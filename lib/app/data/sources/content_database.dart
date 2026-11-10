import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Read-only handle on the bundled content.db.
class ContentDatabase {
  ContentDatabase._(this.raw, this.dataVersion, this.schemaVersion);

  static ContentDatabase open(File file) {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      String meta(String key) =>
          db.select('SELECT value FROM meta WHERE key = ?', [
                key,
              ]).single['value']
              as String;
      return ContentDatabase._(
        db,
        meta('data_version'),
        meta('schema_version'),
      );
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  final Database raw;
  final String dataVersion;
  final String schemaVersion;

  void close() => raw.dispose();
}
