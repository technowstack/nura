import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/juz_rules.dart';
import 'package:nura/content_pipeline/quran_source_parser.dart';

import '../../tool/fetch_juz.dart';
import 'loopback_server.dart';
import 'tanzil_starts.dart';

String xmlOf(List<(int, int)> starts) =>
    '<quran>\n<juzs alias="parts">\n${[for (var i = 0; i < starts.length; i++) '\t<juz index="${i + 1}" sura="${starts[i].$1}" aya="${starts[i].$2}" />'].join('\n')}\n</juzs>\n</quran>';

void main() {
  final counts = {
    for (final s in readQuranDir(Directory('data-source/quran')))
      s.number: s.ayahCount,
  };

  group('buildJuz', () {
    test('30 Tanzil starts cover all 6236 ayat without gaps', () {
      final juz = buildJuz(tanzilJuzStarts, counts);
      expect(juz, hasLength(30));
      expect(validateJuz(juz, counts, expectedCount: 30), isEmpty);
      expect(counts.values.reduce((a, b) => a + b), 6236);
      expect(
        [juz[1].startSurah, juz[1].startAyah, juz[1].endSurah, juz[1].endAyah],
        [2, 142, 2, 252],
      );
      expect([juz[14].startSurah, juz[14].startAyah], [17, 1]);
      expect(
        [juz[29].startSurah, juz[29].endSurah, juz[29].endAyah],
        [78, 114, 6],
      );
    });

    test('rejects a missing juz, wrong order and start past surah end', () {
      expect(
        () => buildJuz(tanzilJuzStarts.sublist(0, 29), counts),
        throwsFormatException,
      );
      final swapped = [...tanzilJuzStarts]..setAll(2, [(3, 93), (2, 253)]);
      expect(() => buildJuz(swapped, counts), throwsFormatException);
      final past = [...tanzilJuzStarts]..[3] = (3, 201);
      expect(() => buildJuz(past, counts), throwsFormatException);
      final wrongRef = [...tanzilJuzStarts]..[1] = (2, 141);
      expect(() => buildJuz(wrongRef, counts), throwsFormatException);
    });
  });

  group('parseJuzStarts', () {
    test('parses 30 elements', () {
      expect(parseJuzStarts(xmlOf(tanzilJuzStarts)), tanzilJuzStarts);
    });
    test('rejects wrong count and bad index', () {
      expect(
        () => parseJuzStarts(xmlOf(tanzilJuzStarts.sublist(1))),
        throwsFormatException,
      );
      expect(
        () => parseJuzStarts('<juz index="2" sura="1" aya="1" />'),
        throwsFormatException,
      );
      expect(() => parseJuzStarts('no xml'), throwsFormatException);
    });
  });

  group('fetchJuz over a real loopback socket', () {
    late Directory tmp;
    late File out;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fetch_juz');
      out = File('${tmp.path}/juz.json');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<int> run(Loopback s, {Duration? timeout}) => fetchJuz(
      url: s.url,
      out: out,
      ayahCounts: counts,
      timeout: timeout,
      now: DateTime.utc(2026, 11, 22),
    );

    test(
      'GET with Accept header writes object with source and fetched_at',
      () async {
        final s = await Loopback.start(body: xmlOf(tanzilJuzStarts));
        addTearDown(s.stop);
        expect(await run(s), 0);
        expect(s.methods, ['GET']);
        expect(s.accepts.single, contains('xml'));
        final j = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
        expect(j['fetched_at'], '2026-11-22T00:00:00.000Z');
        expect(j['source'], s.url.toString());
        expect(j['juz'], hasLength(30));
      },
    );

    test('non-200 fails and writes nothing', () async {
      final s = await Loopback.start(status: 500, body: 'x');
      addTearDown(s.stop);
      expect(await run(s), 1);
      expect(out.existsSync(), isFalse);
    });

    test('malformed body fails', () async {
      final s = await Loopback.start(body: '<html>oops</html>');
      addTearDown(s.stop);
      expect(await run(s), 1);
      expect(out.existsSync(), isFalse);
    });

    test('timeout fails', () async {
      final s = await Loopback.start(hang: true);
      addTearDown(s.stop);
      expect(await run(s, timeout: const Duration(milliseconds: 200)), 1);
      expect(out.existsSync(), isFalse);
    });
  });
}
