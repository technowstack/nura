/// List preview of a hadith translation: the matan (text after the first
/// `bersabda: "`) when there is one, otherwise the start of the text. Display
/// only; the source text is never altered, only cut with an ellipsis.
String hadithPreview(String translation, {int maxChars = 200}) {
  final m = _matanStart.firstMatch(translation);
  var text = translation;
  if (m != null) {
    final matan = translation.substring(m.end).trimLeft();
    if (matan.isNotEmpty) text = matan;
  }
  final runes = text.runes;
  if (runes.length <= maxChars) return text;
  return '${String.fromCharCodes(runes.take(maxChars))}…';
}

final _matanStart = RegExp('bersabda:\\s*["“”]', caseSensitive: false);
