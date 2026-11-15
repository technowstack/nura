import 'package:flutter/material.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/bookmark.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/hadith_book.dart';
import 'package:nura/app/data/models/juz.dart';
import 'package:nura/app/data/models/last_read.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
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

  /// Newest first, as the real repository returns them.
  final List<HadithBookmark> hadithBookmarks = [];

  @override
  bool toggleHadithBookmark(HadithRef ref) {
    _check();
    final before = hadithBookmarks.length;
    hadithBookmarks.removeWhere((b) => b.ref == ref);
    if (hadithBookmarks.length < before) return false;
    hadithBookmarks.insert(
      0,
      HadithBookmark(ref: ref, createdAt: DateTime(2000, 1, 1, 0, 0, ++_tick)),
    );
    return true;
  }

  @override
  List<HadithBookmark> listHadithBookmarks() {
    _check();
    return List.of(hadithBookmarks);
  }

  @override
  Set<int> bookmarkedHadithNumbers(String slug) {
    _check();
    return {
      for (final b in hadithBookmarks)
        if (b.ref.slug == slug) b.ref.number,
    };
  }

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

/// Configurable in-memory hadith repository. Set [failure] to make every call
/// throw. [summaries] hold per-book items ordered by number.
class FakeHadithRepository implements HadithRepository {
  FakeHadithRepository({
    this.books = const [],
    this.summaries = const {},
    this.hadith = const [],
    this.failure,
  });

  List<HadithBook> books;
  Map<String, List<HadithSummary>> summaries;
  List<Hadith> hadith;
  Object? failure;

  void _check() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Future<List<HadithBook>> listBooks() async {
    _check();
    return books;
  }

  @override
  Future<HadithPage> listPage(
    String slug, {
    int afterNumber = 0,
    int limit = 30,
  }) async {
    _check();
    if (limit <= 0) throw ArgumentError.value(limit, 'limit');
    final rest = (summaries[slug] ?? const <HadithSummary>[])
        .where((h) => h.ref.number > afterNumber)
        .toList();
    return HadithPage(
      items: rest.take(limit).toList(),
      hasMore: rest.length > limit,
    );
  }

  @override
  Future<Hadith> getHadith(HadithRef ref) async {
    _check();
    return hadith.firstWhere(
      (h) => h.ref == ref,
      orElse: () =>
          throw ContentUnavailable('hadith ${ref.slug}:${ref.number}'),
    );
  }

  @override
  Future<HadithRef?> neighbor(HadithRef ref, {required bool next}) async {
    _check();
    final nums =
        (summaries[ref.slug] ?? const <HadithSummary>[])
            .map((h) => h.ref.number)
            .toList()
          ..sort();
    if (!nums.contains(ref.number)) {
      throw ContentUnavailable('hadith ${ref.slug}:${ref.number}');
    }
    final i = nums.indexOf(ref.number) + (next ? 1 : -1);
    return i < 0 || i >= nums.length ? null : HadithRef(ref.slug, nums[i]);
  }
}
