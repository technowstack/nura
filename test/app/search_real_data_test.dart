import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/search_query.dart';
import 'package:nura/app/data/models/search_hit.dart';
import 'package:nura/app/data/repositories/isolate_search_repository.dart';
import 'package:nura/app/data/repositories/search_repository.dart';
import 'package:nura/app/data/repositories/sqlite_hadith_repository.dart';
import 'package:nura/app/data/repositories/sqlite_search_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/content_pipeline/text_normalizer.dart';

// Runs against the generated content.db (run tool/prepare_content.sh first);
// fails, rather than skips, when it is missing.
final _dbFile = File('assets/db/content.db');

late ContentDatabase _db;
late SqliteSearchRepository _repo;

/// Pages through every hit of [raw] (keyset on rowId), checking ids ascend.
Future<List<SearchHit>> _all(
  String raw, {
  required bool hadith,
  String? bookSlug,
}) async {
  final q = parseSearchQuery(raw);
  final hits = <SearchHit>[];
  var after = 0;
  while (true) {
    final page = hadith
        ? await _repo.searchHadith(q, bookSlug: bookSlug, afterRowId: after)
        : await _repo.searchAyah(q, afterRowId: after);
    for (final h in page.hits) {
      expect(h.rowId, greaterThan(after));
      after = h.rowId;
    }
    hits.addAll(page.hits);
    if (!page.hasMore) return hits;
  }
}

int _ftsCount(String table, String match) =>
    _db.raw.select(
          'SELECT count(*) AS n FROM ${table}_fts WHERE '
          '${table}_fts MATCH ?',
          [match],
        ).single['n']
        as int;

List<String> _highlighted(SearchHit h) => [
  for (final r in h.snippet.highlights)
    h.snippet.text.substring(r.start, r.end),
];

final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

