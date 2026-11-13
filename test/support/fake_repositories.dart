import 'package:flutter/material.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/bookmark.dart';
import 'package:nura/app/data/models/juz.dart';
import 'package:nura/app/data/models/last_read.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';

/// Configurable in-memory repository. Set [failure] to make every call throw.
class FakeQuranRepository implements QuranRepository {
  FakeQuranRepository({
    this.surahs = const [],
    this.juz = const [],
    this.ayahs = const [],
    this.failure,
  });

  List<Surah> surahs;
  List<Juz> juz;
  List<Ayah> ayahs;
  Object? failure;

  T _guard<T>(T Function() read) {
    final f = failure;
    if (f != null) throw f;
    return read();
  }

  @override
  List<Surah> listSurah() => _guard(() => surahs);

  @override
  Surah getSurah(int number) => _guard(
    () => surahs.firstWhere(
      (s) => s.number == number,
      orElse: () => throw ContentUnavailable('surah $number'),
    ),
  );

  @override
  List<Ayah> listAyah(int surahNumber) =>
      _guard(() => ayahs.where((a) => a.surahNumber == surahNumber).toList());

  @override
  Ayah getAyah(AyahRef ref) => _guard(
    () => ayahs.firstWhere(
      (a) => a.surahNumber == ref.surah && a.ayahNumber == ref.ayah,
      orElse: () => throw ContentUnavailable('ayah ${ref.surah}:${ref.ayah}'),
    ),
  );

  @override
  List<Juz> listJuz() => _guard(() => juz);
}

class FakeUserRepository implements UserRepository {
  FakeUserRepository({this.lastRead, Set<int>? bookmarkedSurahs})
    : bookmarkedSurahs = bookmarkedSurahs ?? {};

  LastRead? lastRead;
  final List<AyahRef> lastReadWrites = [];
  Set<int> bookmarkedSurahs;
  final Map<int, Set<int>> ayahBookmarks = {};

  /// Newest first, as the real repository returns them.
  final List<Bookmark> bookmarks = [];
  int _tick = 0;

  /// When set, getReadingPrefs throws it.
  Object? prefsFailure;

  /// When set, bookmark calls throw it.
  Object? failure;

  void _check() {
    final f = failure;
    if (f != null) throw f;
  }

  ReadingPrefs prefs = const ReadingPrefs(
    arabicFontSize: 28,
    showTranslation: true,
  );
  ThemeMode themeMode = ThemeMode.system;

  @override
  bool toggleBookmark(AyahRef ref) {
    _check();
    bookmarkedSurahs.add(ref.surah);
    final set = ayahBookmarks.putIfAbsent(ref.surah, () => <int>{});
    final added = set.add(ref.ayah) || !set.remove(ref.ayah);
    bookmarks.removeWhere((b) => b.ref == ref);
    if (added) {
      bookmarks.insert(
        0,
        Bookmark(ref: ref, createdAt: DateTime(2000, 1, 1, 0, 0, ++_tick)),
      );
    }
    return added;
  }

  @override
  List<Bookmark> listBookmarks() {
    _check();
    return List.of(bookmarks);
  }

  @override
  Set<int> bookmarkedAyahNumbers(int surahNumber) {
    _check();
    return bookmarkedAyahsOf(surahNumber);
  }

  Set<int> bookmarkedAyahsOf(int surahNumber) => {
    ...?ayahBookmarks[surahNumber],
  };

  @override
  Set<int> bookmarkedSurahNumbers() => bookmarkedSurahs;

  @override
  LastRead? getLastRead() => lastRead;

  @override
  void setLastRead(AyahRef ref) {
    _check();
    lastReadWrites.add(ref);
    lastRead = LastRead(ref: ref, updatedAt: DateTime(2000));
  }

  @override
  ReadingPrefs getReadingPrefs() {
    final f = prefsFailure;
    if (f != null) throw f;
    return prefs;
  }

  @override
  void setArabicFontSize(double size) {
    _check();
    prefs = ReadingPrefs(
      arabicFontSize: size,
      showTranslation: prefs.showTranslation,
    );
  }

  @override
  void setShowTranslation(bool value) {
    _check();
    prefs = ReadingPrefs(
      arabicFontSize: prefs.arabicFontSize,
      showTranslation: value,
    );
  }

  @override
  ThemeMode getThemeMode() => themeMode;

  @override
  void setThemeMode(ThemeMode mode) {
    _check();
    themeMode = mode;
  }
}
