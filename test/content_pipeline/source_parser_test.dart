import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/hadith_source_parser.dart';
import 'package:nura/content_pipeline/quran_source_parser.dart';
import 'package:nura/content_pipeline/source_models.dart';

import '../support/fixtures.dart';

void main() {
  test('parses surah 1 with 7 ayahs in numeric order', () {
    final s = readQuranDir(fixtureDir('quran')).firstWhere((s) => s.number == 1);
    expect(s.ayahCount, 7);
    expect(s.ayahs.map((a) => a.number), [1, 2, 3, 4, 5, 6, 7]);
    expect(s.nameLatin, isNotEmpty);
  });

  test('sorts surahs by number', () {
    expect(readQuranDir(fixtureDir('quran')).map((s) => s.number), [1, 100, 112]);
  });

  test('orders ayah keys numerically for surahs with 10+ ayahs', () {
    final s = readQuranDir(fixtureDir('quran')).firstWhere((s) => s.ayahCount >= 10);
    expect(s.ayahs.map((a) => a.number), List.generate(s.ayahCount, (i) => i + 1));
  });

  test('ayah text equals raw JSON value exactly', () {
    final text = File(fixturePath('quran/1.json')).readAsStringSync();
    final raw = jsonDecode(text) as Map<String, dynamic>;
    final s = parseQuranFile(text);
    expect(s.ayahs.first.arab, raw['1']['text']['1']);
    expect(s.ayahs.first.translation, raw['1']['translations']['id']['text']['1']);
    expect(s.ayahs.first.tafsir, raw['1']['tafsir']['id']['kemenag']['text']['1']);
    expect(s.nameId, raw['1']['translations']['id']['name']);
  });

  test('hadith keeps trailing spaces and ZWNJ', () {
    final b = readHadithDir(fixtureDir('hadith')).firstWhere((b) => b.slug == 'malik');
    final h = b.hadiths.firstWhere((h) => h.number == 99999);
    expect(h.arab, 'نص تجريبي  ');
    expect(h.translation, 'teks‌ uji  dengan  spasi  ');
    expect(b.hadiths.length, 6);
  });

  test('reads all hadith books by slug', () {
    final slugs = readHadithDir(fixtureDir('hadith')).map((b) => b.slug).toSet();
    expect(slugs, {'malik', 'darimi'});
  });

  test('throws SourceFormatException when ayah count mismatches number_of_ayah', () {
    final raw = jsonDecode(File(fixturePath('quran/1.json')).readAsStringSync())
        as Map<String, dynamic>;
    (raw['1']['text'] as Map<String, dynamic>).remove('7');
    expect(() => parseQuranFile(jsonEncode(raw)), throwsA(isA<SourceFormatException>()));
  });

  test('throws SourceFormatException when translation lacks an ayah key', () {
    final raw = jsonDecode(File(fixturePath('quran/1.json')).readAsStringSync())
        as Map<String, dynamic>;
    (raw['1']['translations']['id']['text'] as Map<String, dynamic>).remove('3');
    expect(() => parseQuranFile(jsonEncode(raw)), throwsA(isA<SourceFormatException>()));
  });
}
