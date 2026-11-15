final _arabicStrip = RegExp('[ً-ٰٟۖ-ۭـ]');
final _alif = RegExp('[أإآٱ]');
final _whitespace = RegExp(r'\s+');
final _punctuation = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

String _collapse(String s) => s.replaceAll(_whitespace, ' ').trim();

/// Normalizes Arabic text for the FTS index only.
String normalizeArabicForSearch(String input) => _collapse(
  input
      .replaceAll(_arabicStrip, '')
      .replaceAll(_alif, 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه'),
);

/// Normalizes Indonesian text for the FTS index only.
String normalizeIndonesianForSearch(String input) =>
    _collapse(input.toLowerCase().replaceAll(_punctuation, ' '));

// Uthmani spelling writes a long alif as U+0670 (dagger alef). A small alef
// directly followed by a waw that is not itself followed by another small alef
// stands for the imla'i alif alone (ٱلصَّلَٰوة = الصلاة); a waw before a small
// alef is a real letter (ٱلسَّمَٰوَٰت = السماوات).
final daggerWawPattern = RegExp('ٰو(?![ً-ٟ]*ٰ)');

/// Like [normalizeArabicForSearch] but reads the small alef U+0670 as an
/// alif, so imla'i spellings (الصلاة, الكتاب) match Uthmani text. Equals the
/// plain normalizer for text without U+0670.
String normalizeArabicVariantForSearch(String input) =>
    normalizeArabicForSearch(
      input.replaceAll(daggerWawPattern, 'ا').replaceAll('ٰ', 'ا'),
    );

/// Text stored in `ayah_fts.arab`: the plain form, plus the variant form when
/// it differs, so either spelling finds the ayah.
String normalizeAyahArabicForIndex(String arab) {
  final plain = normalizeArabicForSearch(arab);
  final variant = normalizeArabicVariantForSearch(arab);
  return plain == variant ? plain : '$plain $variant';
}
