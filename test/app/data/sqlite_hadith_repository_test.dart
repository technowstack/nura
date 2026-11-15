import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/repositories/sqlite_hadith_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';

import '../../support/hadith_db.dart';

HadithRow row(int n, [String arab = 'a', String? tr]) =>
    (number: n, arab: arab, translation: tr ?? 'terjemahan $n');

List<HadithRow> seq(int count) => [for (var i = 1; i <= count; i++) row(i)];

int bytes(String s) => utf8.encode(s).length;

void main() {
  late Directory dir;
  late ContentDatabase db;
  late SqliteHadithRepository repo;

  setUp(() => dir = Directory.systemTemp.createTempSync('hadith_test'));
  tearDown(() {
    try {
      db.close();
    } on StateError {
      // already closed
    }
    dir.deleteSync(recursive: true);
  });

  void open(Map<String, List<HadithRow>> rows) {
    db = buildHadithDb(
      dir,
      books: {for (final (i, k) in rows.keys.indexed) k: ('Kitab $k', 10 - i)},
      rows: rows,
    );
    repo = SqliteHadithRepository(db);
  }

  test('listBooks orders by sort_order with name and count', () async {
    open({'a': seq(3), 'b': seq(5)});
    final books = await repo.listBooks();
    expect(books.map((b) => b.slug), ['b', 'a']);
    expect(books.first.name, 'Kitab b');
    expect(books.first.hadithCount, 5);
  });

  test('paging 65 rows: 30, 30, 5 without gaps or duplicates', () async {
    open({'a': seq(65)});
    final seen = <int>[];
    var after = 0;
    final flags = <bool>[];
    final sizes = <int>[];
    while (true) {
      final p = await repo.listPage('a', afterNumber: after);
      sizes.add(p.items.length);
      flags.add(p.hasMore);
      seen.addAll(p.items.map((i) => i.ref.number));
      if (!p.hasMore) break;
      after = p.items.last.ref.number;
    }
    expect(sizes, [30, 30, 5]);
    expect(flags, [true, true, false]);
    expect(seen, [for (var i = 1; i <= 65; i++) i]);
  });

  test('exactly 30 rows has no more; empty book is empty', () async {
    open({'a': seq(30), 'e': []});
    final p = await repo.listPage('a');
    expect(p.items.length, 30);
    expect(p.hasMore, isFalse);
    final e = await repo.listPage('e');
    expect(e.items, isEmpty);
    expect(e.hasMore, isFalse);
  });

  test('gapped numbers sort numerically and neighbor skips gaps', () async {
    open({
      'a': [row(26363), row(50), row(1), row(51), row(2)],
    });
    final p = await repo.listPage('a');
    expect(p.items.map((i) => i.ref.number), [1, 2, 50, 51, 26363]);
    expect(
      await repo.neighbor(const HadithRef('a', 2), next: true),
      const HadithRef('a', 50),
    );
    expect(
      await repo.neighbor(const HadithRef('a', 50), next: false),
      const HadithRef('a', 2),
    );
    expect(await repo.neighbor(const HadithRef('a', 1), next: false), isNull);
    expect(
      await repo.neighbor(const HadithRef('a', 26363), next: true),
      isNull,
    );
  });

  test('preview is first 200 code points, untrimmed; length is full', () async {
    final tr = '${' ' * 3}${'x' * 197}\u{1F600}tail  ';
    open({
      'a': [row(1, 'a', tr)],
    });
    final s = (await repo.listPage('a')).items.single;
    expect(s.preview, String.fromCharCodes(tr.runes.take(200)));
    expect(s.preview.runes.length, 200);
    expect(s.length, tr.length);
  });

  test('getHadith returns exact text and book name', () async {
    final tr = 'x' * 16384;
    open({
      'a': [row(1, 'arab ‌  ', 'isi  ‌ '), row(2, 'a', tr)],
    });
    final h = await repo.getHadith(const HadithRef('a', 1));
    expect(h.arab, 'arab ‌  ');
    expect(h.translation, 'isi  ‌ ');
    expect(h.bookName, 'Kitab a');
    final big = await repo.getHadith(const HadithRef('a', 2));
    expect(big.translation, tr);
    expect(big.translationLength, 16384);
  });

  test('truncation flags by byte boundary', () async {
    final ar374 = 'ب' * 8187;
    final ar373 = '${'ب' * 8186}a';
    // 16,381 ASCII + one 3-byte quote: 16,382 chars, 16,384 bytes.
    final tr16382b = '${'x' * 16381}”';
    expect(tr16382b.length, 16382);
    expect(bytes(tr16382b), 16384);
    open({
      'a': [
        row(1, ar374, 't'),
        row(2, ar373, 't'),
        row(3, 'a', 'x' * 16374),
        row(4, 'a', 'x' * 16373),
        row(5, 'a', tr16382b),
        row(6, 'a', 'x' * 16092),
        row(7, 'a', '${'x' * 16371}\u201d'),
        row(8, 'a', '${'x' * 16370}\u201d'),
      ],
    });
    Future<Hadith> g(int n) => repo.getHadith(HadithRef('a', n));
    expect((await g(1)).arabTruncated, isTrue);
    expect((await g(1)).translationTruncated, isFalse);
    expect((await g(2)).arabTruncated, isFalse);
    expect((await g(3)).translationTruncated, isTrue);
    expect((await g(3)).arabTruncated, isFalse);
    expect((await g(4)).translationTruncated, isFalse);
    expect((await g(5)).translationTruncated, isTrue);
    expect((await g(6)).translationTruncated, isFalse);
    expect((await g(7)).translationTruncated, isTrue);
    expect((await g(8)).translationTruncated, isFalse);
  });

  test('missing book or hadith throws ContentUnavailable', () async {
    open({'a': seq(2)});
    expect(repo.listPage('zz'), throwsA(isA<ContentUnavailable>()));
    expect(
      repo.getHadith(const HadithRef('zz', 1)),
      throwsA(isA<ContentUnavailable>()),
    );
    expect(
      repo.getHadith(const HadithRef('a', 99)),
      throwsA(isA<ContentUnavailable>()),
    );
  });

  test('neighbor of unknown ref throws; real ends still null', () async {
    open({'a': seq(3)});
    expect(
      repo.neighbor(const HadithRef('a', 99), next: true),
      throwsA(isA<ContentUnavailable>()),
    );
    expect(
      repo.neighbor(const HadithRef('zz', 1), next: false),
      throwsA(isA<ContentUnavailable>()),
    );
    expect(await repo.neighbor(const HadithRef('a', 3), next: true), isNull);
    expect(await repo.neighbor(const HadithRef('a', 1), next: false), isNull);
  });

  test('non-positive limit is an ArgumentError', () async {
    open({'a': seq(5)});
    for (final l in [0, -1, -2]) {
      expect(repo.listPage('a', limit: l), throwsA(isA<ArgumentError>()));
    }
  });

  test('closed database throws ContentUnavailable everywhere', () async {
    open({'a': seq(2)});
    db.close();
    expect(repo.listBooks(), throwsA(isA<ContentUnavailable>()));
    expect(repo.listPage('a'), throwsA(isA<ContentUnavailable>()));
    expect(
      repo.getHadith(const HadithRef('a', 1)),
      throwsA(isA<ContentUnavailable>()),
    );
    expect(
      repo.neighbor(const HadithRef('a', 1), next: true),
      throwsA(isA<ContentUnavailable>()),
    );
  });
}
