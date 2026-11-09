import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/app/data/sources/content_db_installer.dart';
import 'package:nura/content_pipeline/content_db_builder.dart';

import '../support/fixtures.dart';

void main() {
  late Directory tmp;
  late Directory target;
  late Uint8List v1;
  late Uint8List v2;

  Uint8List build(String version) {
    final out = File('${tmp.path}/$version.db');
    buildContentDb(
      sourceRoot: fixtureDir(''),
      output: out,
      dataVersion: version,
      builtAt: DateTime.utc(2026, 11, 9),
    );
    return out.readAsBytesSync();
  }

  setUp(() {
    loads = 0;
    tmp = Directory.systemTemp.createTempSync('nura_inst_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    target = Directory('${tmp.path}/target');
    v1 = build('test-1');
    v2 = build('test-2');
  });

  var loads = 0;
  ContentDbInstaller installer(Uint8List bytes) => ContentDbInstaller(
    loadAsset: (key) async {
      loads++;
      expect(key, contentDbAssetKey);
      return bytes;
    },
    targetDir: target,
  );

  String versionOf(File f) {
    final db = ContentDatabase.open(f);
    addTearDown(db.close);
    return db.dataVersion;
  }

  test('installs when target missing', () async {
    final f = await installer(v1).ensureInstalled();
    expect(f.path, '${target.path}/content.db');
    expect(versionOf(f), 'test-1');
  });

  test('does not recopy when data_version matches', () async {
    final f = await installer(v1).ensureInstalled();
    final before = f.lastModifiedSync();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loads, 1);
    await installer(v1).ensureInstalled();
    expect(loads, 2);
    expect(f.lastModifiedSync(), before);
    expect(File('${f.path}.tmp').existsSync(), isFalse);
  });

  test('recopies when asset data_version differs', () async {
    await installer(v1).ensureInstalled();
    final f = await installer(v2).ensureInstalled();
    expect(versionOf(f), 'test-2');
  });

  test('leftover .tmp from interrupted copy is replaced', () async {
    target.createSync(recursive: true);
    File('${target.path}/content.db.tmp').writeAsStringSync('junk');
    final f = await installer(v1).ensureInstalled();
    expect(versionOf(f), 'test-1');
    expect(File('${f.path}.tmp').existsSync(), isFalse);
  });

  test('corrupt existing content.db is replaced', () async {
    target.createSync(recursive: true);
    File('${target.path}/content.db').writeAsStringSync('junk' * 100);
    final f = await installer(v1).ensureInstalled();
    expect(versionOf(f), 'test-1');
  });

  test('junk asset keeps existing valid content.db', () async {
    final f = await installer(v1).ensureInstalled();
    await expectLater(
      installer(Uint8List.fromList(List.filled(500, 7))).ensureInstalled(),
      throwsStateError,
    );
    expect(versionOf(f), 'test-1');
    expect(File('${f.path}.tmp').existsSync(), isFalse);
  });

  test('junk asset with no existing db throws and creates nothing', () async {
    await expectLater(
      installer(Uint8List.fromList(List.filled(500, 7))).ensureInstalled(),
      throwsStateError,
    );
    expect(File('${target.path}/content.db').existsSync(), isFalse);
    expect(File('${target.path}/content.db.tmp').existsSync(), isFalse);
  });
}
