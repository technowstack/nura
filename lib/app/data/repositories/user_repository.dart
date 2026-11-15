import 'package:flutter/material.dart';

import '../models/ayah.dart';
import '../models/bookmark.dart';
import '../models/hadith.dart';
import '../models/last_read.dart';
import '../models/reading_prefs.dart';

abstract interface class UserRepository {
  /// Toggles the bookmark and returns the new state (true = bookmarked).
  bool toggleBookmark(AyahRef ref);
  List<Bookmark> listBookmarks();
  Set<int> bookmarkedAyahNumbers(int surahNumber);
  Set<int> bookmarkedSurahNumbers();

  /// Toggles the hadith bookmark and returns the new state.
  bool toggleHadithBookmark(HadithRef ref);
  List<HadithBookmark> listHadithBookmarks();
  Set<int> bookmarkedHadithNumbers(String slug);
  LastRead? getLastRead();
  void setLastRead(AyahRef ref);
  ReadingPrefs getReadingPrefs();
  void setArabicFontSize(double size);
  void setShowTranslation(bool value);
  ThemeMode getThemeMode();
  void setThemeMode(ThemeMode mode);
}
