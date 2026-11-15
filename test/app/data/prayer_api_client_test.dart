import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/sources/prayer_api_client.dart';
import 'package:nura/app/data/sources/prayer_api_exception.dart';

const _jakarta = PrayerRegion(
  provinsi: 'DKI Jakarta',
  kabkota: 'Kota Jakarta',
  zone: PrayerZone.wib,
);

String _fixture(String name) =>
    File('test/fixtures/prayer/$name').readAsStringSync();

/// Builds a valid response body, optionally mutated before encoding.
String _body({
  String provinsi = 'DKI Jakarta',
  String kabkota = 'Kota Jakarta',
  int year = 2026,
  int month = 11,
  void Function(Map<String, dynamic> data, List<Map<String, dynamic>> days)?
  mutate,
}) {
  final n = DateTime(year, month + 1, 0).day;
  final days = [
    for (var d = 1; d <= n; d++)
      <String, dynamic>{
        'tanggal': d,
        'tanggal_lengkap':
            '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
        'imsak': '03:59',
        'subuh': '04:09',
        'terbit': '05:23',
        'dhuha': '05:51',
        'dzuhur': '11:40',
        'ashar': '14:55',
        'maghrib': '17:49',
        'isya': '19:00',
      },
  ];
  final data = <String, dynamic>{
    'provinsi': provinsi,
    'kabkota': kabkota,
    'bulan': month,
    'tahun': year,
    'jadwal': days,
  };
  mutate?.call(data, days);
  return jsonEncode({'code': 200, 'message': 'ok', 'data': data});
}

class _Fake {
  _Fake(this.respond);
  final Future<({int status, String body})> Function() respond;
  final calls = <({Uri url, String? jsonBody})>[];

  Future<({int status, String body})> call(Uri url, {String? jsonBody}) {
    calls.add((url: url, jsonBody: jsonBody));
    return respond();
  }
}

_Fake _ok(String body, [int status = 200]) =>
    _Fake(() async => (status: status, body: body));

PrayerApiClient _client(_Fake f, {int Function()? nowMs}) =>
    PrayerApiClient(f.call, nowMs: nowMs ?? () => 1000);

Future<void> _expectBad(
  String body, {
  PrayerRegion region = _jakarta,
  int year = 2026,
  int month = 11,
}) async {
  await expectLater(
    _client(_ok(body)).fetchMonth(region, year, month),
    throwsA(isA<BadResponse>()),
  );
}

