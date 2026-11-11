import 'package:flutter/material.dart';

/// Font families from design tokens (`type/font/*`). The Arabic family is not
/// bundled yet and falls back to the system font.
const String nuraLatinFont = 'Plus Jakarta Sans';
const String nuraArabicFont = 'LPMQ Isep Misbah';

/// Builds a style from token size and line height (Flutter height = ratio).
TextStyle nuraTextStyle({
  required String family,
  required double size,
  required double lineHeight,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  height: lineHeight / size,
  fontWeight: weight,
);

/// Arabic and translation styles (`type/arabic*`, `type/translation`).
@immutable
class NuraTextStyles extends ThemeExtension<NuraTextStyles> {
  const NuraTextStyles({
    required this.arabicReading,
    required this.arabicCard,
    required this.arabicTitle,
    required this.arabicReading36,
    required this.translation,
  });

  static final NuraTextStyles standard = NuraTextStyles(
    arabicReading: nuraTextStyle(
      family: nuraArabicFont,
      size: 28,
      lineHeight: 56,
    ),
    arabicCard: nuraTextStyle(family: nuraArabicFont, size: 22, lineHeight: 44),
    arabicTitle: nuraTextStyle(
      family: nuraArabicFont,
      size: 24,
      lineHeight: 36,
    ),
    arabicReading36: nuraTextStyle(
      family: nuraArabicFont,
      size: 36,
      lineHeight: 72,
    ),
    translation: nuraTextStyle(family: nuraLatinFont, size: 15, lineHeight: 24),
  );

  final TextStyle arabicReading;
  final TextStyle arabicCard;
  final TextStyle arabicTitle;
  final TextStyle arabicReading36;
  final TextStyle translation;

  @override
  NuraTextStyles copyWith({
    TextStyle? arabicReading,
    TextStyle? arabicCard,
    TextStyle? arabicTitle,
    TextStyle? arabicReading36,
    TextStyle? translation,
  }) => NuraTextStyles(
    arabicReading: arabicReading ?? this.arabicReading,
    arabicCard: arabicCard ?? this.arabicCard,
    arabicTitle: arabicTitle ?? this.arabicTitle,
    arabicReading36: arabicReading36 ?? this.arabicReading36,
    translation: translation ?? this.translation,
  );

  @override
  NuraTextStyles lerp(ThemeExtension<NuraTextStyles>? other, double t) {
    if (other is! NuraTextStyles) return this;
    return NuraTextStyles(
      arabicReading:
          TextStyle.lerp(arabicReading, other.arabicReading, t) ??
          arabicReading,
      arabicCard: TextStyle.lerp(arabicCard, other.arabicCard, t) ?? arabicCard,
      arabicTitle:
          TextStyle.lerp(arabicTitle, other.arabicTitle, t) ?? arabicTitle,
      arabicReading36:
          TextStyle.lerp(arabicReading36, other.arabicReading36, t) ??
          arabicReading36,
      translation:
          TextStyle.lerp(translation, other.translation, t) ?? translation,
    );
  }
}
