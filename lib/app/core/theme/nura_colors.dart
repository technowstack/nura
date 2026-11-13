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
  });

  static const NuraColors light = NuraColors(
    arabicText: Color(0xFF121413),
    lastReadHighlight: Color(0xFFFFF4DE),
    searchHighlight: Color(0xFFFFE3A3),
    ornament: Color(0x141F6F5C),
    offlineBadge: Color(0xFF2B7430),
  );

  static const NuraColors dark = NuraColors(
    arabicText: Color(0xFFF1F2EF),
    lastReadHighlight: Color(0xFF2A2418),
    searchHighlight: Color(0xFF5A4A1E),
    ornament: Color(0x0F7FC8B2),
    offlineBadge: Color(0xFF81C784),
  );

  final Color arabicText;
  final Color lastReadHighlight;
  final Color searchHighlight;
  final Color ornament;
  final Color offlineBadge;

  @override
  NuraColors copyWith({
    Color? arabicText,
    Color? lastReadHighlight,
    Color? searchHighlight,
    Color? ornament,
    Color? offlineBadge,
  }) => NuraColors(
    arabicText: arabicText ?? this.arabicText,
    lastReadHighlight: lastReadHighlight ?? this.lastReadHighlight,
    searchHighlight: searchHighlight ?? this.searchHighlight,
    ornament: ornament ?? this.ornament,
    offlineBadge: offlineBadge ?? this.offlineBadge,
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
    );
  }
}
