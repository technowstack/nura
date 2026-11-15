import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../core/errors.dart';
import '../../core/search_query.dart';
import '../models/search_hit.dart';
import '../sources/search_query_worker.dart';
import 'search_repository.dart';

/// Runs search queries in a long-lived worker isolate that owns its own
/// read-only connection (sqlite handles cannot cross isolates), so snippet
/// building never blocks the UI isolate.
class IsolateSearchRepository implements SearchRepository {
  IsolateSearchRepository._() {
    // _onGone may fail _ready before anyone awaits it (e.g. spawn throws).
    _ready.future.ignore();
    _replies.listen(_onReply);
    _exitPort.listen((_) => _onGone('Isolate pencarian berhenti'));
  }

  /// Spawns the worker and waits up to [timeout] for it to open [contentDb].
  static Future<IsolateSearchRepository> start(
    File contentDb, {
    @visibleForTesting Duration timeout = const Duration(seconds: 10),
    @visibleForTesting
    void Function(List<Object>) entry = searchWorkerMain,
  }) async {
    final repo = IsolateSearchRepository._();
    try {
      repo._isolate = await Isolate.spawn<List<Object>>(
        entry,
        [repo._replies.sendPort, contentDb.path],
        onExit: repo._exitPort.sendPort,
        onError: repo._exitPort.sendPort,
      );
      repo._send = await repo._ready.future.timeout(timeout);
      return repo;
    } catch (e) {
      repo._isolate?.kill(priority: Isolate.immediate);
      repo._onGone('start failed');
      if (e is ContentUnavailable) rethrow;
      throw ContentUnavailable('Konten tidak dapat dibuka: $e');
    }
  }

  final ReceivePort _replies = ReceivePort();
  final ReceivePort _exitPort = ReceivePort();
  final Completer<SendPort> _ready = Completer<SendPort>();
  final Map<int, Completer<Object?>> _pending = {};
  final Completer<void> _exited = Completer<void>();
  Isolate? _isolate;
  late final SendPort _send;
  int _nextId = 0;
  bool _closed = false;

  @visibleForTesting
  Isolate? get workerIsolate => _isolate;

  /// Completes when the worker isolate has ended.
  @visibleForTesting
  Future<void> get exited => _exited.future;

  void _onReply(Object? m) {
    final msg = m as List<Object?>; // shortcut: replies come from our worker
    if (msg[0] == 'ready') return _ready.complete(msg[1] as SendPort);
    if (msg[0] == 'error') {
      return _ready.completeError(
        ContentUnavailable('Konten tidak dapat dibuka: ${msg[1]}'),
      );
    }
    final c = _pending.remove(msg[0]);
    if (c == null) return;
    if (msg[1] == true) {
      c.complete(msg[2]);
    } else {
      c.completeError(ContentUnavailable('${msg[2]}'));
    }
  }

  void _onGone(String why) {
    _closed = true;
    if (!_ready.isCompleted) {
      _ready.completeError(ContentUnavailable(why));
    }
    final waiting = _pending.values.toList();
    _pending.clear();
    for (final c in waiting) {
      c.completeError(ContentUnavailable(why));
    }
    if (!_exited.isCompleted) _exited.complete();
    _replies.close();
    _exitPort.close();
  }

  Future<Object?> _call(String op, List<Object?> args) {
    if (_closed) {
      return Future.error(const ContentUnavailable('Konten tidak tersedia'));
    }
    final id = _nextId++;
    final c = Completer<Object?>();
    _pending[id] = c;
    _send.send([id, op, args]);
    return c.future;
  }

  Future<void> close() async {
    if (_closed) return _exited.future;
    _closed = true;
    _send.send('close');
    try {
      await _exited.future.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      _isolate?.kill(priority: Isolate.immediate);
      await _exited.future;
    }
  }

  Future<SearchPage> _search(String op, ParsedQuery q, List<Object?> rest) {
    final limit = rest[1] as int;
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    return _call(op, [
      queryToMap(q),
      ...rest,
    ]).then((r) => searchPageFromMap(r as Map<Object?, Object?>));
  }

  @override
  Future<SearchPage> searchAyah(
    ParsedQuery q, {
    int afterRowId = 0,
    int limit = 30,
  }) async => _search('searchAyah', q, [afterRowId, limit]);

  @override
  Future<SearchPage> searchHadith(
    ParsedQuery q, {
    String? bookSlug,
    int afterRowId = 0,
    int limit = 30,
  }) async => _search('searchHadith', q, [afterRowId, limit, bookSlug]);
}
