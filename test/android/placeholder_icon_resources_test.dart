import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

String _read(String path) => File('$_res/$path').readAsStringSync();

/// Resolves a Figma variable (Light = mode1, Dark = mode2) to `#AARRGGBB`.
String _token(Map<String, dynamic> tokens, String name, String mode) {
  Map<String, dynamic>? found;
  void walk(Object? o) {
    if (o is Map<String, dynamic>) {
      if (o['name'] == name && o['valuesByMode'] != null) found = o;
      o.values.forEach(walk);
    } else if (o is List) {
      o.forEach(walk);
    }
  }

  walk(tokens);
  final byMode =
      (found?['valuesByMode'] as Map<String, dynamic>).entries
              .firstWhere((e) => e.key.endsWith(mode))
              .value
          as Map<String, dynamic>;
  String h(String k) =>
      ((byMode[k] as num) * 255).round().toRadixString(16).padLeft(2, '0');
  return '#FF${h('r')}${h('g')}${h('b')}'.toUpperCase();
}

String _color(String xml, String name) {
  final m = RegExp('name="$name">(#[0-9A-Fa-f]{8})<').firstMatch(xml);
  expect(m, isNotNull, reason: 'missing color $name');
  return m!.group(1)!.toUpperCase(); // guarded by expect above
}

void main() {
  final tokens =
      jsonDecode(File('docs/design/tokens.json').readAsStringSync())
          as Map<String, dynamic>;

  test('adaptive icon declares background, foreground and monochrome', () {
    final xml = _read('mipmap-anydpi-v26/ic_launcher.xml');
    for (final tag in ['background', 'foreground', 'monochrome']) {
      expect(xml, contains('<$tag '));
    }
  });

  test('color resources match design tokens (light and dark)', () {
    final light = _read('values/colors.xml');
    final dark = _read('values-night/colors.xml');
    expect(
      _color(light, 'nura_icon_background'),
      _token(tokens, 'ext/hero', 'mode1'),
    );
    expect(
      _color(light, 'nura_icon_star'),
      _token(tokens, 'ext/onHeroAccent', 'mode1'),
    );
    expect(
      _color(light, 'nura_splash_background'),
      _token(tokens, 'surface', 'mode1'),
    );
    expect(
      _color(light, 'nura_splash_star'),
      _token(tokens, 'ext/iconAccent', 'mode1'),
    );
    expect(
      _color(dark, 'nura_icon_background'),
      _token(tokens, 'ext/hero', 'mode2'),
    );
    expect(
      _color(dark, 'nura_icon_star'),
      _token(tokens, 'ext/onHeroAccent', 'mode2'),
    );
    expect(
      _color(dark, 'nura_splash_background'),
      _token(tokens, 'surface', 'mode2'),
    );
    expect(
      _color(dark, 'nura_splash_star'),
      _token(tokens, 'ext/iconAccent', 'mode2'),
    );
  });

  test('launch themes exist for light, night and v31', () {
    for (final dir in [
      'values',
      'values-night',
      'values-v31',
      'values-night-v31',
    ]) {
      final xml = _read('$dir/styles.xml');
      expect(xml, contains('name="LaunchTheme"'), reason: dir);
      expect(xml, contains('name="NormalTheme"'), reason: dir);
    }
    for (final dir in ['values-v31', 'values-night-v31']) {
      expect(
        _read('$dir/styles.xml'),
        contains('windowSplashScreenBackground'),
      );
    }
  });

  test('pubspec has no launcher icon or splash generators', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('flutter_launcher_icons')));
    expect(pubspec, isNot(contains('flutter_native_splash')));
  });
}
