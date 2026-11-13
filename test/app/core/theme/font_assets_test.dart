import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // pubspec.yaml is parsed as text to avoid adding a yaml dependency.
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final fontsSection = pubspec.split(RegExp(r'^  fonts:', multiLine: true));
  final fonts = fontsSection.length > 1 ? fontsSection.last : '';

  test('Plus Jakarta Sans is registered with weights 400, 500, 600', () {
    expect(fonts, contains('family: Plus Jakarta Sans'));
    for (final w in [400, 500, 600]) {
      expect(fonts, contains('weight: $w'));
    }
  });

  test('every declared font file exists and OFL.txt sits next to them', () {
    final files = RegExp(r'asset:\s*(\S+)').allMatches(fonts).map((m) => m[1]!);
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    expect(File('assets/fonts/PlusJakartaSans/OFL.txt').existsSync(), isTrue);
  });

  test('LPMQ Isep Misbah stays unregistered (license question Q6)', () {
    expect(pubspec, isNot(contains('LPMQ')));
  });
}
