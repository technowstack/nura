final _arabicStrip = RegExp('[ً-ٰٟۖ-ۭـ]');
final _alif = RegExp('[أإآٱ]');
final _whitespace = RegExp(r'\s+');
final _punctuation = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

String _collapse(String s) => s.replaceAll(_whitespace, ' ').trim();

/// Normalizes Arabic text for the FTS index only.
String normalizeArabicForSearch(String input) => _collapse(input
    .replaceAll(_arabicStrip, '')
    .replaceAll(_alif, 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه'));

/// Normalizes Indonesian text for the FTS index only.
String normalizeIndonesianForSearch(String input) =>
    _collapse(input.toLowerCase().replaceAll(_punctuation, ' '));
