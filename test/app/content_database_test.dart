import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/content_pipeline/content_db_builder.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fixtures.dart';

void main() {
  late ContentDatabase db;

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('nura_cdb_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/content.db');
    buildContentDb(
      sourceRoot: fixtureDir(''),
      output: file,
      builtAt: DateTime.utc(2026, 11, 9),
    );
    db = ContentDatabase.open(file);
    addTearDown(db.close);
  });

  test('exposes data_version from meta', () {
    expect(db.dataVersion, matches(RegExp(r'^[0-9a-f]{16}$')));
  });

  test('rejects writes', () {
    expect(
      () => db.raw.execute('DELETE FROM ayah'),
      throwsA(isA<SqliteException>()),
    );
  });
}
