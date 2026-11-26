import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release is never signed with the debug key', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, isNot(contains('getByName("debug")')));
    expect(gradle, contains('signingConfigs.getByName("release")'));
    expect(gradle, contains('android/key.properties tidak ditemukan'));
  });

  test('signing secrets are ignored, the example is not', () {
    bool ignored(String path) =>
        Process.runSync('git', [
          'check-ignore',
          '--no-index',
          '-q',
          path,
        ]).exitCode ==
        0;

    for (final path in [
      'android/key.properties',
      'android/upload.jks',
      'android/app/upload.keystore',
      'upload.jks',
      'upload.keystore',
      'key.properties',
    ]) {
      expect(ignored(path), isTrue, reason: path);
    }
    expect(ignored('android/key.properties.example'), isFalse);
  });
}
