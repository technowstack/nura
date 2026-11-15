import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _expected = {
  'PlusJakartaSans-Regular.ttf': '400',
  'PlusJakartaSans-Medium.ttf': '500',
  'PlusJakartaSans-SemiBold.ttf': '600',
};

/// Returns the problems found in the pubspec text (empty when valid).
/// Parsed as text to avoid adding a yaml dependency.
List<String> checkFontPubspec(String pubspec) {
  final problems = <String>[];
  if (!pubspec.contains('family: Plus Jakarta Sans')) {
    problems.add('missing family Plus Jakarta Sans');
  }
  // Adjacent asset:/weight: entries only.
  final pairs = {
    for (final m in RegExp(
      r'asset:\s*(\S+)\s*\n\s*weight:\s*(\d+)',
    ).allMatches(pubspec))
      m[1]!.split('/').last: m[2]!,
  };
  _expected.forEach((file, weight) {
    if (pairs[file] != weight) {
      problems.add('$file must map to $weight, got ${pairs[file]}');
    }
  });
  if (RegExp(r'family:.*LPMQ').hasMatch(pubspec)) problems.add('LPMQ family');
  if (pubspec.contains('assets/fonts/LPMQ')) problems.add('LPMQ path');
  if (pubspec.contains('Isep')) problems.add('Isep');
  return problems;
}

String _synthetic(String regular, String medium, String semiBold) =>
    '''
  fonts:
    - family: Plus Jakarta Sans
      fonts:
        - asset: assets/fonts/PlusJakartaSans/PlusJakartaSans-Regular.ttf
          weight: $regular
        - asset: assets/fonts/PlusJakartaSans/PlusJakartaSans-Medium.ttf
          weight: $medium
        - asset: assets/fonts/PlusJakartaSans/PlusJakartaSans-SemiBold.ttf
          weight: $semiBold
''';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('pubspec ties each Plus Jakarta Sans file to its weight', () {
    expect(checkFontPubspec(pubspec), isEmpty);
  });

  test('checker accepts a correct synthetic pubspec', () {
    expect(checkFontPubspec(_synthetic('400', '500', '600')), isEmpty);
  });

  test('checker rejects wrong, missing, or swapped weights', () {
    expect(checkFontPubspec(_synthetic('400', '700', '600')), isNotEmpty);
    expect(checkFontPubspec(_synthetic('400', '500', '')), isNotEmpty);
    expect(checkFontPubspec(_synthetic('500', '400', '600')), isNotEmpty);
    expect(
      checkFontPubspec(
        _synthetic('400', '500', '600').split('\n').take(8).join('\n'),
      ),
      isNotEmpty,
    );
  });

  test('checker rejects LPMQ family, path, and Isep', () {
    final ok = _synthetic('400', '500', '600');
    expect(checkFontPubspec('$ok\n    - family: LPMQ Isep'), isNotEmpty);
    expect(
      checkFontPubspec('$ok\n  - asset: assets/fonts/LPMQ/a.ttf'),
      isNotEmpty,
    );
    expect(checkFontPubspec('$ok\n# Isep Misbah'), isNotEmpty);
  });

  test('every declared font file exists and OFL.txt sits next to them', () {
    final files = RegExp(
      r'asset:\s*(\S+)',
    ).allMatches(pubspec).map((m) => m[1]!);
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    expect(File('assets/fonts/PlusJakartaSans/OFL.txt').existsSync(), isTrue);
  });
}
