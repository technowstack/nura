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
  // Matching on the original text keeps offsets valid even where lowercasing
  // changes string length (e.g. U+0130 on the web).
  final matches = <TextRange>[
    for (final t in tokens)
      if (t.isNotEmpty)
        for (final m in RegExp(
          RegExp.escape(t),
          caseSensitive: false,
        ).allMatches(text))
          TextRange(start: m.start, end: m.end),
  ];
  return _assemble(text, matches);
}

/// Windows [text] around the earliest of [matches] (ranges in [text]) and
/// returns the merged matches that fit inside the window.
Snippet _assemble(String text, List<TextRange> matches) {
  matches.sort((a, b) => a.start.compareTo(b.start));
  final range = matches.isEmpty
      ? snippetWindow(text, 0, 0)
      : snippetWindow(text, matches.first.start, matches.first.end);

  final merged = <TextRange>[];
  for (final m in matches) {
    if (m.start < range.start || m.end > range.end) continue;
    final s = TextRange(start: m.start - range.start, end: m.end - range.start);
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
    text: text.substring(range.start, range.end),
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
  final windowEnd = start + _windowSize;
  var end = windowEnd;

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
  // No space to trim to (e.g. no match and a space-free head): keep the raw
  // window rather than an empty one.
  if (end <= start) end = windowEnd;
  return TextRange(start: start, end: end);
}
