import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/audio_api_client.dart';
import 'package:nura/app/data/sources/prayer_api_client.dart';

/// Loopback server only; no internet. Regression: the audio endpoint
/// (`GET /api/v2/surat/{id}`) answers 405 to a POST, and the shared default
/// transport used to POST for every caller ("Audio tidak dapat diputar.").
void main() {
  late HttpServer server;
  late Uri url;
  final methods = <String>[];

  setUp(() async {
    methods.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = Uri.parse('http://127.0.0.1:${server.port}/api/v2/surat/1');
    server.listen((r) async {
      methods.add(r.method);
      r.response.statusCode = r.method == 'GET' ? 200 : 405;
      r.response.write('{"code":200}');
      await r.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  test('audio transport uses GET', () async {
    final res = await defaultAudioHttp(url);
    expect(methods, ['GET']);
    expect(res.status, 200);
  });

  test('prayer transport still uses POST', () async {
    await defaultPrayerHttp(url, jsonBody: '{"a":1}');
    expect(methods, ['POST']);
  });
}
