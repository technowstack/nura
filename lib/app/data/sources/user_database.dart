import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

void _migrateToV1(Database db) {
  db.execute('''
CREATE TABLE setting (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE bookmark (
  id          INTEGER PRIMARY KEY,
  kind        TEXT NOT NULL CHECK (kind IN ('ayah','hadith')),
  ref_a       TEXT NOT NULL,
  ref_b       INTEGER NOT NULL,
  created_at  INTEGER NOT NULL,
  UNIQUE (kind, ref_a, ref_b)
);
CREATE TABLE last_read (
  kind        TEXT PRIMARY KEY CHECK (kind IN ('ayah','hadith')),
  ref_a       TEXT NOT NULL,
  ref_b       INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);
CREATE TABLE prayer_location (
  id        INTEGER PRIMARY KEY CHECK (id = 1),
  source    TEXT NOT NULL CHECK (source IN ('gps','city')),
  label     TEXT NOT NULL,
  lat       REAL NOT NULL,
  lng       REAL NOT NULL,
  city_key  TEXT NOT NULL
);
CREATE TABLE prayer_day (
  date      TEXT NOT NULL,
  city_key  TEXT NOT NULL,
  imsak TEXT, subuh TEXT, terbit TEXT, dhuha TEXT,
  dzuhur TEXT, ashar TEXT, maghrib TEXT, isya TEXT,
  source    TEXT NOT NULL CHECK (source IN ('api','calc')),
  fetched_at INTEGER NOT NULL,
  PRIMARY KEY (date, city_key)
);
CREATE TABLE audio_download (
  qari_id      TEXT NOT NULL,
  surah_number INTEGER NOT NULL,
  status       TEXT NOT NULL CHECK (status IN ('partial','complete')),
  ayah_done    INTEGER NOT NULL,
  bytes        INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  PRIMARY KEY (qari_id, surah_number)
);
''');
}

/// v1 prayer tables were never used (always empty), so they are replaced by
/// the province + kab/kota model and a per-month cache marker.
void _migrateToV2(Database db) {
  db.execute('''
DROP TABLE prayer_location;
DROP TABLE prayer_day;
CREATE TABLE prayer_location (
  id        INTEGER PRIMARY KEY CHECK (id = 1),
  provinsi  TEXT NOT NULL,
  kabkota   TEXT NOT NULL,
  source    TEXT NOT NULL CHECK (source IN ('city','gps'))
);
CREATE TABLE prayer_day (
  date      TEXT NOT NULL,
  provinsi  TEXT NOT NULL,
  kabkota   TEXT NOT NULL,
  imsak TEXT, subuh TEXT, terbit TEXT, dhuha TEXT,
  dzuhur TEXT, ashar TEXT, maghrib TEXT, isya TEXT,
  source    TEXT NOT NULL CHECK (source IN ('api','calc')),
  fetched_at INTEGER NOT NULL,
  PRIMARY KEY (date, provinsi, kabkota)
);
CREATE TABLE prayer_month (
  provinsi  TEXT NOT NULL,
  kabkota   TEXT NOT NULL,
  year      INTEGER NOT NULL,
  month     INTEGER NOT NULL,
  status    TEXT NOT NULL CHECK (status IN ('ok','none')),
  fetched_at INTEGER NOT NULL,
  PRIMARY KEY (provinsi, kabkota, year, month)
);
''');
}

/// Index i migrates the schema from version i to i + 1.
final List<void Function(Database)> _migrations = [
  _migrateToV1,
  _migrateToV2,
];

/// The real migration list, for tests that stop at or fail after a version.
@visibleForTesting
List<void Function(Database)> get userMigrationsForTest => _migrations;

/// Schema version this app build expects in user.db.
final int userSchemaVersion = _migrations.length;

/// Read-write handle on user.db (settings, bookmarks, prayer cache, downloads).
class UserDatabase {
  UserDatabase._(this.raw);

  /// Opens (creating if needed) and migrates [file]. [migrations] is only
  /// overridable for tests.
  static UserDatabase open(
    File file, {
    @visibleForTesting List<void Function(Database)>? migrations,
  }) {
    final steps = migrations ?? _migrations;
    file.parent.createSync(recursive: true);
    final db = sqlite3.open(file.path);
    try {
      db.execute('PRAGMA foreign_keys = ON');
      final current =
          db.select('PRAGMA user_version').single.values.single as int;
      if (current > steps.length) {
        throw StateError(
          'user.db version $current is newer than supported ${steps.length}',
        );
      }
      if (current < steps.length) {
        db.execute('BEGIN');
        try {
          for (var i = current; i < steps.length; i++) {
            steps[i](db);
          }
          db.execute('PRAGMA user_version = ${steps.length}');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      return UserDatabase._(db);
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  final Database raw;

  int get schemaVersion =>
      raw.select('PRAGMA user_version').single.values.single as int;

  /// Returns the stored value, or null when [key] has never been set.
  String? getSetting(String key) {
    final rows = raw.select('SELECT value FROM setting WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  /// Inserts or replaces the value for [key].
  void setSetting(String key, String value) => raw.execute(
    'INSERT INTO setting (key, value) VALUES (?, ?) '
    'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    [key, value],
  );

  void close() => raw.dispose();
}
