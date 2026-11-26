import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/content_db_installer.dart';

const _res = 'android/app/src/main/res/xml';

// getApplicationSupportDirectory() is Context.getFilesDir(): domain "file".
const _expected = {
  'file:user.db',
  'file:user.db-journal',
  'file:user.db-wal',
  'file:user.db-shm',
  'sharedpref:.',
};

String _read(String path) => File(
  path,
).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

String _section(String xml, String tag) =>
    RegExp('<$tag>(.*?)</$tag>', dotAll: true).firstMatch(xml)?.group(1) ?? '';

/// "domain:path" of every include element.
List<String> _includes(String xml) => [
  for (final m in RegExp(r'<include\b[^>]*>').allMatches(xml))
    '${RegExp(r'domain="([^"]*)"').firstMatch(m[0] ?? '')?.group(1)}:'
        '${RegExp(r'path="([^"]*)"').firstMatch(m[0] ?? '')?.group(1)}',
];

/// Whether an include would back up [file], a path relative to getFilesDir().
bool _covers(String include, String file) {
  final colon = include.indexOf(':');
  final domain = include.substring(0, colon);
  // Domain "root" is the app data directory, which contains files/.
  final target = switch (domain) {
    'file' => file,
    'root' => 'files/$file',
    _ => null,
  };
  if (target == null) return false;
  final path = include
      .substring(colon + 1)
      .replaceFirst(RegExp(r'^\./'), '')
      .replaceFirst(RegExp(r'/$'), '');
  return path == '.' ||
      path.isEmpty ||
      target == path ||
      target.startsWith('$path/');
}

void main() {
  final contentDb = contentDbAssetKey.split('/').last;
  final excluded = [
    contentDb,
    '$contentDb.tmp',
    contentVersionAssetKey.split('/').last,
    'widget/daily_ayah.png',
  ];

  List<String> leaks(String xml) => [
    for (final i in _includes(xml))
      for (final f in excluded)
        if (_covers(i, f)) '$i covers $f',
  ];

  final full = _section(_read('$_res/backup_rules.xml'), 'full-backup-content');
  final extraction = _read('$_res/data_extraction_rules.xml');
  final sections = {
    'full-backup-content': full,
    'cloud-backup': _section(extraction, 'cloud-backup'),
    'device-transfer': _section(extraction, 'device-transfer'),
  };

  test('manifest enables backup and references both rule files', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    for (final attribute in [
      'android:allowBackup="true"',
      'android:dataExtractionRules="@xml/data_extraction_rules"',
      'android:fullBackupContent="@xml/backup_rules"',
    ]) {
      expect(manifest, contains(attribute));
    }
  });

  test('the app still stores its files where the rules assume', () {
    expect(
      File('lib/main.dart').readAsStringSync(),
      contains('await getApplicationSupportDirectory()'),
    );
    final bootstrap = File('lib/app/app_bootstrap.dart').readAsStringSync();
    expect(bootstrap, contains(r"'${dataDir.path}/user.db'"));
    expect(bootstrap, contains(r"'${dataDir.path}/widget'"));
  });

  for (final MapEntry(key: name, value: xml) in sections.entries) {
    test('$name includes only user data', () {
      expect(_includes(xml), unorderedEquals(_expected));
      expect(xml, isNot(contains('<exclude')));
      expect(leaks(xml), isEmpty);
    });
  }

  test('the check catches includes that would back up content', () {
    for (final bad in [
      '<include domain="file" path="." />',
      '<include domain="file" path="./" />',
      '<include domain="file" path="widget/" />',
      '<include path="content.db" domain="file" />',
      '<include domain="root" path="." />',
      '<include domain="root" path="files" />',
    ]) {
      expect(leaks('$full\n$bad'), isNotEmpty, reason: bad);
    }
  });
}
