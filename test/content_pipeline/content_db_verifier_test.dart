import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/content_db_builder.dart';
import 'package:nura/content_pipeline/content_db_verifier.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fixtures.dart';

void main() {
  late Directory tempDir;
  late File built;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nura_verify_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    built = File('${tempDir.path}/content.db');
    buildContentDb(sourceRoot: fixtureDir(''), output: built, dataVersion: 't');
  });

  VerificationReport verifyTampered(String sql, {Directory? source}) {
    final copy = built.copySync('${tempDir.path}/tampered.db');
    final db = sqlite3.open(copy.path)..execute(sql);
    db.dispose();
    return verifyContentDb(
      sourceRoot: source ?? fixtureDir(''),
      database: copy,
    );
  }

  Directory sourceCopy() {
    final dst = Directory('${tempDir.path}/src')..createSync();
    for (final f in fixtureDir(
      '',
    ).listSync(recursive: true).whereType<File>()) {
      final rel = f.path
          .substring(fixtureDir('').path.length)
          .replaceFirst(RegExp('^/'), '');
      File('${dst.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsBytesSync(f.readAsBytesSync());
    }
    return dst;
  }

  test('freshly built fixture db verifies ok', () {
    final r = verifyContentDb(sourceRoot: fixtureDir(''), database: built);
    expect(r.errors, isEmpty);
    expect(r.ok, isTrue);
  });

  test('one changed character in ayah.arab is an error', () {
    final r = verifyTampered("UPDATE ayah SET arab = arab || 'x' WHERE id = 1");
    expect(r.ok, isFalse);
    expect(r.errors.single, contains('ayah 1:1'));
  });

  test('trimmed trailing space in hadith is an error', () {
    final r = verifyTampered(
      'UPDATE hadith SET arab = rtrim(arab) WHERE number = 99999',
    );
    expect(r.ok, isFalse);
    expect(r.errors.single, contains('hadith malik:99999 arab differs'));
  });

  test('missing row is an error', () {
    final r = verifyTampered('DELETE FROM hadith WHERE id = 1');
    expect(r.ok, isFalse);
    expect(r.errors, contains(startsWith('missing hadith ')));
  });

  test('source checksum mismatch is an error', () {
    final src = sourceCopy();
    final f = File('${src.path}/meta/surah_info.json');
    f.writeAsStringSync('${f.readAsStringSync()} ');
    final r = verifyContentDb(sourceRoot: src, database: built);
    expect(r.ok, isFalse);
    expect(r.errors, contains(contains('hash mismatch: meta/surah_info.json')));
  });

  test('meta.source_checksums mismatch is an error', () {
    final r = verifyTampered(
      "UPDATE meta SET value = '{}' WHERE key = 'source_checksums'",
    );
    expect(r.ok, isFalse);
    expect(r.errors.single, contains('source_checksums'));
  });

  test('empty revelation is a warning, not an error', () {
    final r = verifyContentDb(sourceRoot: fixtureDir(''), database: built);
    expect(r.ok, isTrue);
    expect(r.warnings, contains(contains('112')));
  });

  test('expected totals mismatch is an error', () {
    final r = verifyContentDb(
      sourceRoot: fixtureDir(''),
      database: built,
      expected: fullDatasetTotals,
    );
    expect(r.ok, isFalse);
  });

  test('stale ayah_count is an error', () {
    final r = verifyTampered(
      'UPDATE surah SET ayah_count = 99 WHERE number = 1',
    );
    expect(r.ok, isFalse);
  });
}
