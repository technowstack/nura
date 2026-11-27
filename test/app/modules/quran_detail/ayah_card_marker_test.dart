import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/widgets/ayah_end_marker.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';

import '../../../support/ayah_text.dart';

const _short = 'قُلْ هُوَ ٱللَّهُ أَحَدٌ';
final _long = List.filled(14, 'ٱلَّذِينَ يُؤْمِنُونَ بِٱلْغَيْبِ').join(' ');

Future<void> _pump(WidgetTester t, String arab, int n, double size) async {
  t.view.physicalSize = const Size(360, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: AyahCard(
            ayah: Ayah(
              surahNumber: 2,
              ayahNumber: n,
              arab: arab,
              translation: 't',
              tafsir: '',
            ),
            bookmarked: false,
            lastRead: false,
            prefs: ReadingPrefs(arabicFontSize: size, showTranslation: false),
            onBookmark: () {},
            onCopy: () {},
            onTafsir: () {},
            onMarkLastRead: () {},
          ),
        ),
      ),
    ),
  );
}

/// The last word, the Text next to the marker.
Finder get _lastWord => find
    .descendant(
      of: find.byWidgetPredicate(
        (w) => w is Row && w.children.last is AyahEndMarker,
      ),
      matching: find.byType(Text),
    )
    .first;

void main() {
  setUpAll(loadArabicFont);

  test('toArabicIndic', () {
    expect(toArabicIndic(10), '١٠');
    expect(toArabicIndic(286), '٢٨٦');
    expect(() => toArabicIndic(-1), throwsArgumentError);
  });

  for (final c in [('short', _short, 1), ('long', _long, 255)]) {
    for (final size in [20.0, 36.0]) {
      testWidgets('${c.$1} ayah $size: data text then marker, never alone', (
        t,
      ) async {
        await _pump(t, c.$2, c.$3, size);
        expect(ayahFinder(c.$2, c.$3), findsOneWidget);
        // Marker on the same line as the last word, ring right of the
        // word's left edge (RTL: the marker follows the word on the left).
        final word = t.getRect(_lastWord);
        final marker = t.getRect(find.byType(AyahEndMarker));
        expect(marker.center.dy, greaterThan(word.top));
        expect(marker.center.dy, lessThan(word.bottom));
        expect(marker.right, lessThanOrEqualTo(word.left + 0.5));
      });
    }
  }

  for (final e in {
    'space+U+06DA': ('${'ا' * 3} ۚ', 1),
    'U+06D9': ('ٱلْحَمْدُ لِلَّهِۙ', 2),
    'space+U+08D6': ('ٱلْعَلِيمُ ࣖ', 286),
  }.entries) {
    testWidgets('waqaf ${e.key} stays in the text before the marker', (
      t,
    ) async {
      await _pump(t, e.value.$1, e.value.$2, 28);
      expect(ayahFinder(e.value.$1, e.value.$2), findsOneWidget);
      final mark = e.key.contains('06DA')
          ? '\u06DA'
          : e.key.contains('06D9')
          ? '\u06D9'
          : '\u08D6';
      // The mark is in the data text, before the marker widget.
      expect(e.value.$1.trimRight().endsWith(mark), isTrue);
      final tail = t.widget<Text>(_lastWord);
      expect(tail.data!.endsWith(mark), isTrue);
    });
  }
}
