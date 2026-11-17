import 'dart:async';

import 'package:nura/app/services/audio_engine.dart';

class FakeAudioEngine implements AudioEngine {
  final calls = <String>[];
  final queues = <List<Uri>>[];
  final _ctl = StreamController<EngineEvent>.broadcast(sync: true);
  Object? setUrlsError;
  Completer<void>? setUrlsGate;
  Object? pauseError;
  Object? playError;
  bool disposed = false;

  void emit(EngineEvent e) => _ctl.add(e);
  bool get hasListener => _ctl.hasListener;

  @override
  Stream<EngineEvent> get events => _ctl.stream;

  @override
  Future<void> setUrls(List<Uri> urls, {int initialIndex = 0}) async {
    calls.add('setUrls');
    queues.add(urls);
    await setUrlsGate?.future;
    final e = setUrlsError;
    if (e != null) throw e;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    final e = playError;
    if (e != null) throw e;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    final e = pauseError;
    if (e != null) throw e;
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
  }
}
