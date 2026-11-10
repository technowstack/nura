import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/content_db_installer.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fixture_db.dart';

void main() {
  late Directory tmp;
  late Directory target;
  late ({Uint8List bytes, String version, File file}) v1;
  late ({Uint8List bytes, String version, File file}) v2;
  var loads = 0;

  setUp(() {
    loads = 0;
    tmp = Directory.systemTemp.createTempSync('nura_inst_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    target = Directory('${tmp.path}/target');
    v1 = buildFixtureDb(tmp, 'v1');
    v2 = buildFixtureDb(tmp, 'v2', changed: true);
  });

  ContentDbInstaller installer(Uint8List bytes, String version) =>
      ContentDbInstaller(
        copyAsset: (key, dest) async {
          loads++;
          expect(key, contentDbAssetKey);
          await dest.writeAsBytes(bytes, flush: true);
        },
        loadVersion: (key) async {
          expect(key, contentVersionAssetKey);
          return '$version\n';
        },
        targetDir: target,
      );

  File versionFile() => File('${target.path}/content.version');

  String nameOf(File f) {
    final db = sqlite3.open(f.path, mode: OpenMode.readOnly);
    addTearDown(db.dispose);
    return db
            .select('SELECT name_latin FROM surah WHERE number = 1')
            .single
            .values
            .first
        as String;
  }

  test('installs db and writes version file last', () async {
    final f = await installer(v1.bytes, v1.version).ensureInstalled();
    expect(f.path, '${target.path}/content.db');
    expect(nameOf(f), 'Al-Fatihah');
    expect(versionFile().readAsStringSync(), v1.version);
    expect(File('${versionFile().path}.tmp').existsSync(), isFalse);
  });

  test('second start does not load the db asset', () async {
    final f = await installer(v1.bytes, v1.version).ensureInstalled();
    final before = f.lastModifiedSync();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(loads, 1);
    await installer(v1.bytes, v1.version).ensureInstalled();
    expect(loads, 1);
    expect(f.lastModifiedSync(), before);
  });

  test('recopies when asset version differs', () async {
    await installer(v1.bytes, v1.version).ensureInstalled();
    final f = await installer(v2.bytes, v2.version).ensureInstalled();
    expect(loads, 2);
    expect(nameOf(f), 'Al-Fatihah-2');
    expect(versionFile().readAsStringSync(), v2.version);
  });

  test(
    'rejects asset whose meta schema disagrees with content.version',
    () async {
      await installer(v1.bytes, v1.version).ensureInstalled();
      final hash = v1.version.split(':').last;
      // Asset claims another schema: installed version no longer matches and
      // the asset's meta schema_version disagrees, so it is rejected.
      await expectLater(
        installer(v1.bytes, '99:$hash').ensureInstalled(),
        throwsStateError,
      );
      expect(loads, 2);
      expect(versionFile().readAsStringSync(), v1.version);
    },
  );

  test('recopies when installed schema_version part differs', () async {
    await installer(v1.bytes, v1.version).ensureInstalled();
    versionFile().writeAsStringSync('0:${v1.version.split(':').last}');
    await installer(v1.bytes, v1.version).ensureInstalled();
    expect(loads, 2);
    expect(versionFile().readAsStringSync(), v1.version);
  });

  test('recopies when installed version file is missing', () async {
    await installer(v1.bytes, v1.version).ensureInstalled();
    versionFile().deleteSync();
    await installer(v1.bytes, v1.version).ensureInstalled();
    expect(loads, 2);
    expect(versionFile().readAsStringSync(), v1.version);
  });

  test('leftover .tmp from interrupted copy is replaced', () async {
    target.createSync(recursive: true);
    File('${target.path}/content.db.tmp').writeAsStringSync('junk');
    final f = await installer(v1.bytes, v1.version).ensureInstalled();
    expect(nameOf(f), 'Al-Fatihah');
    expect(File('${f.path}.tmp').existsSync(), isFalse);
  });

  test('corrupt existing content.db is replaced', () async {
    target.createSync(recursive: true);
    File('${target.path}/content.db').writeAsStringSync('junk' * 100);
    versionFile().writeAsStringSync(v1.version);
    final f = await installer(v1.bytes, v1.version).ensureInstalled();
    expect(loads, 1);
    expect(nameOf(f), 'Al-Fatihah');
  });

  test('junk asset keeps existing valid content.db and version', () async {
    final f = await installer(v1.bytes, v1.version).ensureInstalled();
    await expectLater(
      installer(
        Uint8List.fromList(List.filled(500, 7)),
        'x:y',
      ).ensureInstalled(),
      throwsStateError,
    );
    expect(nameOf(f), 'Al-Fatihah');
    expect(versionFile().readAsStringSync(), v1.version);
    expect(File('${f.path}.tmp').existsSync(), isFalse);
  });

  test('junk asset with no existing db throws and creates nothing', () async {
    await expectLater(
      installer(
        Uint8List.fromList(List.filled(500, 7)),
        'x:y',
      ).ensureInstalled(),
      throwsStateError,
    );
    expect(File('${target.path}/content.db').existsSync(), isFalse);
    expect(File('${target.path}/content.db.tmp').existsSync(), isFalse);
    expect(versionFile().existsSync(), isFalse);
  });

  test('copier failure keeps existing db and leaves no .tmp', () async {
    final f = await installer(v1.bytes, v1.version).ensureInstalled();
    final failing = ContentDbInstaller(
      copyAsset: (key, dest) async {
        await dest.writeAsBytes([1, 2, 3]);
        throw const FileSystemException('disk full');
      },
      loadVersion: (_) async => v2.version,
      targetDir: target,
    );
    await expectLater(
      failing.ensureInstalled(),
      throwsA(isA<FileSystemException>()),
    );
    expect(nameOf(f), 'Al-Fatihah');
    expect(versionFile().readAsStringSync(), v1.version);
    expect(File('${f.path}.tmp').existsSync(), isFalse);
  });
}
