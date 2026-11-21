import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/quran_source_parser.dart';

import '../../tool/fetch_surah_info.dart';
import 'loopback_server.dart';

void main() {
  final counts = {
    for (final s in readQuranDir(Directory('data-source/quran')))
      s.number: s.ayahCount,
  };
  // Arbitrary Madinah set: the parser only maps the strings, it is not data.
  const madinah = {
    2,
    3,
    4,
    5,
    8,
    9,
    13,
    22,
    24,
    33,
    47,
    48,
    49,
    55,
    57,
    58,
    59,
    60,
    61,
    62,
    63,
    64,
    65,
    66,
    76,
    98,
    99,
    110,
  };
  String body({
    int? skip,
    int? dup,
    String? place,
    int? wrongCount,
    int extra = 0,
  }) {
    final data = <Map<String, Object>>[
      for (var n = 1; n <= 114 + extra; n++)
        if (n != skip)
          {
            'nomor': n > 114 ? 1 : n,
            'namaLatin': 'S$n',
            'jumlahAyat': n == wrongCount ? 1 : counts[n > 114 ? 1 : n] ?? 0,
            'tempatTurun': n == 7 && place != null
                ? place
                : madinah.contains(n)
                ? 'Madinah'
                : 'Mekah',
          },
      if (dup != null)
        {'nomor': dup, 'jumlahAyat': counts[dup] ?? 0, 'tempatTurun': 'Mekah'},
    ];
    return jsonEncode({'code': 200, 'data': data});
  }

  group('parseSurahInfo', () {
    test('maps Mekah/Madinah and keeps order', () {
      final r = parseSurahInfo(body(), counts);
      expect(r, hasLength(114));
      expect(r.first, {'number': 1, 'revelation': 'makkiyah'});
      expect(r[1], {'number': 2, 'revelation': 'madaniyah'});
      expect(
        r.where((e) => e['revelation'] == 'madaniyah'),
        hasLength(madinah.length),
      );
    });
    test('rejects unknown place, missing, duplicate, extra, wrong count', () {
      expect(
        () => parseSurahInfo(body(place: 'Bumi'), counts),
        throwsFormatException,
      );
      expect(
        () => parseSurahInfo(body(skip: 50), counts),
        throwsFormatException,
      );
      expect(() => parseSurahInfo(body(dup: 3), counts), throwsFormatException);
      expect(
        () => parseSurahInfo(body(extra: 1), counts),
        throwsFormatException,
      );
      expect(
        () => parseSurahInfo(body(wrongCount: 9), counts),
        throwsFormatException,
      );
      expect(() => parseSurahInfo('{"data":1}', counts), throwsFormatException);
      expect(() => parseSurahInfo('nope', counts), throwsFormatException);
    });
  });

  group('fetchSurahInfo over a real loopback socket', () {
    late Directory tmp;
    late File out;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fetch_si');
      out = File('${tmp.path}/surah_info.json');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<int> run(Loopback s, {Duration? timeout}) => fetchSurahInfo(
      url: s.url,
      out: out,
      ayahCounts: counts,
      timeout: timeout,
      now: DateTime.utc(2026, 11, 22),
    );

    test(
      'GET with Accept header writes object with source and fetched_at',
      () async {
        final s = await Loopback.start(body: body());
        addTearDown(s.stop);
        expect(await run(s), 0);
        expect(s.methods, ['GET']);
        expect(s.accepts.single, contains('json'));
        final j = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
        expect(j['fetched_at'], '2026-11-22T00:00:00.000Z');
        expect(j['surahs'], hasLength(114));
      },
    );
    test('non-200, malformed body and timeout fail without output', () async {
      final bad = await Loopback.start(status: 503, body: body());
      final junk = await Loopback.start(body: 'not json');
      final hang = await Loopback.start(hang: true);
      addTearDown(bad.stop);
      addTearDown(junk.stop);
      addTearDown(hang.stop);
      expect(await run(bad), 1);
      expect(await run(junk), 1);
      expect(await run(hang, timeout: const Duration(milliseconds: 200)), 1);
      expect(out.existsSync(), isFalse);
    });
  });
}
