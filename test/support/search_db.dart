import 'dart:io';

import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/content_pipeline/content_schema.dart';
import 'package:nura/content_pipeline/text_normalizer.dart';
import 'package:sqlite3/sqlite3.dart';

typedef SearchAyahRow = ({
  int surah,
  int ayah,
  String arab,
  String translation,
});
typedef SearchHadithRow = ({
  String slug,
  int number,
  String arab,
  String translation,
});

/// Builds a small content.db with search indexes in [dir] and opens it
/// read-only. Row ids follow list order (like the production builder), so
/// pass [ayahs] and [hadith] in reading order. [surahs] maps number to
/// `name_latin`; [books] maps slug to name, its iteration order is
/// `sort_order`. FTS rows go through the same normalizers as the builder.
ContentDatabase buildSearchDb(
  Directory dir, {
  Map<int, String> surahs = const {},
  List<SearchAyahRow> ayahs = const [],
  Map<String, String> books = const {},
  List<SearchHadithRow> hadith = const [],
}) {
  final file = File('${dir.path}/search.db');
  final db = sqlite3.open(file.path);
  for (final ddl in contentSchemaDdl) {
    db.execute(ddl);
  }
  db.execute(
    "INSERT INTO meta VALUES ('data_version','test'),('schema_version','1')",
  );
  db.execute('BEGIN');
  for (final e in surahs.entries) {
    db.execute('INSERT INTO surah VALUES (?,?,?,?,?,?)', [
      e.key,
      '',
      e.value,
      '',
      ayahs.where((a) => a.surah == e.key).length,
      'Makkiyah',
    ]);
  }
  for (final (i, a) in ayahs.indexed) {
    db.execute('INSERT INTO ayah VALUES (?,?,?,?,?,?)', [
      i + 1,
      a.surah,
      a.ayah,
      a.arab,
      a.translation,
      '',
    ]);
    db.execute(
      'INSERT INTO ayah_fts(rowid, arab, translation) VALUES (?,?,?)',
      [
        i + 1,
        normalizeAyahArabicForIndex(a.arab),
        normalizeIndonesianForSearch(a.translation),
      ],
    );
  }
  for (final (i, e) in books.entries.indexed) {
    db.execute('INSERT INTO hadith_book VALUES (?,?,?,?)', [
      e.key,
      e.value,
      hadith.where((h) => h.slug == e.key).length,
      i,
    ]);
  }
  for (final (i, h) in hadith.indexed) {
    db.execute('INSERT INTO hadith VALUES (?,?,?,?,?,?)', [
      i + 1,
      h.slug,
      h.number,
      h.arab,
      h.translation,
      h.translation.length,
    ]);
    db.execute(
      'INSERT INTO hadith_fts(rowid, arab, translation) VALUES (?,?,?)',
      [
        i + 1,
        normalizeArabicForSearch(h.arab),
        normalizeIndonesianForSearch(h.translation),
      ],
    );
  }
  db.execute('COMMIT');
  db.dispose();
  return ContentDatabase.open(file);
}
