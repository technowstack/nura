import 'package:flutter/painting.dart';

/// A search-result excerpt. [highlights] are relative to [text]; ellipses are
/// added by the view according to [cutStart] and [cutEnd].
class Snippet {
  const Snippet({
    required this.text,
    required this.highlights,
    required this.cutStart,
    required this.cutEnd,
  });

  final String text;
  final List<TextRange> highlights;
  final bool cutStart;
  final bool cutEnd;
}

const int _windowSize = 100;

/// Builds a snippet of [text] centred on the earliest case-insensitive
/// occurrence of any of [tokens] (translation mode, spec 5.5).
Snippet buildSnippet(String text, List<String> tokens) {
  // shortcut: lowercasing assumed length-preserving (true for Indonesian text).
  final lower = text.toLowerCase();
  final needles = [
    for (final t in tokens)
      if (t.isNotEmpty) t.toLowerCase(),
  ];

  var first = -1;
  var firstEnd = 0;
  for (final n in needles) {
    final i = lower.indexOf(n);
    if (i >= 0 && (first < 0 || i < first)) {
      first = i;
      firstEnd = i + n.length;
    }
  }

  final range = first < 0
      ? snippetWindow(text, 0, 0)
      : snippetWindow(text, first, firstEnd);
  final cut = text.substring(range.start, range.end);

  final spans = <TextRange>[];
  final cutLower = lower.substring(range.start, range.end);
  for (final n in needles) {
    for (var i = cutLower.indexOf(n); i >= 0; i = cutLower.indexOf(n, i + 1)) {
      spans.add(TextRange(start: i, end: i + n.length));
    }
  }
  spans.sort((a, b) => a.start.compareTo(b.start));
  final merged = <TextRange>[];
  for (final s in spans) {
    if (merged.isNotEmpty && s.start < merged.last.end) {
      if (s.end > merged.last.end) {
        merged[merged.length - 1] = TextRange(
          start: merged.last.start,
          end: s.end,
        );
      }
    } else {
      merged.add(s);
    }
  }

  return Snippet(
    text: cut,
    highlights: merged,
    cutStart: range.start > 0,
    cutEnd: range.end < text.length,
  );
}

/// Computes the 100-char window around [matchStart, matchEnd) of [text]:
/// centred, shifted inside the text, then trimmed to word boundaries (spaces)
/// without cutting the match. Shared with the Arabic snippet builder.
TextRange snippetWindow(String text, int matchStart, int matchEnd) {
  final len = text.length;
  if (len <= _windowSize) return TextRange(start: 0, end: len);

  final center = (matchStart + matchEnd) ~/ 2;
  var start = (center - _windowSize ~/ 2).clamp(0, len - _windowSize);
  var end = start + _windowSize;

  bool isSpace(int i) => text.codeUnitAt(i) == 0x20;

  if (start > 0 && !isSpace(start - 1)) {
    while (start < matchStart && !isSpace(start - 1)) {
      start++;
    }
  }
  if (end < len && !isSpace(end)) {
    while (end > matchEnd && !isSpace(end)) {
      end--;
    }
  }
  return TextRange(start: start, end: end);
}
