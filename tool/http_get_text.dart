import 'dart:convert';
import 'dart:io';

/// GETs [url] and returns the body. Throws [HttpException] on non-200 and
/// [TimeoutException] when the whole exchange exceeds [timeout].
Future<String> httpGetText(Uri url, {Duration? timeout}) async {
  final client = HttpClient()..userAgent = 'nura-data-tool';
  try {
    return await (() async {
      final req = await client.getUrl(url);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/xml');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      return body;
    })().timeout(timeout ?? const Duration(seconds: 30));
  } finally {
    client.close(force: true);
  }
}
