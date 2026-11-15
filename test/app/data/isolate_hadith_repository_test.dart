import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/repositories/isolate_hadith_repository.dart';
import 'package:nura/app/data/repositories/sqlite_hadith_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/app/data/sources/hadith_query_worker.dart';

import '../../support/hadith_db.dart';

void main() {
  late Directory tmp;
  late ContentDatabase db;
  late SqliteHadithRepository direct;
  late IsolateHadithRepository repo;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('nura_iso_');
    final arab = 'ا' * 20;
    db = buildHadithDb(
      tmp,
      books: {'bukhari': ('Shahih Bukhari', 1), 'muslim': ('Shahih Muslim', 2)},
      rows: {
        'bukhari': [
          for (var i = 1; i <= 40; i++)
            (number: i, arab: arab, translation: 'terjemah $i  ‌ '),
        ],
        'muslim': [(number: 1, arab: arab, translation: 'm1')],
      },
    );
    direct = SqliteHadithRepository(db);
    repo = await IsolateHadithRepository.start(db.file);
  });

  tearDown(() async {
    await repo.close();
    db.close();
    tmp.deleteSync(recursive: true);
  });

  test('listBooks matches direct repository', () async {
    final a = await repo.listBooks();
    final b = await direct.listBooks();
    expect(
      a.map((e) => (e.slug, e.name, e.hadithCount, e.sortOrder)),
      b.map((e) => (e.slug, e.name, e.hadithCount, e.sortOrder)),
    );
  });

  test('listPage two consecutive pages match', () async {
    var after = 0;
    for (var i = 0; i < 2; i++) {
      final a = await repo.listPage('bukhari', afterNumber: after, limit: 15);
      final b = await direct.listPage('bukhari', afterNumber: after, limit: 15);
      expect(a.hasMore, b.hasMore);
      expect(
        a.items.map((e) => (e.ref, e.preview, e.length)).toList(),
        b.items.map((e) => (e.ref, e.preview, e.length)).toList(),
      );
      after = a.items.last.ref.number;
    }
    expect(after, 30);
  });

  test('getHadith and neighbor match', () async {
    const ref = HadithRef('bukhari', 5);
    final a = await repo.getHadith(ref);
    final b = await direct.getHadith(ref);
    expect(a.translation, b.translation);
    expect(a.translation.endsWith('  ‌ '), isTrue);
    expect(a.arab, b.arab);
    expect(a.bookName, b.bookName);
    expect(a.translationLength, b.translationLength);
    expect(await repo.neighbor(ref, next: true), const HadithRef('bukhari', 6));
    expect(
      await repo.neighbor(ref, next: false),
      const HadithRef('bukhari', 4),
    );
    expect(
      await repo.neighbor(const HadithRef('bukhari', 40), next: true),
      isNull,
    );
  });

  test('20 concurrent requests all answered correctly', () async {
    final results = await Future.wait([
      for (var i = 1; i <= 20; i++) repo.getHadith(HadithRef('bukhari', i)),
    ]);
    expect(results.map((h) => h.ref.number), [for (var i = 1; i <= 20; i++) i]);
  });

  test(
    'errors map to ContentUnavailable, bad limit is ArgumentError',
    () async {
      await expectLater(
        repo.listPage('nope'),
        throwsA(isA<ContentUnavailable>()),
      );
      await expectLater(
        repo.getHadith(const HadithRef('bukhari', 999)),
        throwsA(isA<ContentUnavailable>()),
      );
      await expectLater(
        repo.neighbor(const HadithRef('bukhari', 999), next: true),
        throwsA(isA<ContentUnavailable>()),
      );
      await expectLater(
        repo.listPage('bukhari', limit: 0),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test('close is idempotent, ends the isolate, later calls throw', () async {
    await repo.close();
    await repo.close();
    await repo.exited.timeout(const Duration(seconds: 5));
    await expectLater(repo.listBooks(), throwsA(isA<ContentUnavailable>()));
  });

  test(
    'killed isolate completes pending request with ContentUnavailable',
    () async {
      repo.workerIsolate.kill(priority: Isolate.immediate);
      final pending = repo.listBooks();
      await expectLater(
        pending.timeout(const Duration(seconds: 5)),
        throwsA(isA<ContentUnavailable>()),
      );
    },
  );

  test(
    'start fails with ContentUnavailable for bad path or non-sqlite file',
    () async {
      await expectLater(
        IsolateHadithRepository.start(File('${tmp.path}/missing.db')),
        throwsA(isA<ContentUnavailable>()),
      );
      final junk = File('${tmp.path}/junk.db')..writeAsStringSync('not sqlite');
      await expectLater(
        IsolateHadithRepository.start(junk),
        throwsA(isA<ContentUnavailable>()),
      );
    },
  );

  test('codec round trip keeps flags and exact text', () {
    const h = Hadith(
      ref: HadithRef('x', 3),
      bookName: 'B',
      arab: 'a ',
      translation: 't ‌ ',
      translationLength: 4,
      arabTruncated: true,
      translationTruncated: false,
    );
    final back = hadithFromMap(hadithToMap(h));
    expect(back.ref, h.ref);
    expect(back.translation, h.translation);
    expect(back.arab, h.arab);
    expect(back.arabTruncated, isTrue);
    expect(back.translationTruncated, isFalse);
    expect(back.translationLength, 4);
    expect(back.bookName, 'B');
  });
}
