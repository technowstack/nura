import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/repositories/isolate_quran_range_repository.dart';
import 'package:nura/app/data/repositories/sqlite_quran_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';

import '../../support/fixture_db.dart';

/// Null when assets/db/content.db exists (see tool/prepare_content.sh).
final String? _noDb = File('assets/db/content.db').existsSync()
    ? null
    : 'run tool/prepare_content.sh first';

List<(int, int)> _ids(List<Ayah> l) => [
  for (final a in l) (a.surahNumber, a.ayahNumber),
];

void main() {
  group('fixture db', () {
    late Directory tmp;
    late ContentDatabase db;
    late SqliteQuranRepository direct;
    late IsolateQuranRangeRepository repo;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('nura_range_');
      db = ContentDatabase.open(buildFixtureDb(tmp, 'fixture').file);
      direct = SqliteQuranRepository(db);
      repo = await IsolateQuranRangeRepository.start(db.file);
    });

    tearDown(() async {
      await repo.close();
      db.close();
      tmp.deleteSync(recursive: true);
    });

    test('range within one surah, inclusive', () async {
      final r = await repo.getAyahRange(const AyahRef(100, 3), AyahRef(100, 6));
      expect(_ids(r), [(100, 3), (100, 4), (100, 5), (100, 6)]);
    });

    test('single ayah range', () async {
      final r = await repo.getAyahRange(const AyahRef(1, 2), AyahRef(1, 2));
      expect(_ids(r), [(1, 2)]);
    });

    test(
      'range across surahs keeps order and spans all ayat between',
      () async {
        final r = await repo.getAyahRange(const AyahRef(1, 6), AyahRef(112, 2));
        final all = [
          for (final s in direct.listSurah()) ...direct.listAyah(s.number),
        ];
        final from = all.indexWhere(
          (a) => a.surahNumber == 1 && a.ayahNumber == 6,
        );
        final to = all.indexWhere(
          (a) => a.surahNumber == 112 && a.ayahNumber == 2,
        );
        expect(_ids(r), _ids(all.sublist(from, to + 1)));
        expect(r.map((a) => a.surahNumber).toSet().length, greaterThan(2));
      },
    );

    test('whole surah matches listAyah field by field', () async {
      final n = direct.getSurah(100).ayahCount;
      final a = await repo.getAyahRange(const AyahRef(100, 1), AyahRef(100, n));
      final b = direct.listAyah(100);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].surahNumber, b[i].surahNumber);
        expect(a[i].ayahNumber, b[i].ayahNumber);
        expect(a[i].arab, b[i].arab);
        expect(a[i].translation, b[i].translation);
        expect(a[i].tafsir, b[i].tafsir);
      }
    });

    for (final (name, s, e) in [
      ('surah 115', const AyahRef(115, 1), const AyahRef(115, 2)),
      ('surah 0', const AyahRef(0, 1), const AyahRef(1, 1)),
      ('ayah 0', const AyahRef(1, 0), const AyahRef(1, 2)),
      ('ayah beyond count', const AyahRef(1, 1), const AyahRef(1, 8)),
      ('start after end', const AyahRef(100, 5), const AyahRef(100, 4)),
      ('start surah after end', const AyahRef(112, 1), const AyahRef(1, 1)),
    ]) {
      test('invalid ref ($name) throws ContentUnavailable', () {
        expect(repo.getAyahRange(s, e), throwsA(isA<ContentUnavailable>()));
      });
    }

    test('closed worker throws a clear error and does not hang', () async {
      await repo.close();
      await expectLater(
        repo.getAyahRange(const AyahRef(1, 1), AyahRef(1, 2)),
        throwsA(isA<ContentUnavailable>()),
      );
    });

    test('killed worker fails pending and later calls', () async {
      repo.workerIsolate.kill(priority: Isolate.immediate);
      await repo.exited.timeout(const Duration(seconds: 5));
      await expectLater(
        repo.getAyahRange(const AyahRef(1, 1), AyahRef(1, 2)),
        throwsA(isA<ContentUnavailable>()),
      );
    });

    test('start on a missing db throws ContentUnavailable', () {
      expect(
        IsolateQuranRangeRepository.start(File('${tmp.path}/nope.db')),
        throwsA(isA<ContentUnavailable>()),
      );
    });
  });

  group('real content.db', () {
    late ContentDatabase db;
    late SqliteQuranRepository direct;
    late IsolateQuranRangeRepository repo;

    setUp(() async {
      db = ContentDatabase.open(File('assets/db/content.db'));
      direct = SqliteQuranRepository(db);
      repo = await IsolateQuranRangeRepository.start(db.file);
    });

    tearDown(() async {
      await repo.close();
      db.close();
    });

    test('juz 30 spans 78:1-114:6 across many surahs', () async {
      final j = direct.listJuz().last;
      expect((j.start, j.end), (const AyahRef(78, 1), const AyahRef(114, 6)));
      final r = await repo.getAyahRange(j.start, j.end);
      final expected = [
        for (var s = 78; s <= 114; s++) direct.getSurah(s).ayahCount,
      ].reduce((a, b) => a + b);
      expect(r.length, expected);
      expect(_ids(r).first, (78, 1));
      expect(_ids(r).last, (114, 6));
    });

    test('range starting mid-surah (juz 2 at 2:142)', () async {
      final j = direct.listJuz()[1];
      expect(j.start, const AyahRef(2, 142));
      final r = await repo.getAyahRange(j.start, j.end);
      expect(_ids(r).first, (2, 142));
      expect(_ids(r).last, (j.endSurah, j.endAyah));
    });

    test('30 juz sum to 6236, each matches the table, no overlap', () async {
      final counts = {
        for (final s in direct.listSurah()) s.number: s.ayahCount,
      };
      var total = 0;
      final seen = <(int, int)>{};
      for (final j in direct.listJuz()) {
        final r = await repo.getAyahRange(j.start, j.end);
        var expected = 0;
        for (var s = j.startSurah; s <= j.endSurah; s++) {
          final from = s == j.startSurah ? j.startAyah : 1;
          final to = s == j.endSurah ? j.endAyah : counts[s]!;
          expected += to - from + 1;
        }
        expect(r.length, expected, reason: 'juz ${j.number}');
        for (final id in _ids(r)) {
          expect(seen.add(id), isTrue, reason: 'overlap at $id');
        }
        total += r.length;
      }
      expect(total, 6236);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('every whole surah equals listAyah', () async {
      for (final s in direct.listSurah()) {
        final a = await repo.getAyahRange(
          AyahRef(s.number, 1),
          AyahRef(s.number, s.ayahCount),
        );
        final b = direct.listAyah(s.number);
        expect(a.length, b.length);
        for (var i = 0; i < a.length; i++) {
          expect(
            [a[i].arab, a[i].translation, a[i].tafsir, a[i].ayahNumber],
            [b[i].arab, b[i].translation, b[i].tafsir, b[i].ayahNumber],
          );
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }, skip: _noDb);
}
