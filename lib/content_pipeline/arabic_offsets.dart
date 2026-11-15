import 'text_normalizer.dart';

final _space = RegExp(r'\s');

// Per-char normalizer results (' ' for whitespace); bounded by distinct code
// units, and avoids running the normalizer's regexes on every char.
final _charCache = <String, String>{};

String _normalizeChar(String ch) => _charCache.putIfAbsent(
  ch,
  () => _space.hasMatch(ch) ? ' ' : normalizeArabicForSearch(ch),
);

bool isStrippedArabicChar(String ch) => _normalizeChar(ch).isEmpty;

/// Equals `normalizeArabicForSearch(text)`, plus for each normalized char the
/// index of the original char it came from. Built per char with the index
/// normalizer itself so the two cannot drift apart.
({String text, List<int> offsets}) normalizeArabicWithOffsets(String text) {
  final out = StringBuffer();
  final offsets = <int>[];
  var pendingSpace = -1;
  for (var i = 0; i < text.length; i++) {
    final mapped = _normalizeChar(text[i]);
    if (mapped == ' ') {
      if (offsets.isNotEmpty && pendingSpace < 0) pendingSpace = i;
      continue;
    }
    if (mapped.isEmpty) continue;
    if (pendingSpace >= 0) {
      out.write(' ');
      offsets.add(pendingSpace);
      pendingSpace = -1;
    }
    out.write(mapped);
    offsets.add(i);
  }
  return (text: out.toString(), offsets: offsets);
}

/// Equals `normalizeArabicVariantForSearch(text)`, with the same offset map
/// as [normalizeArabicWithOffsets]. A small alef and the waw it absorbs
/// become one alif that maps to the waw, so a highlight ending there covers
/// the whole written word.
({String text, List<int> offsets}) normalizeArabicVariantWithOffsets(
  String text,
) {
  final out = StringBuffer();
  final offsets = <int>[];
  var pendingSpace = -1;

  void emit(String mapped, int at) {
    if (mapped == ' ') {
      if (offsets.isNotEmpty && pendingSpace < 0) pendingSpace = at;
      return;
    }
    if (mapped.isEmpty) return;
    if (pendingSpace >= 0) {
      out.write(' ');
      offsets.add(pendingSpace);
      pendingSpace = -1;
    }
    out.write(mapped);
    offsets.add(at);
  }

  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) != 0x670) {
      emit(_normalizeChar(text[i]), i);
      continue;
    }
    if (daggerWawPattern.matchAsPrefix(text, i) != null) {
      emit('ا', i + 1);
      i++; // the waw is absorbed
    } else {
      emit('ا', i);
    }
  }
  return (text: out.toString(), offsets: offsets);
}
