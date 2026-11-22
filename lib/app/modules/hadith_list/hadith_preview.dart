/// List preview of a hadith translation: the matan (text after the first
/// `bersabda: "` or `bersabda: '`) when there is one, otherwise the start of
/// the text. A single-quote opener counts only when a closing single quote
/// follows (so an unterminated or cut-off quote falls back to the start).
/// Display only; the source text is never altered, only cut with an ellipsis.
String hadithPreview(String translation, {int maxChars = 200}) {
  final m = _matanStart.firstMatch(translation);
  var text = translation;
  if (m != null &&
      (m.group(1) != null || _hasClosingSingle(translation, m.end))) {
    final matan = translation.substring(m.end).trimLeft();
    if (matan.isNotEmpty) text = matan;
  }
  final runes = text.runes;
  if (runes.length <= maxChars) return text;
  return '${String.fromCharCodes(runes.take(maxChars))}…';
}

/// Group 1 = double-quote opener, group 2 = single-quote opener.
final _matanStart = RegExp(
  'bersabda:\\s*(?:(["“])|([\'‘]))',
  caseSensitive: false,
);

/// A closing single quote: follows a non-space and is not followed by a
/// letter, so in-word apostrophes (Ya'qub) and a leading one ('Umar) do not
/// count.
final _closingSingle = RegExp(r"(?<=\S)['’](?!\p{L})", unicode: true);

bool _hasClosingSingle(String text, int from) =>
    _closingSingle.hasMatch(text.substring(from));
