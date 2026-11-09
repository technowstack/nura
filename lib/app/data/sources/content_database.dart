import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Read-only handle on the bundled content.db.
class ContentDatabase {
  ContentDatabase._(this.raw, this.dataVersion);

  static ContentDatabase open(File file) {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        "SELECT value FROM meta WHERE key = 'data_version'",
      );
      return ContentDatabase._(db, rows.single['value'] as String);
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  final Database raw;
  final String dataVersion;

  void close() => raw.dispose();
}
