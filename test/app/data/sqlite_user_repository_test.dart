import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/theme_mode_setting.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/repositories/sqlite_user_repository.dart';
import 'package:nura/app/data/sources/user_database.dart';

void main() {
  late Directory tmp;
  late File file;
  late UserDatabase db;
  late int tick;
  late SqliteUserRepository repo;

  SqliteUserRepository make(UserDatabase d) => SqliteUserRepository(
    d,
    now: () => DateTime.fromMillisecondsSinceEpoch(1000 * ++tick, isUtc: true),
  );

  setUp(() {
    tick = 0;
    tmp = Directory.systemTemp.createTempSync('nura_urepo_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    file = File('${tmp.path}/user.db');
    db = UserDatabase.open(file);
    addTearDown(db.close);
    repo = make(db);
  });

  int rows(String table) =>
      db.raw.select('SELECT COUNT(*) c FROM $table').single['c'] as int;

  test('toggle twice gives true then false without duplicating rows', () {
    expect(repo.toggleBookmark(const AyahRef(1, 2)), isTrue);
    expect(rows('bookmark'), 1);
    expect(repo.toggleBookmark(const AyahRef(1, 2)), isFalse);
    expect(rows('bookmark'), 0);
  });

  test('five rapid toggles end true with one row', () {
    var last = false;
    for (var i = 0; i < 5; i++) {
      last = repo.toggleBookmark(const AyahRef(2, 255));
    }
    expect(last, isTrue);
    expect(rows('bookmark'), 1);
  });

  test('listBookmarks orders created_at ties by id descending', () {
    final fixed = SqliteUserRepository(
      db,
      now: () => DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
    );
    fixed.toggleBookmark(const AyahRef(1, 1));
    fixed.toggleBookmark(const AyahRef(2, 5));
    expect(fixed.listBookmarks().map((b) => b.ref).toList(), const [
      AyahRef(2, 5),
      AyahRef(1, 1),
    ]);
  });

  test('listBookmarks newest first; surah/ayah sets', () {
    repo.toggleBookmark(const AyahRef(1, 1));
    repo.toggleBookmark(const AyahRef(2, 5));
    repo.toggleBookmark(const AyahRef(1, 3));
    expect(repo.listBookmarks().map((b) => b.ref).toList(), const [
      AyahRef(1, 3),
      AyahRef(2, 5),
      AyahRef(1, 1),
    ]);
    expect(repo.listBookmarks().first.createdAt.isUtc, isTrue);
    expect(repo.bookmarkedAyahNumbers(1), {1, 3});
    expect(repo.bookmarkedSurahNumbers(), {1, 2});
  });

  test('last read is null on fresh db and upsert keeps one row', () {
    expect(repo.getLastRead(), isNull);
    repo.setLastRead(const AyahRef(1, 1));
    repo.setLastRead(const AyahRef(3, 7));
    expect(rows('last_read'), 1);
    expect(repo.getLastRead()?.ref, const AyahRef(3, 7));
    expect(repo.getLastRead()?.updatedAt.millisecondsSinceEpoch, 2000);
  });

  test('prefs default and clamp', () {
    expect(repo.getReadingPrefs().arabicFontSize, 28.0);
    expect(repo.getReadingPrefs().showTranslation, isTrue);
    repo.setArabicFontSize(100);
    expect(repo.getReadingPrefs().arabicFontSize, 40.0);
    repo.setArabicFontSize(10);
    expect(repo.getReadingPrefs().arabicFontSize, 20.0);
  });

  test('values persist after reopening', () {
    repo.toggleBookmark(const AyahRef(1, 1));
    repo.setLastRead(const AyahRef(2, 2));
    repo.setArabicFontSize(32);
    repo.setShowTranslation(false);
    repo.setThemeMode(ThemeMode.dark);
    db.close();
    final db2 = UserDatabase.open(file);
    addTearDown(db2.close);
    final r = make(db2);
    expect(r.bookmarkedSurahNumbers(), {1});
    expect(r.getLastRead()?.ref, const AyahRef(2, 2));
    expect(r.getReadingPrefs().arabicFontSize, 32.0);
    expect(r.getReadingPrefs().showTranslation, isFalse);
    expect(r.getThemeMode(), ThemeMode.dark);
    // db is closed again by teardown; reopen guard
    db = db2;
  });

  test('theme mode round trips', () {
    for (final m in ThemeMode.values) {
      expect(themeModeFromSetting(themeModeToSetting(m)), m);
      repo.setThemeMode(m);
      expect(repo.getThemeMode(), m);
    }
  });
}
