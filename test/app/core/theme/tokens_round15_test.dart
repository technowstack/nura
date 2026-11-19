import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/nura_colors.dart';
import 'package:nura/app/core/theme/nura_text_styles.dart';
import 'package:nura/app/core/theme/tokens.dart';

void main() {
  final vars =
      (jsonDecode(File('docs/design/tokens.json').readAsStringSync())
              as Map<String, dynamic>)['meta']['variables']
          as Map<String, dynamic>;

  Map<String, dynamic> byName(String name) =>
      vars.values.firstWhere((v) => (v as Map)['name'] == name)
          as Map<String, dynamic>;

  Color token(String name, int mode) {
    final values = (byName(name)['valuesByMode'] as Map).values.toList();
    final c = values[mode] as Map;
    int ch(String k) => ((c[k] as num) * 255).round();
    return Color.fromARGB(ch('a'), ch('r'), ch('g'), ch('b'));
  }

  for (final mode in [0, 1]) {
    final label = mode == 0 ? 'light' : 'dark';
    final colors = mode == 0 ? NuraColors.light : NuraColors.dark;
    final theme = mode == 0 ? AppTheme.light : AppTheme.dark;
    test('$label colors match tokens.json', () {
      expect(colors.hero, token('ext/hero', mode));
      expect(colors.heroShape, token('ext/heroShape', mode));
      expect(colors.onHero, token('ext/onHero', mode));
      expect(colors.onHeroAccent, token('ext/onHeroAccent', mode));
      expect(colors.iconAccent, token('ext/iconAccent', mode));
      expect(
        theme.colorScheme.surfaceContainerLowest,
        token('surfaceContainerLowest', mode),
      );
    });
  }

  test('s36 and arabicHero', () {
    expect(NuraSpace.s36, 36);
    final s = NuraTextStyles.standard.arabicHero;
    expect(s.fontSize, 40);
    expect(s.height, 56 / 40);
    expect(s.fontFamily, nuraArabicFont);
  });

  test('lerp ends and copyWith identity', () {
    const a = NuraColors.light;
    const b = NuraColors.dark;
    expect(a.lerp(b, 0).hero, a.hero);
    final end = a.lerp(b, 1);
    expect(end.hero, b.hero);
    expect(end.heroShape, b.heroShape);
    expect(end.onHero, b.onHero);
    expect(end.onHeroAccent, b.onHeroAccent);
    expect(end.iconAccent, b.iconAccent);
    final c = a.copyWith();
    expect(c.hero, a.hero);
    expect(c.iconAccent, a.iconAccent);
    expect(c.onHeroAccent, a.onHeroAccent);
    final t = NuraTextStyles.standard;
    expect(t.copyWith().arabicHero, t.arabicHero);
    expect(t.lerp(t, 1).arabicHero, t.arabicHero);
  });
}
