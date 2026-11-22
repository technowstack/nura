/// Translation size bounds and default (design token `type/translation`).
const double kTranslationFontMin = 14;
const double kTranslationFontMax = 22;
const double kTranslationFontDefault = 15;

class ReadingPrefs {
  const ReadingPrefs({
    required this.arabicFontSize,
    required this.showTranslation,
    this.translationFontSize = kTranslationFontDefault,
  });

  final double arabicFontSize;
  final bool showTranslation;
  final double translationFontSize;

  ReadingPrefs copyWith({
    double? arabicFontSize,
    bool? showTranslation,
    double? translationFontSize,
  }) => ReadingPrefs(
    arabicFontSize: arabicFontSize ?? this.arabicFontSize,
    showTranslation: showTranslation ?? this.showTranslation,
    translationFontSize: translationFontSize ?? this.translationFontSize,
  );
}
