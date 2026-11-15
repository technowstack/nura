import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/daily_link.dart';

void main() {
  test('parses valid links', () {
    final a = parseDailyLink('nura://ayah/94/6');
    expect(a, isA<AyahLink>());
    expect((a as AyahLink).surah, 94);
    expect(a.ayah, 6);
    final h = parseDailyLink('nura://hadith/bukhari/12');
    expect(h, isA<HadithLink>());
    expect((h as HadithLink).slug, 'bukhari');
    expect(h.number, 12);
  });

  test('rejects invalid links', () {
    for (final s in [
      '',
      'nura://ayah/94',
      'nura://ayah/94/6/1',
      'nura://ayah/x/6',
      'nura://ayah/-1/6',
      'nura://ayah/94/-6',
      'nura://ayah/94/6.5',
      'nura://hadith/bukhari',
      'nura://hadith//12',
      'nura://hadith/bukhari/x',
      'nura://hadith/bukhari/12/3',
      'nura://other/1/2',
      'http://ayah/94/6',
      'https://nura/ayah/94/6',
      'ayah/94/6',
    ]) {
      expect(parseDailyLink(s), isNull, reason: s);
    }
  });
}
