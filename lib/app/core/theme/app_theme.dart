import 'package:flutter/material.dart';

import 'nura_colors.dart';
import 'nura_text_styles.dart';

abstract final class AppTheme {
  static const ColorScheme _lightScheme = ColorScheme.light(
    primary: Color(0xFF1F6F5C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD3EEE5),
    onPrimaryContainer: Color(0xFF00201A),
    secondary: Color(0xFF7D6038),
    surface: Color(0xFFF8F7F3),
    surfaceContainerLow: Color(0xFFF1F0EB),
    surfaceContainer: Color(0xFFEBEAE4),
    onSurface: Color(0xFF1A1C1B),
    onSurfaceVariant: Color(0xFF55605C),
    outline: Color(0xFF7A8580),
    outlineVariant: Color(0xFFC4CAC6),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    scrim: Color(0x52000000),
  );

  static const ColorScheme _darkScheme = ColorScheme.dark(
    primary: Color(0xFF7FC8B2),
    onPrimary: Color(0xFF00382C),
    primaryContainer: Color(0xFF0F4F41),
    onPrimaryContainer: Color(0xFFC9EDE1),
    secondary: Color(0xFFD9BE92),
    surface: Color(0xFF0F1513),
    surfaceContainerLow: Color(0xFF161D1B),
    surfaceContainer: Color(0xFF1B2220),
    onSurface: Color(0xFFE2E4E1),
    onSurfaceVariant: Color(0xFFA9B3AF),
    outline: Color(0xFF6B7672),
    outlineVariant: Color(0xFF3A4441),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    scrim: Color(0x52000000),
  );

  static TextStyle _latin(double size, double lineHeight, FontWeight weight) =>
      nuraTextStyle(
        family: nuraLatinFont,
        size: size,
        lineHeight: lineHeight,
        weight: weight,
      );

  static final TextTheme _textTheme = TextTheme(
    displaySmall: _latin(32, 40, FontWeight.w600),
    headlineSmall: _latin(24, 32, FontWeight.w600),
    titleLarge: _latin(20, 28, FontWeight.w600),
    titleMedium: _latin(16, 24, FontWeight.w600),
    bodyLarge: _latin(16, 26, FontWeight.w400),
    bodyMedium: _latin(14, 22, FontWeight.w400),
    labelLarge: _latin(14, 20, FontWeight.w600),
    labelMedium: _latin(12, 16, FontWeight.w500),
  );

  static ThemeData _build(ColorScheme scheme, NuraColors colors) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: _textTheme,
    extensions: [colors, NuraTextStyles.standard],
  );

  static final ThemeData light = _build(_lightScheme, NuraColors.light);
  static final ThemeData dark = _build(_darkScheme, NuraColors.dark);
}

/// Shortcuts to the Nura theme extensions; fall back to Light values when the
/// extension is not installed (e.g. a bare MaterialApp).
extension NuraThemeContext on BuildContext {
  NuraColors get nuraColors =>
      Theme.of(this).extension<NuraColors>() ?? NuraColors.light;

  NuraTextStyles get nuraText =>
      Theme.of(this).extension<NuraTextStyles>() ?? NuraTextStyles.standard;
}
