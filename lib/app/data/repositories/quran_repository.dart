import '../models/ayah.dart';
import '../models/juz.dart';
import '../models/surah.dart';

/// All methods throw ContentUnavailable when a row is missing or SQLite fails.
abstract interface class QuranRepository {
  List<Surah> listSurah();
  Surah getSurah(int number);
  List<Ayah> listAyah(int surahNumber);
  Ayah getAyah(AyahRef ref);
  List<Juz> listJuz();
}
