import 'package:flutter/material.dart';
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
  Surah getSurah(int number) =>
      _guard(() => surahs.firstWhere((s) => s.number == number));

  @override
  List<Ayah> listAyah(int surahNumber) =>
      _guard(() => ayahs.where((a) => a.surahNumber == surahNumber).toList());

  @override
  Ayah getAyah(AyahRef ref) => _guard(
    () => ayahs.firstWhere(
      (a) => a.surahNumber == ref.surah && a.ayahNumber == ref.ayah,
    ),
  );

  @override
  List<Juz> listJuz() => _guard(() => juz);
}

class FakeUserRepository implements UserRepository {
  FakeUserRepository({this.lastRead, Set<int>? bookmarkedSurahs})
    : bookmarkedSurahs = bookmarkedSurahs ?? {};

  LastRead? lastRead;
  Set<int> bookmarkedSurahs;
  ReadingPrefs prefs = const ReadingPrefs(
    arabicFontSize: 28,
    showTranslation: true,
  );
  ThemeMode themeMode = ThemeMode.system;

  @override
  bool toggleBookmark(AyahRef ref) => bookmarkedSurahs.add(ref.surah);

  @override
  List<Bookmark> listBookmarks() => const [];

  @override
  Set<int> bookmarkedAyahNumbers(int surahNumber) => const {};

  @override
  Set<int> bookmarkedSurahNumbers() => bookmarkedSurahs;

  @override
  LastRead? getLastRead() => lastRead;

  @override
  void setLastRead(AyahRef ref) =>
      lastRead = LastRead(ref: ref, updatedAt: DateTime(2000));

  @override
  ReadingPrefs getReadingPrefs() => prefs;

  @override
  void setArabicFontSize(double size) {}

  @override
  void setShowTranslation(bool value) {}

  @override
  ThemeMode getThemeMode() => themeMode;

  @override
  void setThemeMode(ThemeMode mode) => themeMode = mode;
}
