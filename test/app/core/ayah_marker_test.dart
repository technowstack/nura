import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/ayah_marker.dart';

void main() {
  test('strips trailing ASCII spaces and appends marker', () {
    expect(ayahDisplayText('قُلْ ', 3), 'قُلْ ۝٣');
    expect(ayahDisplayText('قُلْ', 3), ayahDisplayText('قُلْ ', 3));
    expect(ayahDisplayText('قُلْ  ', 3), 'قُلْ ۝٣');
  });

  test('digits are Arabic-Indic', () {
    expect(toArabicIndic(10), '١٠');
    expect(toArabicIndic(286), '٢٨٦');
    expect(ayahDisplayText('أ', 10), endsWith('۝١٠'));
  });

  test('exactly one NBSP, input otherwise untouched', () {
    const input = 'بِسْمِ اللّٰهِ';
    final out = ayahDisplayText(input, 1);
    expect(' '.allMatches(out).length, 1);
    expect(out.startsWith(input), isTrue);
    expect(ayahDisplayText('كلمة', 7), 'كلمة ۝٧');
  });

  test('only U+0020 is stripped', () {
    expect(ayahDisplayText('أ\u00A0', 1), 'أ\u00A0\u00A0۝١');
    expect(ayahDisplayText('أ\n', 1), 'أ\n\u00A0۝١');
  });

  test('negative numbers throw ArgumentError', () {
    expect(() => toArabicIndic(-1), throwsArgumentError);
    expect(() => ayahDisplayText('أ', -1), throwsArgumentError);
  });
}
