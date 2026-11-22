import 'package:sqlite3/sqlite3.dart';

import '../../core/errors.dart';
import '../models/ayah.dart';
import '../models/juz.dart';
import '../models/surah.dart';
import '../sources/content_database.dart';
import 'quran_repository.dart';

class SqliteQuranRepository implements QuranRepository {
  SqliteQuranRepository(this._db);

  final ContentDatabase _db;

  ResultSet _select(String sql, [List<Object?> args = const []]) {
    try {
      return _db.raw.select(sql, args);
    } on SqliteException catch (e) {
      throw ContentUnavailable('Konten tidak dapat dibaca: ${e.message}');
    } on StateError {
      // sqlite3 throws StateError (not SqliteException) on a closed database.
      throw const ContentUnavailable('Konten tidak dapat dibaca');
    }
  }

  Surah _surah(Row r) => Surah(
    number: r['number'] as int,
    nameArab: r['name_arab'] as String,
    nameLatin: r['name_latin'] as String,
    nameId: r['name_id'] as String,
    ayahCount: r['ayah_count'] as int,
    revelation: r['revelation'] as String,
  );

  Ayah _ayah(Row r) => Ayah(
    surahNumber: r['surah_number'] as int,
    ayahNumber: r['ayah_number'] as int,
    arab: r['arab'] as String,
    translation: r['translation_id'] as String,
    tafsir: r['tafsir_kemenag'] as String,
  );

  static const _ayahCols =
      'surah_number, ayah_number, arab, translation_id, tafsir_kemenag';

  @override
  List<Surah> listSurah() =>
      _select('SELECT * FROM surah ORDER BY number').map(_surah).toList();

  @override
  Surah getSurah(int number) {
    final rows = _select('SELECT * FROM surah WHERE number = ?', [number]);
    if (rows.isEmpty) throw ContentUnavailable('Surah $number tidak ditemukan');
    return _surah(rows.first);
  }

  @override
  List<Ayah> listAyah(int surahNumber) => _select(
    'SELECT $_ayahCols FROM ayah WHERE surah_number = ? ORDER BY ayah_number',
    [surahNumber],
  ).map(_ayah).toList();

  @override
  Ayah getAyah(AyahRef ref) {
    final rows = _select(
      'SELECT $_ayahCols FROM ayah WHERE surah_number = ? AND ayah_number = ?',
      [ref.surah, ref.ayah],
    );
    if (rows.isEmpty) {
      throw ContentUnavailable('Ayat ${ref.surah}:${ref.ayah} tidak ditemukan');
    }
    return _ayah(rows.first);
  }

  /// Ayat from [start] to [end] inclusive, across surahs, in one query.
  /// Throws ContentUnavailable for refs outside the surah table or start > end.
  List<Ayah> getAyahRange(AyahRef start, AyahRef end) {
    for (final r in [start, end]) {
      final count = _select('SELECT ayah_count FROM surah WHERE number = ?', [
        r.surah,
      ]);
      if (count.isEmpty ||
          r.ayah < 1 ||
          r.ayah > (count.first['ayah_count'] as int)) {
        throw ContentUnavailable('Ayat ${r.surah}:${r.ayah} tidak valid');
      }
    }
    if (start.surah > end.surah ||
        (start.surah == end.surah && start.ayah > end.ayah)) {
      throw ContentUnavailable(
        'Rentang ${start.surah}:${start.ayah}-${end.surah}:${end.ayah} '
        'tidak valid',
      );
    }
    return _select(
      'SELECT $_ayahCols FROM ayah '
      'WHERE (surah_number, ayah_number) >= (?, ?) '
      'AND (surah_number, ayah_number) <= (?, ?) '
      'ORDER BY surah_number, ayah_number',
      [start.surah, start.ayah, end.surah, end.ayah],
    ).map(_ayah).toList();
  }

  @override
  List<Juz> listJuz() => _select('SELECT * FROM juz ORDER BY number')
      .map(
        (r) => Juz(
          number: r['number'] as int,
          startSurah: r['start_surah'] as int,
          startAyah: r['start_ayah'] as int,
          endSurah: r['end_surah'] as int,
          endAyah: r['end_ayah'] as int,
        ),
      )
      .toList();
}
