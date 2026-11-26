import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';
const _src = 'assets/icon';

String _read(String path) => File(path).readAsStringSync();

List<String?> _all(String xml, String attribute) => [
  for (final m in RegExp('\\s$attribute="([^"]*)"').allMatches(xml)) m.group(1),
];

void main() {
  test('adaptive icon references background, foreground and monochrome', () {
    final xml = _read('$_res/mipmap-anydpi-v26/ic_launcher.xml');
    for (final layer in [
      '<background android:drawable="@color/nura_icon_background"',
      '<foreground android:drawable="@drawable/ic_launcher_foreground"',
      '<monochrome android:drawable="@drawable/ic_launcher_monochrome"',
    ]) {
      expect(xml, contains(layer));
    }
  });

  test('vectors keep the owner paths, colours and order', () {
    const pairs = {
      'ic_launcher_foreground': 'adaptive/foreground',
      'ic_launcher_monochrome': 'adaptive/monochrome',
      'nura_splash_icon': 'splash/splash_icon',
    };
    for (final MapEntry(key: vector, value: svg) in pairs.entries) {
      final xml = _read('$_res/drawable/$vector.xml');
      final source = _read('$_src/$svg.svg');
      final paths = _all(source, 'd');
      expect(paths, isNotEmpty, reason: svg);
      expect(_all(xml, 'android:pathData'), paths, reason: vector);
      expect(_all(xml, 'android:fillColor'), _all(source, 'fill'));
      expect(
        _all(xml, 'android:fillType'),
        List.filled(paths.length, 'evenOdd'),
      );
    }
  });

  test('splash vector maps the owner viewBox to 288 dp', () {
    expect(
      _read('$_src/splash/splash_icon.svg'),
      contains('viewBox="4.5 4.5 99 99"'),
    );
    final xml = _read('$_res/drawable/nura_splash_icon.xml');
    for (final value in [
      'android:width="288dp"',
      'android:height="288dp"',
      'android:viewportWidth="99"',
      'android:viewportHeight="99"',
      'android:translateX="-4.5"',
      'android:translateY="-4.5"',
    ]) {
      expect(xml, contains(value));
    }
  });

  test(
    'background colours are the owner background, with no night variant',
    () {
      final fill = _all(_read('$_src/adaptive/background.svg'), 'fill').single;
      final argb = '#FF${fill?.substring(1)}';
      final colors = _read('$_res/values/colors.xml');
      for (final name in ['nura_icon_background', 'nura_splash_background']) {
        expect(colors, contains('<color name="$name">$argb</color>'));
      }
      expect(File('$_res/values-night/colors.xml').existsSync(), isFalse);
    },
  );

  test('every launch theme and background uses the splash artwork', () {
    for (final dir in ['values-v31', 'values-night-v31']) {
      final xml = _read('$_res/$dir/styles.xml');
      expect(
        xml,
        contains('SplashScreenAnimatedIcon">@drawable/nura_splash_icon<'),
      );
      expect(
        xml,
        contains('SplashScreenBackground">@color/nura_splash_background<'),
      );
    }
    for (final dir in ['drawable', 'drawable-v21']) {
      final xml = _read('$_res/$dir/launch_background.xml');
      expect(xml, contains('@drawable/nura_splash_icon'));
      expect(xml, contains('@color/nura_splash_background'));
    }
    for (final dir in ['values', 'values-night']) {
      expect(
        _read('$_res/$dir/styles.xml'),
        contains('windowBackground">@drawable/launch_background<'),
      );
    }
  });

  test('legacy and notification PNGs are byte copies of the owner files', () {
    const densities = {
      'mdpi': (48, 24),
      'hdpi': (72, 36),
      'xhdpi': (96, 48),
      'xxhdpi': (144, 72),
      'xxxhdpi': (192, 96),
    };
    for (final MapEntry(key: d, value: (launcher, stat)) in densities.entries) {
      expect(
        File('$_res/mipmap-$d/ic_launcher.png').readAsBytesSync(),
        File('$_src/legacy/ic_launcher-$d-$launcher.png').readAsBytesSync(),
        reason: d,
      );
      expect(
        File('$_res/drawable-$d/ic_stat_nura.png').readAsBytesSync(),
        File('$_src/notification/ic_stat_nura-$d-$stat.png').readAsBytesSync(),
        reason: d,
      );
    }
  });

  test('resource shrinking keeps the notification icon', () {
    expect(
      _read('$_res/raw/keep.xml'),
      contains('tools:keep="@drawable/ic_stat_nura"'),
    );
  });

  test('no icon generators, and logo sources are not bundled', () {
    final pubspec = _read('pubspec.yaml');
    expect(pubspec, isNot(contains('flutter_launcher_icons')));
    expect(pubspec, isNot(contains('flutter_native_splash')));
    expect(pubspec, isNot(contains('assets/icon')));
  });
}
