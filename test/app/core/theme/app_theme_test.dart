import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/arabic_font.dart';
import 'package:nura/app/core/theme/nura_colors.dart';
import 'package:nura/app/core/theme/nura_text_styles.dart';
import 'package:nura/app/core/theme/tokens.dart';

/// Reads docs/design/tokens.json (FigCraft export): variables live in
/// meta.variables, grouped by collection id; color modes are Light/Dark.
class _Tokens {
  _Tokens() {
    final meta =
        (jsonDecode(File('docs/design/tokens.json').readAsStringSync())
                as Map<String, dynamic>)['meta']
            as Map<String, dynamic>;
    _collections = (meta['variableCollections'] as Map<String, dynamic>).values
        .cast<Map<String, dynamic>>()
        .toList();
    _variables = (meta['variables'] as Map<String, dynamic>).values
        .cast<Map<String, dynamic>>()
        .toList();
  }

  late final List<Map<String, dynamic>> _collections;
  late final List<Map<String, dynamic>> _variables;

  dynamic _value(String collection, String name, int modeIndex) {
    final c = _collections.firstWhere((c) => c['name'] == collection);
    final v = _variables.firstWhere(
      (v) => v['variableCollectionId'] == c['id'] && v['name'] == name,
    );
    final modes = c['modes'] as List<dynamic>;
    final modeId = (modes[modeIndex] as Map<String, dynamic>)['modeId'];
    return (v['valuesByMode'] as Map<String, dynamic>)[modeId];
  }

  Color color(String name, {required bool dark}) {
    final m = _value('color', name, dark ? 1 : 0) as Map<String, dynamic>;
    int ch(String k) => ((m[k] as num) * 255).round();
    // Tokens are 0-1 floats; compare as 8-bit ARGB to avoid float noise.
    return Color.fromARGB(ch('a'), ch('r'), ch('g'), ch('b'));
  }

  double number(String collection, String name) =>
      (_value(collection, name, 0) as num).toDouble();

  String string(String collection, String name) =>
      _value(collection, name, 0) as String;
}

void main() {
  final t = _Tokens();

  for (final dark in [false, true]) {
    final label = dark ? 'dark' : 'light';
    final theme = dark ? AppTheme.dark : AppTheme.light;

    test('$label ColorScheme matches color/* tokens', () {
      final s = theme.colorScheme;
      final expected = <String, Color>{
        'primary': s.primary,
        'onPrimary': s.onPrimary,
        'primaryContainer': s.primaryContainer,
        'onPrimaryContainer': s.onPrimaryContainer,
        'secondary': s.secondary,
        'surface': s.surface,
        'surfaceContainerLow': s.surfaceContainerLow,
        'surfaceContainer': s.surfaceContainer,
        'onSurface': s.onSurface,
        'onSurfaceVariant': s.onSurfaceVariant,
        'outline': s.outline,
        'outlineVariant': s.outlineVariant,
        'error': s.error,
        'onError': s.onError,
        'scrim': s.scrim,
      };
      expected.forEach((name, actual) {
        expect(actual, t.color(name, dark: dark), reason: name);
      });
      expect(theme.useMaterial3, isTrue);
    });

    test('$label NuraColors matches color/ext/* tokens', () {
      final c = theme.extension<NuraColors>();
      expect(c, isNotNull);
      if (c == null) return;
      expect(c.arabicText, t.color('ext/arabicText', dark: dark));
      expect(c.lastReadHighlight, t.color('ext/lastReadHighlight', dark: dark));
      expect(c.searchHighlight, t.color('ext/searchHighlight', dark: dark));
      expect(c.ornament, t.color('ext/ornament', dark: dark));
      expect(c.offlineBadge, t.color('ext/offlineBadge', dark: dark));
    });

    test('$label NuraTextStyles present', () {
      expect(theme.extension<NuraTextStyles>(), isNotNull);
    });
  }

  test('Arabic styles match type tokens', () {
    final s = AppTheme.light.extension<NuraTextStyles>();
    expect(s, isNotNull);
    if (s == null) return;
    // Token still names LPMQ; the app uses the replaceable constant.
    final arabic = nuraArabicFont;
    final byName = {
      'arabicReading': s.arabicReading,
      'arabicCard': s.arabicCard,
      'arabicTitle': s.arabicTitle,
      'arabicReading36': s.arabicReading36,
    };
    byName.forEach((name, style) {
      final size = t.number('type', '$name/size');
      expect(style.fontFamily, arabic, reason: name);
      expect(style.fontSize, size, reason: name);
      expect(
        style.height,
        t.number('type', '$name/lineHeight') / size,
        reason: name,
      );
    });
    expect(s.arabicReading.fontSize, 28);
    expect(s.arabicReading.height, 56 / 28);
  });

  test('Latin text theme matches type tokens', () {
    final latin = t.string('type', 'font/latin');
    expect(latin, 'Plus Jakarta Sans');
    final tt = AppTheme.light.textTheme;
    final styles = <String, TextStyle?>{
      'displaySmall': tt.displaySmall,
      'headlineSmall': tt.headlineSmall,
      'titleLarge': tt.titleLarge,
      'titleMedium': tt.titleMedium,
      'bodyLarge': tt.bodyLarge,
      'bodyMedium': tt.bodyMedium,
      'labelLarge': tt.labelLarge,
      'labelMedium': tt.labelMedium,
    };
    styles.forEach((name, style) {
      final size = t.number('type', '$name/size');
      expect(style?.fontFamily, latin, reason: name);
      expect(style?.fontSize, size, reason: name);
      expect(
        style?.height,
        t.number('type', '$name/lineHeight') / size,
        reason: name,
      );
    });
    expect(tt.titleLarge?.fontSize, 20);
    expect(tt.titleLarge?.height, 28 / 20);
    final tr = AppTheme.light.extension<NuraTextStyles>()?.translation;
    expect(tr?.fontFamily, latin);
    expect(tr?.fontSize, 15);
    expect(tr?.height, 24 / 15);
  });

  test('space and radius constants match tokens', () {
    expect(NuraSpace.s48, 48);
    expect(NuraSpace.s4, t.number('space', '4'));
    expect(NuraSpace.s20, t.number('space', '20'));
    expect(NuraRadius.lg, 16);
    expect(NuraRadius.sm, t.number('radius', 'sm'));
    expect(NuraRadius.md, t.number('radius', 'md'));
    expect(NuraRadius.xl, t.number('radius', 'xl'));
    expect(NuraRadius.full, t.number('radius', 'full'));
  });
}
