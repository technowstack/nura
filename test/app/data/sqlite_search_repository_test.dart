import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/search_query.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/search_hit.dart';
import 'package:nura/app/data/repositories/sqlite_search_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';

import '../../support/search_db.dart';

SearchAyahRow ayah(int s, int a, String tr, [String arab = 'ب']) =>
    (surah: s, ayah: a, arab: arab, translation: tr);

SearchHadithRow hadith(String slug, int n, String tr, [String arab = 'ب']) =>
    (slug: slug, number: n, arab: arab, translation: tr);

void main() {
  late Directory dir;
  late ContentDatabase db;
  late SqliteSearchRepository repo;

  setUp(() => dir = Directory.systemTemp.createTempSync('search_test'));
  tearDown(() {
    try {
      db.close();
    } on StateError {
      // already closed
    }
    dir.deleteSync(recursive: true);
  });

  void open({
    List<SearchAyahRow> ayahs = const [],
    List<SearchHadithRow> hadiths = const [],
  }) {
    db = buildSearchDb(
      dir,
      surahs: {1: 'Al-Fatihah', 2: 'Al-Baqarah'},
      ayahs: ayahs,
      books: {'bukhari': 'Shahih Bukhari', 'muslim': 'Shahih Muslim'},
      hadith: hadiths,
    );
    repo = SqliteSearchRepository(db);
  }

  List<int> ids(SearchPage p) => p.hits.map((h) => h.rowId).toList();

  group('translation (substring LIKE)', () {
    test(
      "'sabar' finds 'Sabarlah', 'bersabar' and 'Sabar', not others",
      () async {
        open(
          ayahs: [
            ayah(1, 1, 'Sabarlah kamu'),
            ayah(1, 2, 'orang yang bersabar'),
            ayah(1, 3, 'bersyukurlah'),
            ayah(2, 1, 'Sabar itu indah'),
          ],
        );
        final p = await repo.searchAyah(parseSearchQuery('sabar'));
        expect(ids(p), [1, 2, 4]);
        expect(p.hasMore, isFalse);
        final h = p.hits[1] as AyahSearchHit;
        expect(h.surahNumber, 1);
        expect(h.ayahNumber, 2);
        expect(h.surahName, 'Al-Fatihah');
        expect(h.snippet.text, 'orang yang bersabar');
        expect(h.snippet.highlights.single.start, 14);
        expect((p.hits[2] as AyahSearchHit).surahName, 'Al-Baqarah');
      },
    );

    test('% and _ are matched literally', () async {
      open(
        ayahs: [
          ayah(1, 1, '100% benar'),
          ayah(1, 2, '1000 benar'),
          ayah(1, 3, 'kode a_b'),
          ayah(1, 4, 'kode axb'),
        ],
      );
      expect(ids(await repo.searchAyah(parseSearchQuery('100%'))), [1]);
      expect(ids(await repo.searchAyah(parseSearchQuery('a_b'))), [3]);
    });

    test('words are ANDed in any order', () async {
      open(
        ayahs: [
          ayah(1, 1, 'orang yang bersabar'),
          ayah(1, 2, 'Sabar itu indah'),
          ayah(1, 3, 'orang itu'),
        ],
      );
      expect(ids(await repo.searchAyah(parseSearchQuery('sabar orang'))), [1]);
    });

    test('hadith hits carry ref and book name, ordered by id', () async {
      open(
        hadiths: [
          hadith('bukhari', 1, 'sabar satu'),
          hadith('bukhari', 2, 'lain'),
          hadith('muslim', 1, 'sabar dua'),
        ],
      );
      final p = await repo.searchHadith(parseSearchQuery('sabar'));
      expect(ids(p), [1, 3]);
      final h = p.hits.last as HadithSearchHit;
      expect(h.ref, const HadithRef('muslim', 1));
      expect(h.bookName, 'Shahih Muslim');
    });

    test('bookSlug filters hadith', () async {
      open(
        hadiths: [
          hadith('bukhari', 1, 'sabar satu'),
          hadith('muslim', 1, 'sabar dua'),
          hadith('muslim', 2, 'sabar tiga'),
        ],
      );
      final p = await repo.searchHadith(
        parseSearchQuery('sabar'),
        bookSlug: 'muslim',
      );
      expect(ids(p), [2, 3]);
    });

    test('long hadith snippet stays within 100 chars', () async {
      final long = '${'kata ' * 1600}sabar${' lain' * 1600}';
      expect(long.length, greaterThan(16000));
      open(hadiths: [hadith('bukhari', 1, long)]);
      final p = await repo.searchHadith(parseSearchQuery('sabar'));
      expect(p.hits.single.snippet.text.length, lessThanOrEqualTo(100));
      expect(p.hits.single.snippet.text, contains('sabar'));
    });

    test('common word on 500 rows returns only limit hits', () async {
      open(
        hadiths: [
          for (var i = 1; i <= 500; i++) hadith('bukhari', i, 'yang ke $i'),
        ],
      );
      final p = await repo.searchHadith(parseSearchQuery('yang'), limit: 30);
      expect(ids(p), [for (var i = 1; i <= 30; i++) i]);
      expect(p.hasMore, isTrue);
    });
  });

  group('arabic (fts prefix)', () {
    const sabirin = 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ';

    test('vocalized and plain queries match as token prefix', () async {
      open(ayahs: [ayah(1, 1, 'x', sabirin), ayah(1, 2, 'y', 'قُلْ هُوَ')]);
      for (final q in ['الصَّابِرِينَ', 'الصابرين', 'الصاب']) {
        final p = await repo.searchAyah(parseSearchQuery(q));
        expect(ids(p), [1], reason: q);
        expect(p.hits.single.snippet.highlights, isNotEmpty, reason: q);
      }
    });

    test(
      'v1 limitation: base word does not find the al-prefixed form',
      () async {
        open(ayahs: [ayah(1, 1, 'x', sabirin)]);
        expect(
          await repo.searchAyah(parseSearchQuery('صابرين')),
          isA<SearchPage>().having((p) => p.hits, 'hits', isEmpty),
        );
      },
    );

    test('hadith arabic search honours bookSlug', () async {
      open(
        hadiths: [
          hadith('bukhari', 1, 'a', sabirin),
          hadith('muslim', 1, 'b', sabirin),
        ],
      );
      final q = parseSearchQuery('الصابرين');
      expect(ids(await repo.searchHadith(q)), [1, 2]);
      expect(ids(await repo.searchHadith(q, bookSlug: 'muslim')), [2]);
    });
  });

  test('keyset paging: limit 2 over 7 hits, no duplicates or gaps', () async {
    open(
      ayahs: [
        for (var i = 1; i <= 10; i++)
          ayah(1, i, i.isEven || i == 9 || i == 1 ? 'sabar $i' : 'lain $i'),
      ],
    );
    final q = parseSearchQuery('sabar');
    final seen = <int>[];
    final more = <bool>[];
    var after = 0;
    while (true) {
      final p = await repo.searchAyah(q, afterRowId: after, limit: 2);
      seen.addAll(ids(p));
      more.add(p.hasMore);
      if (!p.hasMore) break;
      after = p.hits.last.rowId;
    }
    expect(seen, [1, 2, 4, 6, 8, 9, 10]);
    expect(more, [true, true, true, false]);
  });

  test('limit below 1 throws ArgumentError', () async {
    open(ayahs: [ayah(1, 1, 'sabar')]);
    final q = parseSearchQuery('sabar');
    expect(() => repo.searchAyah(q, limit: 0), throwsArgumentError);
    expect(() => repo.searchHadith(q, limit: 0), throwsArgumentError);
  });

  test(
    'empty and tooShort queries return an empty page without querying',
    () async {
      open(ayahs: [ayah(1, 1, 'sabar')]);
      db.close();
      for (final raw in ['', '  ', 'a']) {
        final q = parseSearchQuery(raw);
        expect(q.status, isNot(QueryStatus.ok));
        final a = await repo.searchAyah(q);
        final h = await repo.searchHadith(q);
        expect(a.hits, isEmpty);
        expect(a.hasMore, isFalse);
        expect(h.hits, isEmpty);
      }
    },
  );

  test('closed database throws ContentUnavailable', () async {
    open(ayahs: [ayah(1, 1, 'sabar')]);
    db.close();
    final q = parseSearchQuery('sabar');
    await expectLater(repo.searchAyah(q), throwsA(isA<ContentUnavailable>()));
    await expectLater(
      repo.searchHadith(parseSearchQuery('الصابرين')),
      throwsA(isA<ContentUnavailable>()),
    );
  });
}
