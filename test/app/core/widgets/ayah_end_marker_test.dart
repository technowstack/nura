import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/widgets/ayah_end_marker.dart';

import '../../../support/ayah_text.dart';

Widget _host(Widget child, {double scale = 1}) => MaterialApp(
  builder: (c, w) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: w ?? const SizedBox.shrink(),
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUpAll(loadArabicFont);

  const digits = {1: '١', 10: '١٠', 255: '٢٥٥', 286: '٢٨٦'};
  const frac = {1: 0.5, 2: 0.4, 3: 0.3};

  for (final size in [20.0, 28.0, 36.0, 40.0]) {
    for (final e in digits.entries) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${e.key} at $size x$scale: digits inside ring', (t) async {
          await t.pumpWidget(
            _host(
              AyahEndMarker(number: e.key, fontSize: size),
              scale: scale,
            ),
          );
          expect(tester(t), isNull);
          final ring = t.getRect(find.text('۝'));
          final d = t.getRect(find.text(e.value));
          expect(ring.contains(d.center), isTrue);
          expect(
            d.width,
            lessThanOrEqualTo(ring.width * frac[e.value.length]! + 0.01),
          );
          expect(d.height, lessThanOrEqualTo(ring.height));
        });
      }
    }
  }

  testWidgets('uses the given color for ring and digits', (t) async {
    await t.pumpWidget(
      _host(
        const AyahEndMarker(number: 7, fontSize: 28, color: Color(0xFF123456)),
      ),
    );
    for (final s in ['۝', '٧']) {
      expect(
        t.widget<Text>(find.text(s)).style?.color,
        const Color(0xFF123456),
      );
    }
  });

  test('ayahTextSpans: data before the last word, last word + marker', () {
    const st = TextStyle(fontSize: 28);
    final spans = ayahTextSpans('قُلْ هُوَ  ', 3, style: st);
    expect(spans, hasLength(2));
    expect((spans[0] as TextSpan).text, 'قُلْ ');
    final row = (spans[1] as WidgetSpan).child as Row;
    expect(((row.children.first as Flexible).child as Text).data, 'هُوَ');
    expect((row.children.last as AyahEndMarker).number, 3);
    // Waqaf signs after a space stay with the word before them.
    final w = ayahTextSpans('أ ب \u06DA', 1, style: st);
    expect((w[0] as TextSpan).text, 'أ ');
    expect(((w[1] as WidgetSpan).child as Row).children.first, isA<Flexible>());
    // Single word and empty text.
    expect(ayahTextSpans('كلمة', 1, style: st), hasLength(1));
    expect(ayahTextSpans('', 1, style: st), hasLength(1));
  });
}

Object? tester(WidgetTester t) => t.takeException();
