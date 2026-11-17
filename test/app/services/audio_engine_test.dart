import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/services/audio_engine.dart';

class _Port implements PlayerPort {
  final idx = StreamController<int?>.broadcast(sync: true);
  final done = StreamController<bool>.broadcast(sync: true);
  final play$ = StreamController<bool>.broadcast(sync: true);
  final err = StreamController<String>.broadcast(sync: true);
  final calls = <String>[];
  @override
  bool playing = false;
  Object? playError;

  @override
  Stream<int?> get currentIndex => idx.stream;
  @override
  Stream<bool> get completed => done.stream;
  @override
  Stream<bool> get playingChanges => play$.stream;
  @override
  Stream<String> get errors => err.stream;
  @override
  Future<void> setUrls(List<Uri> urls) async => calls.add('setUrls');
  @override
  Future<void> play() async {
    calls.add('play');
    playing = true;
    final e = playError;
    if (e != null) throw e;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing = false;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    playing = false;
  }

  @override
  Future<void> dispose() async => calls.add('dispose');
}

void main() {
  late _Port port;
  late JustAudioEngine engine;
  late List<EngineEvent> events;

  setUp(() {
    port = _Port();
    engine = JustAudioEngine(port: port);
    events = [];
    engine.events.listen(events.add);
  });

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('error becomes one Failed', () async {
    port.err.add('404');
    await tick();
    expect(events.whereType<Failed>().length, 1);
  });

  test('play() failure becomes Failed', () async {
    port.playError = StateError('x');
    await engine.play();
    await tick();
    expect(events.whereType<Failed>().length, 1);
  });

  test('index change and completion map once', () async {
    port.idx.add(2);
    port.idx.add(null);
    port.done.add(false);
    port.done.add(true);
    await tick();
    expect(events.whereType<IndexChanged>().single.index, 2);
    expect(events.whereType<Completed>().length, 1);
  });

  test('platform pause is reported, own pause/stop is not', () async {
    await engine.play();
    port.play$.add(false);
    await tick();
    expect(events.whereType<PausedByPlatform>().length, 1);
    await engine.play();
    await engine.pause();
    port.play$.add(false);
    await engine.play();
    await engine.stop();
    port.play$.add(false);
    await tick();
    expect(events.whereType<PausedByPlatform>().length, 1);
  });

  test('pause when not playing stops to clear the interruption flag', () async {
    await engine.pause();
    expect(port.calls.last, 'stop');
    await engine.play();
    await engine.pause();
    expect(port.calls.last, 'pause');
  });

  test('dispose then late events do not throw', () async {
    await engine.dispose();
    port.err.add('late');
    port.idx.add(1);
    port.play$.add(false);
    await tick();
    expect(port.calls, contains('dispose'));
    engine.play().ignore();
    await tick();
  });
}
