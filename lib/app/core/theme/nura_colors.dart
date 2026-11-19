import 'package:flutter/material.dart';

/// App-specific colors (`color/ext/*`) that have no ColorScheme role.
@immutable
class NuraColors extends ThemeExtension<NuraColors> {
  const NuraColors({
    required this.arabicText,
    required this.lastReadHighlight,
    required this.searchHighlight,
    required this.ornament,
    required this.offlineBadge,
    required this.hero,
    required this.heroShape,
    required this.onHero,
    required this.onHeroAccent,
    required this.iconAccent,
  });

  static const NuraColors light = NuraColors(
    arabicText: Color(0xFF121413),
    lastReadHighlight: Color(0xFFFFF4DE),
    searchHighlight: Color(0xFFFFE3A3),
    ornament: Color(0x141F6F5C),
    offlineBadge: Color(0xFF2B7430),
    hero: Color(0xFF185A4B),
    heroShape: Color(0xFF1B6252),
    onHero: Color(0xFFF8F7F3),
    onHeroAccent: Color(0xFFEBCB8B),
    iconAccent: Color(0xFF8A6A3E),
  );

  static const NuraColors dark = NuraColors(
    arabicText: Color(0xFFF1F2EF),
    lastReadHighlight: Color(0xFF2A2418),
    searchHighlight: Color(0xFF5A4A1E),
    ornament: Color(0x0F7FC8B2),
    offlineBadge: Color(0xFF81C784),
    hero: Color(0xFF0F3F34),
    heroShape: Color(0xFF124A3D),
    onHero: Color(0xFFF1F2EF),
    onHeroAccent: Color(0xFFEBCB8B),
    iconAccent: Color(0xFFD9BE92),
  );

  final Color arabicText;
  final Color lastReadHighlight;
  final Color searchHighlight;
  final Color ornament;
  final Color offlineBadge;
  final Color hero;
  final Color heroShape;
  final Color onHero;
  final Color onHeroAccent;
  final Color iconAccent;

  @override
  NuraColors copyWith({
    Color? arabicText,
    Color? lastReadHighlight,
    Color? searchHighlight,
    Color? ornament,
    Color? offlineBadge,
    Color? hero,
    Color? heroShape,
    Color? onHero,
    Color? onHeroAccent,
    Color? iconAccent,
  }) => NuraColors(
    arabicText: arabicText ?? this.arabicText,
    lastReadHighlight: lastReadHighlight ?? this.lastReadHighlight,
    searchHighlight: searchHighlight ?? this.searchHighlight,
    ornament: ornament ?? this.ornament,
    offlineBadge: offlineBadge ?? this.offlineBadge,
    hero: hero ?? this.hero,
    heroShape: heroShape ?? this.heroShape,
    onHero: onHero ?? this.onHero,
    onHeroAccent: onHeroAccent ?? this.onHeroAccent,
    iconAccent: iconAccent ?? this.iconAccent,
  );

  @override
  NuraColors lerp(ThemeExtension<NuraColors>? other, double t) {
    if (other is! NuraColors) return this;
    return NuraColors(
      arabicText: Color.lerp(arabicText, other.arabicText, t) ?? arabicText,
      lastReadHighlight:
          Color.lerp(lastReadHighlight, other.lastReadHighlight, t) ??
          lastReadHighlight,
      searchHighlight:
          Color.lerp(searchHighlight, other.searchHighlight, t) ??
          searchHighlight,
      ornament: Color.lerp(ornament, other.ornament, t) ?? ornament,
      offlineBadge:
          Color.lerp(offlineBadge, other.offlineBadge, t) ?? offlineBadge,
      hero: Color.lerp(hero, other.hero, t) ?? hero,
      heroShape: Color.lerp(heroShape, other.heroShape, t) ?? heroShape,
      onHero: Color.lerp(onHero, other.onHero, t) ?? onHero,
      onHeroAccent:
          Color.lerp(onHeroAccent, other.onHeroAccent, t) ?? onHeroAccent,
      iconAccent: Color.lerp(iconAccent, other.iconAccent, t) ?? iconAccent,
    );
  }
}
