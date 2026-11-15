import 'dart:io';
import 'dart:isolate';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/search_query.dart';
import 'package:nura/app/core/search_snippet.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/search_hit.dart';
import 'package:nura/app/data/repositories/isolate_search_repository.dart';
import 'package:nura/app/data/repositories/sqlite_search_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/app/data/sources/search_query_worker.dart';

import '../../support/search_db.dart';

/// Independent of the wire codec, so a field dropped by the codec shows up.
List<Object?> describe(SearchPage p) => [
  p.hasMore,
  for (final h in p.hits)
    [
      h.runtimeType,
      h.rowId,
      h.snippet.text,
      [for (final r in h.snippet.highlights) (r.start, r.end)],
      h.snippet.cutStart,
      h.snippet.cutEnd,
      switch (h) {
        AyahSearchHit() => (h.surahNumber, h.ayahNumber, h.surahName),
        HadithSearchHit() => (h.ref, h.bookName),
      },
    ],
];

void main() {
  const sabirin = 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ';
  final long = '${'kata ' * 40}sabar ${'lagi ' * 40}';
  late Directory tmp;
  late ContentDatabase db;
  late SqliteSearchRepository direct;
  late IsolateSearchRepository repo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('nura_iso_search_');
    db = buildSearchDb(
      tmp,
      surahs: {1: 'Al-Fatihah', 2: 'Al-Baqarah'},
      ayahs: [
        for (var i = 1; i <= 12; i++)
          (
            surah: i <= 6 ? 1 : 2,
            ayah: i,
            arab: i.isEven ? sabirin : 'قُلْ هُوَ',
            translation: i == 3 ? long : 'Sabarlah yang ke $i, 100% a_b',
          ),
        (surah: 2, ayah: 13, arab: 'ب', translation: 'kode axb 1000'),
      ],
      books: {'bukhari': 'Shahih Bukhari', 'muslim': 'Shahih Muslim'},
      hadith: [
        for (var i = 1; i <= 5; i++)
          (
            slug: 'bukhari',
            number: i,
            arab: sabirin,
            translation: 'sabar bukhari $i',
          ),
        for (var i = 1; i <= 3; i++)
          (
            slug: 'muslim',
            number: i,
            arab: 'ب',
            translation: 'Sabar muslim $i',
          ),
      ],
    );
    direct = SqliteSearchRepository(db);
    repo = await IsolateSearchRepository.start(db.file);
  });

  tearDown(() async {
    await repo.close();
    db.close();
    tmp.deleteSync(recursive: true);
  });

  const queries = [
    'sabar', // Latin substring
    'SABARLAH', // case
    '100%', // LIKE wildcard literal
    'a_b',
    'الصَّابِرِينَ', // Arabic vocalized
    'الصاب',
    'yang', // common word
    '', // empty
    'a', // tooShort
    'tidakada',
  ];

  test('searchAyah matches direct repository, incl. paging', () async {
    for (final raw in queries) {
      final q = parseSearchQuery(raw);
      for (final (after, limit) in [(0, 30), (0, 2), (4, 3)]) {
        expect(
          describe(await repo.searchAyah(q, afterRowId: after, limit: limit)),
          describe(await direct.searchAyah(q, afterRowId: after, limit: limit)),
          reason: '$raw after=$after limit=$limit',
        );
      }
    }
    // Sanity: the fixture actually yields cut snippets and highlights.
    final p = await repo.searchAyah(parseSearchQuery('sabar'));
    final cut = p.hits.firstWhere((h) => h.rowId == 3).snippet;
    expect(cut.cutStart && cut.cutEnd, isTrue);
    expect(cut.highlights, isNotEmpty);
  });

  test(
    'searchHadith matches direct repository with and without book',
    () async {
      for (final raw in queries) {
        final q = parseSearchQuery(raw);
        for (final book in [null, 'bukhari', 'muslim', 'nope']) {
          for (final (after, limit) in [(0, 30), (2, 2)]) {
            expect(
              describe(
                await repo.searchHadith(
                  q,
                  bookSlug: book,
                  afterRowId: after,
                  limit: limit,
                ),
              ),
              describe(
                await direct.searchHadith(
                  q,
                  bookSlug: book,
                  afterRowId: after,
                  limit: limit,
                ),
              ),
              reason: '$raw book=$book after=$after limit=$limit',
            );
          }
        }
      }
      expect(
        (await repo.searchHadith(parseSearchQuery('sabar'))).hits,
        hasLength(8),
      );
    },
  );

  test('bad limit is ArgumentError', () async {
    await expectLater(
      repo.searchAyah(parseSearchQuery('sabar'), limit: 0),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      repo.searchHadith(parseSearchQuery('sabar'), limit: 0),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
    'worker errors are ContentUnavailable without a double prefix',
    () async {
      // A malformed MATCH string makes sqlite fail inside the worker.
      const bad = ParsedQuery(
        status: QueryStatus.ok,
        isArabic: true,
        tokens: ['x'],
        match: 'arab : ("',
        likePatterns: [],
      );
      final e = await repo
          .searchAyah(bad)
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(e, isA<ContentUnavailable>());
      expect('$e'.indexOf('ContentUnavailable'), 0);
      expect('$e'.lastIndexOf('ContentUnavailable'), 0);
    },
  );

  test('close is idempotent, ends the isolate, later calls throw', () async {
    await repo.close();
    await repo.close();
    await repo.exited.timeout(const Duration(seconds: 5));
    await expectLater(
      repo.searchAyah(parseSearchQuery('sabar')),
      throwsA(isA<ContentUnavailable>()),
    );
    await expectLater(
      repo.searchHadith(parseSearchQuery('sabar')),
      throwsA(isA<ContentUnavailable>()),
    );
  });

  test('killed worker fails pending and later calls cleanly', () async {
    repo.workerIsolate?.kill(priority: Isolate.immediate);
    await expectLater(
      repo
          .searchAyah(parseSearchQuery('sabar'))
          .timeout(const Duration(seconds: 5)),
      throwsA(isA<ContentUnavailable>()),
    );
    await repo.exited.timeout(const Duration(seconds: 5));
    await expectLater(
      repo.searchHadith(parseSearchQuery('sabar')),
      throwsA(isA<ContentUnavailable>()),
    );
  });

  test(
    'start fails with ContentUnavailable for bad path or junk file',
    () async {
      await expectLater(
        IsolateSearchRepository.start(File('${tmp.path}/missing.db')),
        throwsA(isA<ContentUnavailable>()),
      );
      final junk = File('${tmp.path}/junk.db')..writeAsStringSync('not sqlite');
      await expectLater(
        IsolateSearchRepository.start(junk),
        throwsA(isA<ContentUnavailable>()),
      );
    },
  );

  test('start times out with ContentUnavailable', () async {
    await expectLater(
      IsolateSearchRepository.start(db.file, timeout: Duration.zero),
      throwsA(isA<ContentUnavailable>()),
    );
  });

  test('codec round trip keeps query and page fields', () {
    const q = ParsedQuery(
      status: QueryStatus.tooShort,
      isArabic: true,
      tokens: ['a', 'b'],
      match: 'm',
      likePatterns: ['%a%'],
    );
    final back = queryFromMap(queryToMap(q));
    expect(back.status, q.status);
    expect(back.isArabic, isTrue);
    expect(back.tokens, q.tokens);
    expect(back.match, 'm');
    expect(back.likePatterns, ['%a%']);

    const page = SearchPage(
      hits: [
        AyahSearchHit(
          rowId: 7,
          snippet: Snippet(
            text: 't ',
            highlights: [TextRange(start: 0, end: 1)],
            cutStart: true,
            cutEnd: false,
          ),
          surahNumber: 2,
          ayahNumber: 3,
          surahName: 'S',
        ),
        HadithSearchHit(
          rowId: 9,
          snippet: Snippet(
            text: 'u',
            highlights: [],
            cutStart: false,
            cutEnd: true,
          ),
          ref: HadithRef('b', 4),
          bookName: 'B',
        ),
      ],
      hasMore: true,
    );
    expect(describe(searchPageFromMap(searchPageToMap(page))), describe(page));
  });
}
