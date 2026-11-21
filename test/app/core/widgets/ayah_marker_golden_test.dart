import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/arabic_font.dart';
import 'package:nura/app/core/widgets/ayah_end_marker.dart';

import '../../../support/ayah_text.dart';

// Only Scheherazade New text: goldens must not depend on fallback fonts.
final _samples = <(String, int)>[
  ('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ', 1),
  ('ٱلۡحَمۡدُ لِلَّهِ رَبِّ ٱلۡعَٰلَمِينَۙ', 2),
  ('الٓمٓ ۚ', 10),
  ('وَهُوَ بِكُلِّ شَيۡءٍ عَلِيمٞ ࣖ', 255),
  ('وَٱنصُرۡنَا عَلَى ٱلۡقَوۡمِ ٱلۡكَٰفِرِينَ ࣖ', 286),
];

void main() {
  setUpAll(loadArabicFont);

  for (final dark in [false, true]) {
    for (final size in [28.0, 36.0]) {
      final name = '${size.toInt()}pt-${dark ? 'dark' : 'light'}';
      testWidgets('ayah marker golden $name', (t) async {
        t.view.physicalSize = Size(400, 120.0 * 5 * size / 28);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final style = TextStyle(
          fontFamily: nuraArabicFont,
          fontSize: size,
          height: 1.8,
          color: dark ? const Color(0xFFE8E8E8) : const Color(0xFF111111),
        );
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: dark
                  ? const Color(0xFF121212)
                  : const Color(0xFFFFFFFF),
              body: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final s in _samples)
                        Text.rich(
                          TextSpan(
                            children: ayahTextSpans(s.$1, s.$2, style: style),
                          ),
                          style: style,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile('../../../goldens/ayah_marker/$name.png'),
        );
      });
    }
  }
}
