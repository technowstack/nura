import 'dart:io';
import 'dart:typed_data';

import 'package:nura/content_pipeline/content_db_builder.dart';

import 'fixtures.dart';

/// Builds a content.db from the fixture tree under [dir]. With [changed], a
/// copy of the tree with one edited name is used so the db bytes differ.
({Uint8List bytes, String version, File file}) buildFixtureDb(
  Directory dir,
  String name, {
  bool changed = false,
}) {
  // The changed copy keeps the original CHECKSUMS.sha256: unverifiable, same data_version.
  var src = fixtureDir('');
  if (changed) {
    src = Directory('${dir.path}/$name-src')..createSync(recursive: true);
    for (final f in fixtureDir(
      '',
    ).listSync(recursive: true).whereType<File>()) {
      final rel = f.path
          .substring(fixtureDir('').path.length)
          .replaceFirst(RegExp('^/'), '');
      File('${src.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          rel == 'quran/1.json'
              ? f.readAsStringSync().replaceFirst('Al-Fatihah', 'Al-Fatihah-2')
              : f.readAsStringSync(),
        );
    }
  }
  final out = File('${dir.path}/$name.db');
  final r = buildContentDb(sourceRoot: src, output: out);
  return (bytes: out.readAsBytesSync(), version: r.contentVersion, file: out);
}