void main() {
  test('real Jakarta fixture parses to 30 consecutive days', () async {
    final f = _ok(_fixture('jakarta_2026_11.json'));
    final days = await _client(
      f,
      nowMs: () => 42,
    ).fetchMonth(_jakarta, 2026, 11);
    expect(days, hasLength(30));
    expect(days.first.date, '2026-11-01');
    expect(days.last.date, '2026-11-30');
    expect(days.first.subuh, '04:09');
    expect(days.every((d) => d.source == PrayerSource.api), isTrue);
    expect(days.every((d) => d.fetchedAt == 42), isTrue);
    final req = f.calls.single;
    expect(req.url.toString(), 'https://equran.id/api/v2/shalat');
    expect(jsonDecode(req.jsonBody ?? ''), {
      'provinsi': 'DKI Jakarta',
      'kabkota': 'Kota Jakarta',
      'bulan': 11,
      'tahun': 2026,
    });
  });

  test('real Bontang fixture parses', () async {
    const r = PrayerRegion(
      provinsi: 'Kalimantan Timur',
      kabkota: 'Kota Bontang',
      zone: PrayerZone.wita,
    );
    final days = await _client(
      _ok(_fixture('bontang_2026_11.json')),
    ).fetchMonth(r, 2026, 11);
    expect(days, hasLength(30));
    expect(days.first.imsak, '04:24');
  });

  test('one fetchedAt per call', () async {
    var t = 0;
    final days = await _client(
      _ok(_body()),
      nowMs: () => ++t,
    ).fetchMonth(_jakarta, 2026, 11);
    expect(days.map((d) => d.fetchedAt).toSet(), {1});
  });

  test('request body carries exact region names', () async {
    const r = PrayerRegion(
      provinsi: 'D.I. Yogyakarta',
      kabkota: 'Kab. Sleman',
      zone: PrayerZone.wib,
    );
    final f = _ok(_body(provinsi: 'D.I. Yogyakarta', kabkota: 'Kab. Sleman'));
    await _client(f).fetchMonth(r, 2026, 11);
    final body = jsonDecode(f.calls.single.jsonBody ?? '') as Map;
    expect(body['provinsi'], 'D.I. Yogyakarta');
    expect(body['kabkota'], 'Kab. Sleman');
  });

  test('404 unknown region', () async {
    final f = _ok(
      '{"code":404,"message":"Kabupaten/Kota \\"X\\" tidak ditemukan di provinsi \\"Y\\"","data":null}',
      404,
    );
    await expectLater(
      _client(f).fetchMonth(_jakarta, 2026, 11),
      throwsA(isA<UnknownRegion>()),
    );
  });

  test('404 unknown province is UnknownRegion', () async {
    final f = _ok(
      '{"code":404,"message":"Provinsi \\"Papua Selatan\\" tidak ditemukan","data":null}',
      404,
    );
    await expectLater(
      _client(f).fetchMonth(_jakarta, 2026, 11),
      throwsA(isA<UnknownRegion>()),
    );
  });

  test('404 unrelated message stays BadResponse', () async {
    final f = _ok('{"message":"Halaman tidak ditemukan"}', 404);
    await expectLater(
      _client(f).fetchMonth(_jakarta, 2026, 11),
      throwsA(isA<BadResponse>()),
    );
  });

  test('404 month without data', () async {
    final f = _ok(
      '{"code":404,"message":"Jadwal shalat untuk \\"Kota Jakarta\\", \\"DKI Jakarta\\" bulan November 2035 tidak ditemukan","data":null}',
      404,
    );
    await expectLater(
      _client(f).fetchMonth(_jakarta, 2035, 11),
      throwsA(isA<NoDataForMonth>()),
    );
  });

  test('other 404 and odd statuses are BadResponse', () async {
    for (final s in [404, 400, 302]) {
      await expectLater(
        _client(_ok('{"message":"?"}', s)).fetchMonth(_jakarta, 2026, 11),
        throwsA(isA<BadResponse>()),
      );
    }
  });

  test('5xx is Network', () async {
    await expectLater(
      _client(_ok('oops', 503)).fetchMonth(_jakarta, 2026, 11),
      throwsA(isA<Network>()),
    );
  });

  test('unparseable JSON on 200 is BadResponse', () async {
    await _expectBad('not json');
  });

  test('404 with unparseable body is BadResponse', () async {
    await expectLater(
      _client(_ok('<html>', 404)).fetchMonth(_jakarta, 2026, 11),
      throwsA(isA<BadResponse>()),
    );
  });

  test('invalid month/year never calls http', () async {
    for (final (y, m) in [(2026, 0), (2026, 13), (1999, 5), (2101, 5)]) {
      final f = _ok(_body());
      await expectLater(
        _client(f).fetchMonth(_jakarta, y, m),
        throwsA(isA<BadResponse>()),
      );
      expect(f.calls, isEmpty);
    }
  });

  test('echo mismatch is BadResponse', () async {
    await _expectBad(_body(month: 10));
    await _expectBad(_body(year: 2025));
    await _expectBad(_body(provinsi: 'Bali'));
    await _expectBad(_body(kabkota: 'Kota Bekasi'));
  });

  test('non-numeric bulan/tahun echo is BadResponse', () async {
    await _expectBad(_body(mutate: (d, _) => d['bulan'] = '11'));
    await _expectBad(_body(mutate: (d, _) => d['tahun'] = 'abcd'));
    await _expectBad(_body(mutate: (d, _) => d['bulan'] = null));
  });

  test('200 with data null is BadResponse', () async {
    await _expectBad('{"code":200,"message":"ok","data":null}');
  });

  test('wrong day count', () async {
    await _expectBad(_body(mutate: (_, days) => days.removeLast()));
    await _expectBad(_body(mutate: (_, days) => days.add({...days.last})));
    // February: leap 29, non-leap 28.
    await _expectBad(
      _body(year: 2028, month: 2, mutate: (_, d) => d.removeLast()),
    );
    await _expectBad(
      _body(
        year: 2027,
        month: 2,
        mutate: (_, d) =>
            d.add({...d.last, 'tanggal': 29, 'tanggal_lengkap': '2027-02-29'}),
      ),
    );
    final feb = await _client(
      _ok(_body(year: 2028, month: 2)),
    ).fetchMonth(_jakarta, 2028, 2);
    expect(feb, hasLength(29));
  });

  test('duplicate or out-of-order dates', () async {
    await _expectBad(
      _body(
        mutate: (_, d) => d[5]['tanggal_lengkap'] = d[4]['tanggal_lengkap'],
      ),
    );
    await _expectBad(
      _body(
        mutate: (_, d) {
          final t = d[3];
          d[3] = d[4];
          d[4] = t;
        },
      ),
    );
    await _expectBad(_body(mutate: (_, d) => d[2]['tanggal'] = 9));
    await _expectBad(
      _body(mutate: (_, d) => d[0]['tanggal_lengkap'] = '2026-11-02'),
    );
  });

  test('bad time values', () async {
    for (final v in ['24:00', '', '9:5', '--:--', '12:60', '1200', null, 7]) {
      await _expectBad(_body(mutate: (_, d) => d[3]['isya'] = v));
    }
    await _expectBad(_body(mutate: (_, d) => d[3].remove('imsak')));
    final ok = await _client(
      _ok(_body(mutate: (_, d) => d[0]['subuh'] = '00:00')),
    ).fetchMonth(_jakarta, 2026, 11);
    expect(ok.first.subuh, '00:00');
  });

  test('FormatException from transport is BadResponse', () async {
    await expectLater(
      _client(
        _Fake(() => throw const FormatException('bad utf8')),
      ).fetchMonth(_jakarta, 2026, 11),
      throwsA(isA<BadResponse>()),
    );
  });

  test('IOException family and timeout map to Network', () async {
    for (final e in <Object>[
      const SocketException('down'),
      const HandshakeException('tls'),
      TimeoutException('slow'),
    ]) {
      await expectLater(
        _client(_Fake(() => throw e)).fetchMonth(_jakarta, 2026, 11),
        throwsA(isA<Network>()),
      );
    }
  });
}
