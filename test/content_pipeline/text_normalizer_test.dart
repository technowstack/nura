import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/text_normalizer.dart';

void main() {
  test('arabic: strips harakat, quranic marks and tatweel', () {
    expect(normalizeArabicForSearch('بِسْمِ ٱللَّهِ'), 'بسم الله');
    expect(normalizeArabicForSearch('الْحَمْدُ لِلَّهِ ۖ'), 'الحمد لله');
    expect(normalizeArabicForSearch('قـــال'), 'قال');
  });
  test('arabic: normalizes alif, ya and ta marbuta', () {
    expect(normalizeArabicForSearch('أإآٱ'), 'اااا');
    expect(normalizeArabicForSearch('هدى'), 'هدي');
    expect(normalizeArabicForSearch('رحمة'), 'رحمه');
  });
  test('arabic: collapses whitespace and trims', () {
    expect(normalizeArabicForSearch('  قال   رسول  '), 'قال رسول');
  });
  test('indonesian: lowercases, replaces punctuation, collapses spaces', () {
    expect(normalizeIndonesianForSearch('Dengan nama Allah, Yang Maha Pengasih.'),
        'dengan nama allah yang maha pengasih');
    expect(normalizeIndonesianForSearch('"(Yaitu)"  orang-orang'),
        'yaitu orang orang');
  });
}
