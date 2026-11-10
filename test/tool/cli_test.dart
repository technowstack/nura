import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';

void main() {
  late Directory tmp;
  late String out;
  final src = fixtureDir('').path;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cli_test');
    out = '${tmp.path}/content.db';
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<ProcessResult> build() => Process.run('dart', [
    'run',
    'tool/build_content_db.dart',
    '--source',
    src,
    '--out',
    out,
  ]);

  test('build then verify on fixture exits 0', () async {
    final b = await build();
    expect(b.exitCode, 0, reason: '${b.stderr}');
    final v = await Process.run('dart', [
      'run',
      'tool/verify_content_db.dart',
      '--source',
      src,
      '--db',
      out,
    ]);
    expect(v.exitCode, 0, reason: '${v.stdout}');
  });

  test('verify --full on fixture exits 1', () async {
    await build();
    final v = await Process.run('dart', [
      'run',
      'tool/verify_content_db.dart',
      '--source',
      src,
      '--db',
      out,
      '--full',
    ]);
    expect(v.exitCode, 1);
  });
}
