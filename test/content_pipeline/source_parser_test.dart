import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/hadith_source_parser.dart';
import 'package:nura/content_pipeline/quran_source_parser.dart';
import 'package:nura/content_pipeline/source_models.dart';

import '../support/fixtures.dart';

void main() {
  test('parses surah 1 with 7 ayahs in numeric order', () {
    final s = readQuranDir(
      fixtureDir('quran'),
    ).firstWhere((s) => s.number == 1);
    expect(s.ayahCount, 7);
    expect(s.ayahs.map((a) => a.number), [1, 2, 3, 4, 5, 6, 7]);
    expect(s.nameLatin, isNotEmpty);
  });

  test('sorts surahs by number', () {
    expect(readQuranDir(fixtureDir('quran')).map((s) => s.number), [
      1,
      100,
      112,
    ]);
  });

  test('orders ayah keys numerically for surahs with 10+ ayahs', () {
    final s = readQuranDir(
      fixtureDir('quran'),
    ).firstWhere((s) => s.ayahCount >= 10);
    expect(
      s.ayahs.map((a) => a.number),
      List.generate(s.ayahCount, (i) => i + 1),
    );
  });

  test('ayah text equals raw JSON value exactly', () {
    final text = File(fixturePath('quran/1.json')).readAsStringSync();
    final raw = jsonDecode(text) as Map<String, dynamic>;
    final s = parseQuranFile(text);
    expect(s.ayahs.first.arab, raw['1']['text']['1']);
    expect(
      s.ayahs.first.translation,
      raw['1']['translations']['id']['text']['1'],
    );
    expect(
      s.ayahs.first.tafsir,
      raw['1']['tafsir']['id']['kemenag']['text']['1'],
    );
    expect(s.nameId, raw['1']['translations']['id']['name']);
  });

  test('hadith keeps trailing spaces and ZWNJ', () {
    final b = readHadithDir(
      fixtureDir('hadith'),
    ).firstWhere((b) => b.slug == 'malik');
    final h = b.hadiths.firstWhere((h) => h.number == 99999);
    expect(h.arab, 'نص تجريبي  ');
    expect(h.translation, 'teks‌ uji  dengan  spasi  ');
    expect(b.hadiths.length, 6);
  });

  test('reads all hadith books by slug', () {
    final slugs = readHadithDir(
      fixtureDir('hadith'),
    ).map((b) => b.slug).toSet();
    expect(slugs, {'malik', 'darimi'});
  });

  test('orders ayah keys numerically even when JSON key order is scrambled', () {
    final raw =
        jsonDecode(File(fixturePath('quran/100.json')).readAsStringSync())
            as Map<String, dynamic>;
    final surah = raw['100'] as Map<String, dynamic>;
    Map<String, dynamic> scramble(Map<String, dynamic> m) {
      // String order puts "10" before "2"; reversed insertion defeats map order.
      final keys = m.keys.toList()..sort();
      return {for (final k in keys.reversed) k: m[k]};
    }

    surah['text'] = scramble(surah['text'] as Map<String, dynamic>);
    final id =
        (surah['translations'] as Map<String, dynamic>)['id']
            as Map<String, dynamic>;
    id['text'] = scramble(id['text'] as Map<String, dynamic>);
    final kemenag =
        ((surah['tafsir'] as Map<String, dynamic>)['id']
                as Map<String, dynamic>)['kemenag']
            as Map<String, dynamic>;
    kemenag['text'] = scramble(kemenag['text'] as Map<String, dynamic>);

    final s = parseQuranFile(jsonEncode(raw));
    expect(
      s.ayahs.map((a) => a.number),
      List.generate(s.ayahCount, (i) => i + 1),
    );
  });

  Map<String, dynamic> loadSurah1() =>
      jsonDecode(File(fixturePath('quran/1.json')).readAsStringSync())
          as Map<String, dynamic>;

  Matcher formatError(String file, String messagePart) => throwsA(
    isA<SourceFormatException>()
        .having((e) => e.file, 'file', file)
        .having((e) => e.message, 'message', contains(messagePart))
        .having(
          (e) => e.message,
          'message',
          isNot(contains('invalid quran json')),
        ),
  );

  test('throws count mismatch error when an ayah key is removed from text', () {
    final raw = loadSurah1();
    (raw['1']['text'] as Map<String, dynamic>).remove('7');
    expect(
      () => parseQuranFile(jsonEncode(raw), file: 'quran/1.json'),
      formatError('quran/1.json', 'ayah count 6 != number_of_ayah 7'),
    );
  });

  test('throws missing-key error when translation lacks an ayah key', () {
    final raw = loadSurah1();
    (raw['1']['translations']['id']['text'] as Map<String, dynamic>).remove(
      '3',
    );
    expect(
      () => parseQuranFile(jsonEncode(raw), file: 'quran/1.json'),
      formatError('quran/1.json', 'ayah 3 missing translation or tafsir'),
    );
  });

  test('throws missing-key error when tafsir lacks an ayah key', () {
    final raw = loadSurah1();
    (raw['1']['tafsir']['id']['kemenag']['text'] as Map<String, dynamic>)
        .remove('5');
    expect(
      () => parseQuranFile(jsonEncode(raw), file: 'quran/1.json'),
      formatError('quran/1.json', 'ayah 5 missing translation or tafsir'),
    );
  });
}
