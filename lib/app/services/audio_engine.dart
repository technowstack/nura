import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Events a playback engine reports for the current queue.
sealed class EngineEvent {
  const EngineEvent();
}

/// The queue moved to item [index] (0-based, relative to the queue set).
class IndexChanged extends EngineEvent {
  const IndexChanged(this.index);

  final int index;
}

/// The whole queue finished playing.
class Completed extends EngineEvent {
  const Completed();
}

/// Playback failed; [reason] is for logs only, not for display.
class Failed extends EngineEvent {
  const Failed(this.reason);

  final String reason;
}

/// Streaming playback backend. Implementations must not write files.
abstract interface class AudioEngine {
  /// Replaces the queue. Throws [StateError] if the queue cannot be set.
  Future<void> setUrls(List<Uri> urls, {int initialIndex = 0});

  /// Starts playback without waiting for it to finish.
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Stream<EngineEvent> get events;
  Future<void> dispose();
}

/// Thin adapter over just_audio (streams from the network, no downloads).
class JustAudioEngine implements AudioEngine {
  JustAudioEngine({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _subs.add(
      _player.currentIndexStream.listen((i) {
        if (i != null) _out.add(IndexChanged(i));
      }),
    );
    _subs.add(
      _player.processingStateStream.listen((s) {
        if (s == ProcessingState.completed) _out.add(const Completed());
      }),
    );
    _subs.add(
      _player.playbackEventStream.listen(
        (_) {},
        onError: (Object e, StackTrace _) => _out.add(Failed('$e')),
      ),
    );
  }

  final AudioPlayer _player;
  final _out = StreamController<EngineEvent>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];

  @override
  Stream<EngineEvent> get events => _out.stream;

  @override
  Future<void> setUrls(List<Uri> urls, {int initialIndex = 0}) async {
    try {
      await _player.setAudioSources([
        for (final u in urls) AudioSource.uri(u),
      ], initialIndex: initialIndex);
    } catch (e) {
      throw StateError('setUrls failed: $e');
    }
  }

  @override
  Future<void> play() async {
    // just_audio's play() completes only when playback stops; do not await.
    unawaited(_player.play().catchError((Object e) => _out.add(Failed('$e'))));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _out.close();
  }
}
