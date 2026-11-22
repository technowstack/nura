import 'package:flutter/widgets.dart';

import '../theme/arabic_font.dart';

/// Converts [n] to Arabic-Indic digits (U+0660 to U+0669).
String toArabicIndic(int n) {
  if (n < 0) throw ArgumentError.value(n, 'n', 'must be non-negative');
  return n
      .toString()
      .split('')
      .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
      .join();
}

/// The ayah end marker, drawn by the app: the ring glyph U+06DD with the
/// number centred inside. The font would enclose digits only through GSUB
/// ligatures that Flutter's text engine does not apply.
class AyahEndMarker extends StatelessWidget {
  const AyahEndMarker({
    required this.number,
    required this.fontSize,
    this.color,
    super.key,
  });

  final int number;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.textScalerOf(context).scale(fontSize);
    final digits = toArabicIndic(number);
    // Inner width as a share of the ring: 1 digit 0.5, 2 digits 0.4, 3+ 0.3.
    final inner =
        size *
        0.97 *
        (digits.length == 1
            ? 0.5
            : digits.length == 2
            ? 0.4
            : 0.3);
    TextStyle style(double s) => TextStyle(
      fontFamily: nuraArabicFont,
      fontSize: s,
      color: color ?? DefaultTextStyle.of(context).style.color,
    );
    return ExcludeSemantics(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('۝', style: style(size), textScaler: TextScaler.noScaling),
          SizedBox(
            width: inner,
            child: FittedBox(
              child: Text(
                digits,
                style: style(size * 0.45),
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Diacritics, Quranic annotation marks and waqaf signs: no base letter.
bool _isMark(int r) =>
    (r >= 0x0610 && r <= 0x061A) ||
    (r >= 0x064B && r <= 0x065F) ||
    r == 0x0670 ||
    (r >= 0x06D6 && r <= 0x06ED) ||
    (r >= 0x08D3 && r <= 0x08FF);

/// Spans for [arab] followed by the marker. Trailing ASCII spaces are
/// dropped and nothing else is touched. The engine allows a line break
/// before any inline widget (it ignores U+00A0 and U+2060 there), so the
/// last word and its waqaf signs sit in the same widget as the marker, which
/// keeps the marker from landing alone on a new line. [style] must be the
/// style of the surrounding text: widget children do not inherit it.
List<InlineSpan> ayahTextSpans(
  String arab,
  int ayahNumber, {
  required TextStyle style,
}) {
  final size = style.fontSize ?? 28;
  final marker = AyahEndMarker(
    number: ayahNumber,
    fontSize: size,
    color: style.color,
  );
  var end = arab.length;
  while (end > 0 && arab.codeUnitAt(end - 1) == 0x20) {
    end--;
  }
  // Start of the last word: after the last space that has a letter behind it.
  var start = end;
  while (start > 0) {
    final c = arab.codeUnitAt(start - 1);
    if (c == 0x20 && !arab.substring(start, end).runes.every(_isMark)) break;
    start--;
  }
  if (end == 0) {
    return [WidgetSpan(alignment: PlaceholderAlignment.middle, child: marker)];
  }
  return [
    if (start > 0) TextSpan(text: arab.substring(0, start)),
    WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // Flexible: a word wider than the line wraps instead of overflowing.
          Flexible(child: Text(arab.substring(start, end), style: style)),
          marker,
        ],
      ),
    ),
  ];
}
