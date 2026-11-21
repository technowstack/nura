import 'dart:async';
import 'dart:io';

/// Loopback server answering every request with [status]/[body] (or never
/// answering when [hang]); records method and Accept header of requests.
class Loopback {
  Loopback._(this.server);
  final HttpServer server;
  final methods = <String>[];
  final accepts = <String?>[];
  Uri get url => Uri.parse('http://127.0.0.1:${server.port}/x');

  static Future<Loopback> start({
    int status = 200,
    String body = '',
    bool hang = false,
  }) async {
    final l = Loopback._(await HttpServer.bind('127.0.0.1', 0));
    l.server.listen((req) async {
      l.methods.add(req.method);
      l.accepts.add(req.headers.value(HttpHeaders.acceptHeader));
      if (hang) return;
      req.response.statusCode = status;
      req.response.write(body);
      await req.response.close();
    });
    return l;
  }

  Future<void> stop() => server.close(force: true);
}