void main() {
  setUpAll(() {
    _db = ContentDatabase.open(_dbFile);
    _repo = SqliteSearchRepository(_db);
  });
  tearDownAll(() => _db.close());

  group('(a) totals', () {
    test('"sabar" substring: 91 ayat, 256 hadith', () async {
      expect(await _all('sabar', hadith: false), hasLength(91));
      expect(await _all('sabar', hadith: true), hasLength(256));
    });

    test('Arabic الصلاة matches as a prefix through FTS', () async {
      final q = parseSearchQuery('الصلاة');
      expect(
        _ftsCount('hadith', q.match),
        greaterThan(_ftsCount('hadith', 'arab : "${q.tokens.single}"')),
      );
      expect((await _repo.searchHadith(q)).hasMore, isTrue);
    });

    // Q13: ayah_fts also holds the small-alef-as-alif form, so imla'i
    // spellings find Uthmani text. Counts measured on content.db (ayat).
    test('Arabic imla\'i spelling finds Uthmani ayat (Q13)', () async {
      const expected = {
        'الصلاة': 55,
        'الصلوة': 55, // the Uthmani spelling keeps working
        'الزكاة': 26,
        'الحياة': 62,
        'السماوات': 180,
        'إبراهيم': 40,
        'الكتاب': 151,
        // Must not shrink: they never carried a small alef problem.
        'الرحمن': 45,
        'هذا': 183,
        'ذلك': 312,
      };
      for (final e in expected.entries) {
        expect(
          await _all(e.key, hadith: false),
          hasLength(e.value),
          reason: e.key,
        );
      }
    });
  });

  test(
    '(b) hostile inputs run on the real FTS and LIKE without error',
    () async {
      const inputs = [
        '"', '*', '-', 'OR', 'AND', 'NEAR(', '(a)', 'ال:ب', '^ك', 'ك"ب', //
        '100%', 'a_b', r'a\b', "'; DROP", '- % sabar', 'sabar الصلاة',
        'الصَّلَاةَ', 'a1 b2 c3 d4 e5 f6 g7 h8 i9',
      ];
      for (final raw in inputs) {
        final q = parseSearchQuery(raw);
        await _repo.searchAyah(q);
        await _repo.searchHadith(q);
        await _repo.searchHadith(q, bookSlug: 'bukhari');
      }
      // `%` and `_` are literal: no translation contains these sequences.
      expect((await _repo.searchHadith(parseSearchQuery('s%r'))).hits, isEmpty);
      expect(
        (await _repo.searchHadith(parseSearchQuery('s_bar'))).hits,
        isEmpty,
      );
    },
  );

  group('(c) common words on all hadith', () {
    test('"a" is one letter: tooShort, no query', () async {
      final page = await _repo.searchHadith(parseSearchQuery('a'));
      expect(page.hits, isEmpty);
      expect(page.hasMore, isFalse);
    });

    for (final word in ['yang', 'di', 'an']) {
      test(
        '"$word": full pages, ascending unique rowIds for 10 pages',
        () async {
          final q = parseSearchQuery(word);
          final seen = <int>{};
          var after = 0;
          for (var i = 0; i < 10; i++) {
            final page = await _repo.searchHadith(q, afterRowId: after);
            expect(page.hits, hasLength(30));
            expect(page.hasMore, isTrue);
            for (final h in page.hits) {
              expect(h.rowId, greaterThan(after));
              expect(seen.add(h.rowId), isTrue);
              after = h.rowId;
            }
          }
        },
      );
    }
  });

  test('(d) harakat-insensitive, highlights cover the token', () async {
    final vocalized = await _repo.searchHadith(parseSearchQuery('الصَّلَاةَ'));
    final bare = await _repo.searchHadith(parseSearchQuery('الصلاه'));
    expect(bare.hits, isNotEmpty);
    expect(
      vocalized.hits.map((h) => (h.rowId, h.snippet.text)),
      bare.hits.map((h) => (h.rowId, h.snippet.text)),
    );
    for (final h in bare.hits.take(20)) {
      final hl = _highlighted(h);
      expect(hl, isNotEmpty, reason: 'row ${h.rowId}');
      for (final s in hl) {
        expect(normalizeArabicForSearch(s), contains('الصلاه'));
      }
    }
  });

  test('(e) last stored word of each truncated hadith is found', () async {
    final rows = _db.raw.select(
      'SELECT id, book_slug, arab FROM hadith '
      'WHERE length(CAST(arab AS BLOB)) >= ? ORDER BY id',
      [sourceTruncationBytes],
    );
    expect(rows, hasLength(19));
    var exercised = 0;
    for (final r in rows) {
      final id = r['id'] as int;
      // Same token split as the FTS tokenizer on the normalized index text.
      final words = normalizeArabicForSearch(
        r['arab'] as String,
      ).split(_nonWord).where((w) => w.length >= 2);
      if (words.isEmpty) continue;
      final q = parseSearchQuery(words.last);
      expect(q.status, QueryStatus.ok, reason: 'row $id');
      final page = await _repo.searchHadith(
        q,
        bookSlug: r['book_slug'] as String,
        afterRowId: id - 1,
        limit: 1,
      );
      expect(page.hits.single.rowId, id, reason: 'row $id "${words.last}"');
      exercised++;
    }
    expect(exercised, greaterThanOrEqualTo(15));
  });

  test('(f) worst-case all-hadith pages via the isolate take < 1 s', () async {
    final iso = await IsolateSearchRepository.start(_dbFile);
    addTearDown(iso.close);
    final SearchRepository repo = iso;
    // Rare word (no hit: full scan), two most common letters, two common
    // words, and a two-letter Arabic prefix.
    for (final raw in ['qzxv', 'an', 'yang dan', 'ال']) {
      final w = Stopwatch()..start();
      final page = await repo.searchHadith(parseSearchQuery(raw));
      final ms = w.elapsedMilliseconds;
      // Reference numbers for docs/STATUS.md.
      stdout.writeln('search hadith "$raw" $ms ms (${page.hits.length} hits)');
      expect(ms, lessThan(1000), reason: raw);
    }
  });

  test('(g) "sabar" ayah snippets carry the spec 5.5 ellipsis flags', () async {
    final hits = (await _all('sabar', hadith: false)).cast<AyahSearchHit>();
    final flags = {
      for (final h in hits)
        (h.surahNumber, h.ayahNumber): (h.snippet.cutStart, h.snippet.cutEnd),
    };
    expect(flags[(2, 45)], (false, true));
    expect(flags[(2, 153)], (true, true));
    expect(flags[(3, 146)], (true, false));
    expect(flags[(16, 42)], (false, false));
  });
}
