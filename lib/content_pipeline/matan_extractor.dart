import 'arabic_offsets.dart';

/// Longest translation matan, in UTF-16 code units (spec 8.1, N = 300).
const int kMatanMaxTranslation = 300;

/// Longest Arabic matan, in UTF-16 code units.
const int kMatanMaxArab = 300;

const int _minMatanLength = 10;
const double _minRatio = 0.8;
const double _maxRatio = 3.0;

/// Half-open ranges of a hadith's matan, as UTF-16 code unit indices into the
/// original `arab` and `translation_id` strings.
class Matan {
  const Matan({
    required this.arabStart,
    required this.arabEnd,
    required this.trStart,
    required this.trEnd,
  });

  final int arabStart;
  final int arabEnd;
  final int trStart;
  final int trEnd;
}

final _quoteOpen = RegExp(r'bersabda\s*:\s*["“]', caseSensitive: false);
final _salawat = RegExp(
  r"shallallahu\s+'alaihi\s+wa\s*sallam",
  caseSensitive: false,
);
final _secondSpeech = RegExp(r'bersabda\s*:', caseSensitive: false);
final _closingTail = RegExp(r'^[\s.;,)\]]*$');
// Normalized form (alif maker ى -> ي): salawat plus an optional speech verb.
final _arabKey = RegExp('صلي الله عليه وسلم( (قال|يقول|قالت|فقال))?( |\$)');

bool _isQuote(int unit) => unit == 0x22 || unit == 0x201D;

// A matan is one uninterrupted quotation; any inner quotation mark (ASCII,
// U+201C, U+201D) means a second speaker, dialogue or commentary. The single
// quote is not one: genuine matan uses it.
final _innerQuote = RegExp('["\u201C\u201D]');

/// Translation matan range, or null when the text does not have the form
/// `... shallallahu 'alaihi wasallam bersabda: "matan"`.
({int start, int end})? _translationMatan(String t) {
  final open = _quoteOpen.firstMatch(t);
  final salawat = _salawat.firstMatch(t);
  if (open == null || salawat == null) return null;
  // The speech must follow the first salawat directly.
  if (open.start < salawat.end || open.start - salawat.end > 14) return null;

  var close = -1;
  for (var i = t.length - 1; i >= open.end; i--) {
    if (_isQuote(t.codeUnitAt(i))) {
      close = i;
      break;
    }
  }
  if (close < 0 || !_closingTail.hasMatch(t.substring(close + 1))) return null;

  var start = open.end;
  var end = close;
  while (start < end && t[start].trim().isEmpty) {
    start++;
  }
  while (end > start && t[end - 1].trim().isEmpty) {
    end--;
  }
  final body = t.substring(start, end);
  if (body.contains('[') || body.contains(']')) return null;
  if (_innerQuote.hasMatch(body)) return null;
  if (_secondSpeech.hasMatch(body)) return null;
  if (body.length < _minMatanLength) return null;
  return (start: start, end: end);
}

/// Arabic matan range: from right after the first salawat (and an optional
/// speech verb) to the end of the text, without trailing whitespace.
({int start, int end})? _arabMatan(String a) {
  final n = normalizeArabicWithOffsets(a);
  final key = _arabKey.firstMatch(n.text);
  if (key == null || key.end >= n.text.length) return null;
  final start = n.offsets[key.end];
  var end = a.length;
  while (end > start && a[end - 1].trim().isEmpty) {
    end--;
  }
  if (end - start < _minMatanLength) return null;
  return (start: start, end: end);
}

/// Extracts the matan of one hadith by the rule of spec 8.1, or null when the
/// hadith does not qualify (form, length limits or length ratio). Ranges
/// index the original strings, which are never altered.
Matan? extractMatan(String arab, String translation) {
  final t = _translationMatan(translation);
  final a = _arabMatan(arab);
  if (t == null || a == null) return null;
  final trLength = t.end - t.start;
  final arabLength = a.end - a.start;
  if (trLength > kMatanMaxTranslation || arabLength > kMatanMaxArab) {
    return null;
  }
  final ratio = trLength / arabLength;
  if (ratio < _minRatio || ratio > _maxRatio) return null;
  return Matan(
    arabStart: a.start,
    arabEnd: a.end,
    trStart: t.start,
    trEnd: t.end,
  );
}
