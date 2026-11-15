import 'dart:io';

import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/content_pipeline/content_schema.dart';
import 'package:sqlite3/sqlite3.dart';

typedef HadithRow = ({int number, String arab, String translation});

/// Builds a small content.db in [dir] and opens it read-only.
/// [books] maps slug to (name, sortOrder); [rows] maps slug to its hadith.
ContentDatabase buildHadithDb(
  Directory dir, {
  required Map<String, (String, int)> books,
  required Map<String, List<HadithRow>> rows,
}) {
  final file = File(
    '${dir.path}/hadith-${DateTime.now().microsecondsSinceEpoch}.db',
  );
  final db = sqlite3.open(file.path);
  for (final ddl in contentSchemaDdl) {
    db.execute(ddl);
  }
  db.execute(
    "INSERT INTO meta VALUES ('data_version','test'),('schema_version','1')",
  );
  db.execute('BEGIN');
  for (final e in books.entries) {
    db.execute('INSERT INTO hadith_book VALUES (?,?,?,?)', [
      e.key,
      e.value.$1,
      rows[e.key]?.length ?? 0,
      e.value.$2,
    ]);
  }
  for (final e in rows.entries) {
    for (final r in e.value) {
      db.execute(
        'INSERT INTO hadith (book_slug, number, arab, translation_id, translation_length) VALUES (?,?,?,?,?)',
        [e.key, r.number, r.arab, r.translation, r.translation.length],
      );
    }
  }
  db.execute('COMMIT');
  db.dispose();
  return ContentDatabase.open(file);
}
