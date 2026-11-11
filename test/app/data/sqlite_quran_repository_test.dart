import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/repositories/sqlite_quran_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';

import '../../support/fixture_db.dart';
import '../../support/fixtures.dart';

void main() {
  late Directory tmp;
  late ContentDatabase db;
  late SqliteQuranRepository repo;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_quran_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = ContentDatabase.open(buildFixtureDb(tmp, 'fixture').file);
    repo = SqliteQuranRepository(db);
  });

  test('listSurah is ordered and maps columns', () {
    final list = repo.listSurah();
    final numbers = list.map((s) => s.number).toList();
    expect(numbers, [...numbers]..sort());
    final s = list.first;
    expect(s.number, 1);
    expect(s.nameLatin, 'Al-Fatihah');
    expect(s.nameId, 'Pembukaan');
    expect(s.ayahCount, 7);
    expect(
      s.revelation,
      'makkiyah',
    ); // brief said '', fixture data says makkiyah
  });

  test('listAyah orders numerically', () {
    final nums = repo.listAyah(100).map((a) => a.ayahNumber).toList();
    expect(nums, List.generate(11, (i) => i + 1));
  });

  test('ayah text is byte-identical to source', () {
    final src =
        jsonDecode(File(fixturePath('quran/1.json')).readAsStringSync())
            as Map<String, dynamic>;
    final s = src['1'] as Map<String, dynamic>;
    final a = repo.listAyah(1).first;
    expect(a.arab, (s['text'] as Map)['1']);
    expect(
      a.translation,
      ((s['translations'] as Map)['id'] as Map)['text']['1'],
    );
    expect(
      a.tafsir,
      (((s['tafsir'] as Map)['id'] as Map)['kemenag'] as Map)['text']['1'],
    );
  });

  test('getAyah and not-found errors', () {
    expect(repo.getAyah(const AyahRef(1, 1)).ayahNumber, 1);
    expect(repo.getSurah(1).number, 1);
    expect(() => repo.getSurah(999), throwsA(isA<ContentUnavailable>()));
    expect(
      () => repo.getAyah(const AyahRef(1, 999)),
      throwsA(isA<ContentUnavailable>()),
    );
  });

  test('listJuz is empty on fixture', () {
    expect(repo.listJuz(), isEmpty);
  });

  test('closed database throws ContentUnavailable', () {
    db.close();
    expect(() => repo.listSurah(), throwsA(isA<ContentUnavailable>()));
    expect(() => repo.getSurah(1), throwsA(isA<ContentUnavailable>()));
    expect(() => repo.listAyah(1), throwsA(isA<ContentUnavailable>()));
    expect(
      () => repo.getAyah(const AyahRef(1, 1)),
      throwsA(isA<ContentUnavailable>()),
    );
    expect(() => repo.listJuz(), throwsA(isA<ContentUnavailable>()));
  });
}
