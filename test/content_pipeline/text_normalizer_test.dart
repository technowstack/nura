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
    expect(
      normalizeIndonesianForSearch('Dengan nama Allah, Yang Maha Pengasih.'),
      'dengan nama allah yang maha pengasih',
    );
    expect(
      normalizeIndonesianForSearch('"(Yaitu)"  orang-orang'),
      'yaitu orang orang',
    );
  });

  // Uthmani spellings as stored in ayah.arab (code points from content.db).
  const salat = '\u0627\u0644\u0635\u0651\u064e\u0644\u0670\u0648\u0629\u064e';
  const hayat = '\u0627\u0644\u0652\u062d\u064e\u064a\u0670\u0648\u0629\u064f';
  const samawat =
      '\u0627\u0644\u0633\u0651\u064e\u0645\u0670\u0648\u0670\u062a\u0650';
  const kitab = '\u0627\u0644\u0652\u0643\u0650\u062a\u0670\u0628\u064f';
  const salawat =
      '\u0627\u0644\u0635\u0651\u064e\u0644\u064e\u0648\u0670\u062a\u0650';

  group('normalizeArabicVariantForSearch (small alef as alef)', () {
    test('drops the waw written after a small alef (salat, hayat)', () {
      expect(normalizeArabicForSearch(salat), 'الصلوه');
      expect(normalizeArabicVariantForSearch(salat), 'الصلاه');
      expect(normalizeArabicVariantForSearch(hayat), 'الحياه');
    });
    test('keeps a waw that is itself followed by a small alef', () {
      expect(normalizeArabicVariantForSearch(samawat), 'السماوات');
      expect(normalizeArabicVariantForSearch(salawat), 'الصلوات');
    });
    test('a standalone small alef becomes alef', () {
      expect(normalizeArabicVariantForSearch(kitab), 'الكتاب');
    });
    test('text without a small alef equals the plain normalizer', () {
      expect(normalizeArabicVariantForSearch('بِسْمِ ٱللَّهِ'), 'بسم الله');
    });
  });

  group('normalizeAyahArabicForIndex', () {
    test('stores both forms when they differ, one when equal', () {
      expect(normalizeAyahArabicForIndex(salat), 'الصلوه الصلاه');
      expect(normalizeAyahArabicForIndex('بِسْمِ ٱللَّهِ'), 'بسم الله');
    });
  });
}
