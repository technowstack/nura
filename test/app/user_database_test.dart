import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  late File file;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_udb_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    file = File('${tmp.path}/user.db');
  });

  test('fresh open creates all v1 tables and sets user_version 1', () {
    final db = UserDatabase.open(file);
    addTearDown(db.close);
    final tables = db.raw
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((r) => r['name'])
        .toSet();
    expect(
      tables,
      containsAll([
        'setting',
        'bookmark',
        'last_read',
        'prayer_location',
        'prayer_day',
        'audio_download',
      ]),
    );
    expect(db.schemaVersion, 1);
    expect(userSchemaVersion, 1);
    expect(db.raw.select('PRAGMA foreign_keys').single.values.single, 1);
  });

  test('reopen keeps data and does not re-run migration', () {
    var db = UserDatabase.open(file);
    expect(db.getSetting(SettingKeys.themeMode), isNull);
    db.setSetting(SettingKeys.themeMode, 'dark');
    db.setSetting(SettingKeys.themeMode, 'light');
    db.close();
    db = UserDatabase.open(file);
    addTearDown(db.close);
    expect(db.getSetting('theme_mode'), 'light');
  });

  test('creates parent directory if missing', () {
    final nested = File('${tmp.path}/a/b/user.db');
    UserDatabase.open(nested).close();
    expect(nested.existsSync(), isTrue);
  });

  test('bookmark unique constraint rejects duplicates', () {
    final db = UserDatabase.open(file);
    addTearDown(db.close);
    const sql =
        "INSERT INTO bookmark (kind, ref_a, ref_b, created_at) VALUES ('ayah','1',1,0)";
    db.raw.execute(sql);
    expect(() => db.raw.execute(sql), throwsA(isA<SqliteException>()));
  });

  test('database newer than app throws a clear error', () {
    final raw = sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 99');
    raw.dispose();
    expect(
      () => UserDatabase.open(file),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('newer'),
        ),
      ),
    );
  });

  test('failed migration rolls back everything and keeps version', () {
    final migrations = <void Function(Database)>[
      (db) => db.execute('CREATE TABLE a (x INTEGER)'),
      (db) {
        db.execute('CREATE TABLE b (x INTEGER)');
        throw StateError('boom');
      },
    ];
    expect(
      () => UserDatabase.open(file, migrations: migrations),
      throwsA(isA<StateError>()),
    );
    final raw = sqlite3.open(file.path);
    addTearDown(raw.dispose);
    expect(raw.select('PRAGMA user_version').single.values.single, 0);
    expect(
      raw.select("SELECT name FROM sqlite_master WHERE type='table'"),
      isEmpty,
    );
  });
}
