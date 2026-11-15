import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../core/errors.dart';
import '../models/hadith.dart';
import '../models/hadith_book.dart';
import '../sources/hadith_query_worker.dart';
import 'hadith_repository.dart';

/// Runs hadith queries in a long-lived worker isolate that owns its own
/// read-only connection (sqlite handles cannot cross isolates).
class IsolateHadithRepository implements HadithRepository {
  IsolateHadithRepository._() {
    _replies.listen(_onReply);
    _exitPort.listen((_) => _onGone('Isolate hadis berhenti'));
  }

  static Future<IsolateHadithRepository> start(File contentDb) async {
    final repo = IsolateHadithRepository._();
    try {
      repo._isolate = await Isolate.spawn<List<Object>>(
        hadithWorkerMain,
        [repo._replies.sendPort, contentDb.path],
        onExit: repo._exitPort.sendPort,
        onError: repo._exitPort.sendPort,
      );
      repo._send = await repo._ready.future;
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
  Isolate get workerIsolate => _isolate!; // set once start() returned

  /// Completes when the worker isolate has ended.
  @visibleForTesting
  Future<void> get exited => _exited.future;

  void _onReply(Object? m) {
    final msg = m! as List<Object?>; // shortcut: replies come from our worker
    if (msg[0] == 'ready') return _ready.complete(msg[1]! as SendPort);
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

  @override
  Future<List<HadithBook>> listBooks() async => [
    for (final m in await _call('listBooks', const []) as List<Object?>)
      bookFromMap(m! as Map<Object?, Object?>),
  ];

  @override
  Future<HadithPage> listPage(
    String slug, {
    int afterNumber = 0,
    int limit = 30,
  }) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    return pageFromMap(
      await _call('listPage', [slug, afterNumber, limit])
          as Map<Object?, Object?>,
    );
  }

  @override
  Future<Hadith> getHadith(HadithRef ref) async => hadithFromMap(
    await _call('getHadith', [ref.slug, ref.number]) as Map<Object?, Object?>,
  );

  @override
  Future<HadithRef?> neighbor(HadithRef ref, {required bool next}) async {
    final r = await _call('neighbor', [ref.slug, ref.number, next]);
    return r == null ? null : refFromMap(r as Map<Object?, Object?>);
  }
}
