import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/matan_extractor.dart';

const _sal = "shallallahu 'alaihi wasallam";
const _arabKey = 'صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ';

String _tr(
  String body, {
  String lead = 'Dari [Abu Hurairah] ',
  String tail = '',
}) => '$lead $_sal bersabda: "$body"$tail';

// Arabic with a sanad, the key phrase, a speech verb and the matan.
String _ar(String body, {String verb = ' قَالَ'}) =>
    'حَدَّثَنَا فُلَانٌ عَنْ النَّبِيِّ $_arabKey$verb $body';

const _body = 'Barangsiapa menegakkan lailatul qodar karena iman';
const _arBody = 'مَنْ يَقُمْ لَيْلَةَ الْقَدْرِ إِيمَانًا وَاحْتِسَابًا';

Map<int, Map<String, dynamic>> _bukhari() {
  final list =
      jsonDecode(File('data-source/hadith/bukhari.json').readAsStringSync())
          as List<dynamic>;
  return {
    for (final e in list.cast<Map<String, dynamic>>()) e['number'] as int: e,
  };
}

void main() {
  group('extractMatan rule', () {
    test('translation matan is the text inside the quotes, arab after key', () {
      final tr = _tr(_body);
      final ar = _ar(_arBody);
      final m = extractMatan(ar, tr);
      expect(m, isNotNull);
      expect(tr.substring(m!.trStart, m.trEnd), _body);
      expect(ar.substring(m.arabStart, m.arabEnd), _arBody);
    });

    test('speech verb is optional and curly quotes work', () {
      final tr = 'Dari [A] $_sal bersabda: “$_body”';
      final ar = _ar(_arBody, verb: '');
      final m = extractMatan(ar, tr);
      expect(m, isNotNull);
      expect(tr.substring(m!.trStart, m.trEnd), _body);
      expect(ar.substring(m.arabStart, m.arabEnd), _arBody);
    });

    test(
      'rejects narrator brackets inside, second bersabda, trailing text',
      () {
        final ar = _ar(_arBody);
        expect(extractMatan(ar, _tr('$_body [Abu] lagi')), isNull);
        expect(extractMatan(ar, _tr('$_body dan bersabda: dia')), isNull);
        expect(extractMatan(ar, _tr(_body, tail: ' dan seterusnya')), isNull);
        expect(extractMatan(ar, _tr(_body, tail: ' .')), isNotNull);
      },
    );

    test('speech must follow the first salawat within 14 characters', () {
      final ar = _ar(_arBody);
      String tr(String gap) => 'Dari [A] $_sal${gap}bersabda: "$_body"';
      expect(extractMatan(ar, tr(' ' * 14)), isNotNull);
      expect(extractMatan(ar, tr(' ' * 15)), isNull);
      // Speech before the first salawat.
      expect(extractMatan(ar, 'Dia bersabda: "$_body" lalu $_sal'), isNull);
      // A later salawat next to the speech does not count: the first one
      // is more than 14 characters away.
      expect(
        extractMatan(ar, 'Dari [A] $_sal ${'x' * 20} $_sal bersabda: "$_body"'),
        isNull,
      );
    });

    test('rejects missing key phrases and short matan', () {
      expect(extractMatan(_ar(_arBody), 'tanpa kutipan'), isNull);
      expect(extractMatan('tanpa kunci $_arBody', _tr(_body)), isNull);
      expect(extractMatan(_ar('قصير'), _tr(_body)), isNull);
      expect(extractMatan(_ar(_arBody), _tr('pendek')), isNull);
    });

    test('translation length 300 passes, 301 fails', () {
      final ar = _ar('ب' * 250);
      expect(extractMatan(ar, _tr('a' * 300)), isNotNull);
      expect(extractMatan(ar, _tr('a' * 301)), isNull);
    });

    test('arabic over 300 chars or ratio outside 0.8..3.0 fails', () {
      expect(extractMatan(_ar('ب' * 300), _tr('a' * 300)), isNotNull);
      expect(extractMatan(_ar('ب' * 301), _tr('a' * 300)), isNull);
      expect(extractMatan(_ar('ب' * 100), _tr('a' * 79)), isNull);
      expect(extractMatan(_ar('ب' * 100), _tr('a' * 80)), isNotNull);
      expect(extractMatan(_ar('ب' * 50), _tr('a' * 150)), isNotNull);
      expect(extractMatan(_ar('ب' * 50), _tr('a' * 151)), isNull);
    });

    test('offsets are UTF-16 code units with non-BMP and combining marks', () {
      final tr = 'Dari [A] \u{1F600} $_sal bersabda: "$_body \u{1F600}x"';
      final ar = 'x\u{1F600} حَدَّثَنَا $_arabKey قَالَ $_arBody';
      final m = extractMatan(ar, tr);
      expect(m, isNotNull);
      expect(tr.substring(m!.trStart, m.trEnd), '$_body \u{1F600}x');
      expect(ar.substring(m.arabStart, m.arabEnd), _arBody);
    });
  });

  group('real Bukhari data', () {
    test('accepted examples give the exact matan', () {
      final b = _bukhari();
      final want = {
        34: 'Barangsiapa menegakkan lailatul qodar karena iman dan mengharap pahala, maka diampuni dosa-dosanya yang telah lalu',
        576:
            'Apabila kalian mendengar adzan, maka jawablah seperti apa yang diucapkan mu\'adzin.',
        588:
            'Di dua adzan (adzan dan iqamat) ada shalat sunah -beliau ucapkan tiga kali- bagi yang mau.',
        1945:
            'Sumpah itu melariskan dagangan jual beli namun menghilangkan barakah',
        2052:
            'Siapa yang menjual pohon kurma yang telah dikawinkan maka buahnya nanti menjadi hak penjual kecuali disyaratkan oleh pembeli',
        1934:
            'Allah merahmati orang yang memudahkan ketika menjual dan ketika membeli dan juga orang yang meminta haknya',
      };
      for (final e in want.entries) {
        final h = b[e.key]!;
        final m = extractMatan(h['arab'] as String, h['id'] as String);
        expect(m, isNotNull, reason: 'bukhari ${e.key}');
        expect((h['id'] as String).substring(m!.trStart, m.trEnd), e.value);
      }
    });

    // 41, 47 and 88 are rejected only by the alignment condition.
    test('misaligned examples are rejected', () {
      final b = _bukhari();
      for (final n in [112, 274, 660, 915, 1175, 41, 47, 88]) {
        final h = b[n]!;
        expect(
          extractMatan(h['arab'] as String, h['id'] as String),
          isNull,
          reason: 'bukhari $n',
        );
      }
    });
  });
}
