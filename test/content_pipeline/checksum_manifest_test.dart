import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/checksum_manifest.dart';

import '../support/fixtures.dart';

void main() {
  ChecksumManifest fixtureManifest() => ChecksumManifest.parse(
    File(fixturePath('CHECKSUMS.sha256')).readAsStringSync(),
  );

  Directory tempCopy() {
    final tmp = Directory.systemTemp.createTempSync('nura_fixture_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final root = fixtureDir('').absolute.path.replaceFirst(RegExp(r'/$'), '');
    for (final f in fixtureDir(
      '',
    ).listSync(recursive: true).whereType<File>()) {
      final rel = f.absolute.path.substring(root.length + 1);
      final dest = File('${tmp.path}/$rel')..createSync(recursive: true);
      dest.writeAsBytesSync(f.readAsBytesSync());
    }
    return tmp;
  }

  test('fixture manifest verifies clean', () {
    expect(fixtureManifest().verify(fixtureDir('')), isEmpty);
  });

  test('detects modified file', () {
    final tmp = tempCopy();
    File(
      '${tmp.path}/hadith/darimi.json',
    ).writeAsStringSync(' ', mode: FileMode.append);
    expect(
      fixtureManifest().verify(tmp),
      contains(contains('hadith/darimi.json')),
    );
  });

  test('detects missing and unlisted files', () {
    final tmp = tempCopy();
    File('${tmp.path}/quran/1.json').deleteSync();
    File('${tmp.path}/meta/extra.json').writeAsStringSync('{}');
    final problems = fixtureManifest().verify(tmp);
    expect(problems, contains(contains('quran/1.json')));
    expect(problems, contains(contains('meta/extra.json')));
  });

  test('parse rejects malformed lines and ignores blank ones', () {
    expect(
      () => ChecksumManifest.parse('abc quran/1.json'),
      throwsFormatException,
    );
    expect(ChecksumManifest.parse('\n\n').entries, isEmpty);
  });

  test('toJson is sorted', () {
    final m = ChecksumManifest.parse(
      '${'b' * 64}  z.json\n${'a' * 64}  a.json\n',
    );
    expect(m.toJson(), '{"a.json":"${'a' * 64}","z.json":"${'b' * 64}"}');
  });
}
