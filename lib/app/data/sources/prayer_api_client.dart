import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/prayer_day.dart';
import '../models/prayer_region.dart';
import 'prayer_api_exception.dart';

typedef PrayerHttp =
    Future<({int status, String body})> Function(Uri url, {String? jsonBody});

final _endpoint = Uri.parse('https://equran.id/api/v2/shalat');
final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
const _timeFields = [
  'imsak',
  'subuh',
  'terbit',
  'dhuha',
  'dzuhur',
  'ashar',
  'maghrib',
  'isya',
];

final _unknownProvince = RegExp(r'^Provinsi ".*" tidak ditemukan');

const _maxBodyBytes = 1 << 20;

/// Default transport: one POST with a JSON body. [timeout] bounds connect,
/// response headers and the body read each; the body is capped at 1 MB.
/// Throws [TimeoutException], [IOException] or [FormatException] (invalid
/// UTF-8 or oversize body); [PrayerApiClient] maps them.
Future<({int status, String body})> defaultPrayerHttp(
  Uri url, {
  String? jsonBody,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final req = await client.postUrl(url);
    req.headers.contentType = ContentType.json;
    if (jsonBody != null) req.write(jsonBody);
    final res = await req.close().timeout(timeout);
    final bytes = <int>[];
    await for (final chunk in res.timeout(timeout)) {
      bytes.addAll(chunk);
      if (bytes.length > _maxBodyBytes) {
        throw const FormatException('response body too large');
      }
    }
    return (status: res.statusCode, body: utf8.decode(bytes));
  } finally {
    client.close(force: true);
  }
}

class PrayerApiClient {
  PrayerApiClient(PrayerHttp http, {int Function()? nowMs})
    : _http = http,
      _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final PrayerHttp _http;
  final int Function() _nowMs;

  Future<List<PrayerDay>> fetchMonth(
    PrayerRegion r,
    int year,
    int month,
  ) async {
    // The API answers 200 with the current month for an invalid one.
    if (month < 1 || month > 12 || year < 2000 || year > 2100) {
      throw BadResponse('invalid month/year: $year-$month');
    }
    final ({int status, String body}) res;
    try {
      res = await _http(
        _endpoint,
        jsonBody: jsonEncode({
          'provinsi': r.provinsi,
          'kabkota': r.kabkota,
          'bulan': month,
          'tahun': year,
        }),
      ).timeout(const Duration(seconds: 15));
    } on IOException {
      throw const Network();
    } on TimeoutException {
      throw const Network();
    } on FormatException {
      throw const BadResponse('undecodable body');
    }
    if (res.status >= 500) throw const Network();
    final Object? json;
    try {
      json = jsonDecode(res.body);
    } on FormatException {
      throw const BadResponse('unparseable JSON');
    }
    if (res.status == 404) {
      final msg = json is Map ? '${json['message']}' : '';
      // Unknown kabkota, or an unknown province (renamed or split).
      if (msg.contains('tidak ditemukan di provinsi') ||
          _unknownProvince.hasMatch(msg)) {
        throw const UnknownRegion();
      }
      if (msg.contains('Jadwal shalat untuk')) throw const NoDataForMonth();
      throw const BadResponse('unrecognised 404');
    }
    if (res.status != 200) throw BadResponse('HTTP ${res.status}');
    return _parse(json, r, year, month, _nowMs());
  }

  List<PrayerDay> _parse(
    Object? json,
    PrayerRegion r,
    int year,
    int month,
    int fetchedAt,
  ) {
    final data = json is Map ? json['data'] : null;
    if (data is! Map) throw const BadResponse('missing data');
    if (data['bulan'] != month || data['tahun'] != year) {
      throw const BadResponse('month/year mismatch');
    }
    if (data['provinsi'] != r.provinsi || data['kabkota'] != r.kabkota) {
      throw const BadResponse('region mismatch');
    }
    final jadwal = data['jadwal'];
    final expected = DateTime(year, month + 1, 0).day;
    if (jadwal is! List || jadwal.length != expected) {
      throw BadResponse('expected $expected days');
    }
    final prefix = '$year-${month.toString().padLeft(2, '0')}-';
    final days = <PrayerDay>[];
    for (var i = 0; i < expected; i++) {
      final e = jadwal[i];
      final dd = (i + 1).toString().padLeft(2, '0');
      if (e is! Map ||
          e['tanggal'] != i + 1 ||
          e['tanggal_lengkap'] != '$prefix$dd') {
        throw BadResponse('bad or out-of-order date on day ${i + 1}');
      }
      final t = <String, String>{};
      for (final f in _timeFields) {
        final v = e[f];
        if (v is! String || !_timePattern.hasMatch(v)) {
          throw BadResponse('bad $f on day ${i + 1}');
        }
        t[f] = v;
      }
      days.add(
        PrayerDay(
          date: '$prefix$dd',
          imsak: t['imsak'],
          subuh: t['subuh'],
          terbit: t['terbit'],
          dhuha: t['dhuha'],
          dzuhur: t['dzuhur'],
          ashar: t['ashar'],
          maghrib: t['maghrib'],
          isya: t['isya'],
          source: PrayerSource.api,
          fetchedAt: fetchedAt,
        ),
      );
    }
    return days;
  }
}
