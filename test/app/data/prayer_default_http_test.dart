import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/prayer_api_client.dart';

/// Loopback server only; no internet.
void main() {
  late HttpServer server;
  late Future<void> Function(HttpRequest) handler;
  late Uri url;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = Uri.parse('http://127.0.0.1:${server.port}/');
    server.listen((r) => handler(r));
  });
  tearDown(() => server.close(force: true));

  test('success returns status and body, posts JSON', () async {
    String? got;
    handler = (r) async {
      got = await utf8.decodeStream(r);
      r.response.write('{"ok":true}');
      await r.response.close();
    };
    final res = await defaultPrayerHttp(url, jsonBody: '{"a":1}');
    expect(res.status, 200);
    expect(res.body, '{"ok":true}');
    expect(got, '{"a":1}');
  });

  test('stalled body times out', () async {
    handler = (r) async {
      r.response.headers.contentLength = 100;
      r.response.add([65]);
      await r.response.flush();
      // never finishes; closed by tearDown
    };
    await expectLater(
      defaultPrayerHttp(url, timeout: const Duration(milliseconds: 200)),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('invalid UTF-8 throws FormatException', () async {
    handler = (r) async {
      r.response.add([0xff, 0xfe, 0xfd]);
      await r.response.close();
    };
    await expectLater(defaultPrayerHttp(url), throwsA(isA<FormatException>()));
  });

  test('oversize body throws FormatException', () async {
    handler = (r) async {
      r.response.add(List.filled(1100000, 65));
      await r.response.close();
    };
    await expectLater(defaultPrayerHttp(url), throwsA(isA<FormatException>()));
  });
}
