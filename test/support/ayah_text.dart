import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/arabic_font.dart';
import 'package:nura/app/core/widgets/ayah_end_marker.dart';

/// Finds the Arabic text of an ayah card: the text before the last word,
/// with the widget holding the last word (and the marker) at its end.
Finder ayahFinder(String arab, int ayahNumber) {
  var end = arab.length;
  while (end > 0 && arab.codeUnitAt(end - 1) == 0x20) {
    end--;
  }
  final shown = arab.substring(0, end);
  return find.byWidgetPredicate((w) {
    if (w is! Text || w.textSpan == null) return false;
    final spans = <InlineSpan>[];
    w.textSpan!.visitChildren((s) {
      spans.add(s);
      return true;
    });
    final tail = spans.whereType<WidgetSpan>().singleOrNull?.child;
    if (tail is! Row) return false;
    final word = (tail.children.first as Flexible).child;
    final marker = tail.children.last;
    final head = spans.whereType<TextSpan>().map((s) => s.text ?? '').join();
    return word is Text &&
        marker is AyahEndMarker &&
        marker.number == ayahNumber &&
        '$head${word.data}' == shown;
  });
}

/// Plain text of a search snippet followed by the marker placeholder.
String ayahSearchPlain(String arab, int ayahNumber) {
  var end = arab.length;
  while (end > 0 && arab.codeUnitAt(end - 1) == 0x20) {
    end--;
  }
  return '${arab.substring(0, end)}\uFFFC';
}

/// Loads the real Arabic font so layout and goldens match the device.
Future<void> loadArabicFont() async {
  final bytes = File(
    'assets/fonts/ScheherazadeNew/ScheherazadeNew-Regular.ttf',
  ).readAsBytesSync();
  final loader = FontLoader(nuraArabicFont)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
