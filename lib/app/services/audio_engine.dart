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

/// The platform paused playback by itself (audio focus lost, headphones
/// unplugged), not through [AudioEngine.pause].
class PausedByPlatform extends EngineEvent {
  const PausedByPlatform();
}

/// Playback failed; [reason] is for logs only, not for display.
class Failed extends EngineEvent {
  const Failed(this.reason);

  final String reason;
}

/// Streaming playback backend. Implementations must not write files.
abstract interface class AudioEngine {
  /// Replaces the queue. Throws [StateError] if the queue cannot be set.
  Future<void> setUrls(List<Uri> urls);

  /// Starts playback without waiting for it to finish.
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Stream<EngineEvent> get events;
  Future<void> dispose();
}

/// Very thin seam over the player so [JustAudioEngine] can be tested.
abstract interface class PlayerPort {
  bool get playing;
  Stream<int?> get currentIndex;
  Stream<bool> get completed;
  Stream<bool> get playingChanges;

  /// Platform and playback errors (reason text).
  Stream<String> get errors;
  Future<void> setUrls(List<Uri> urls);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioPort implements PlayerPort {
  JustAudioPort([AudioPlayer? player]) : _p = player ?? AudioPlayer();

  final AudioPlayer _p;

  @override
  bool get playing => _p.playing;

  @override
  Stream<int?> get currentIndex => _p.currentIndexStream;

  @override
  Stream<bool> get completed => _p.processingStateStream
      .map((s) => s == ProcessingState.completed)
      .distinct();

  @override
  Stream<bool> get playingChanges => _p.playingStream;

  // just_audio >= 0.10 reports platform errors on errorStream; the
  // playbackEventStream error path is kept too.
  @override
  Stream<String> get errors {
    late StreamController<String> c;
    final subs = <StreamSubscription<Object?>>[];
    c = StreamController<String>(
      onListen: () {
        subs.add(
          _p.errorStream.listen((e) => c.add('${e.code}: ${e.message}')),
        );
        subs.add(
          _p.playbackEventStream.listen(
            (_) {},
            onError: (Object e, StackTrace _) => c.add('$e'),
          ),
        );
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return c.stream;
  }

  @override
  Future<void> setUrls(List<Uri> urls) async {
    try {
      await _p.setAudioSources([for (final u in urls) AudioSource.uri(u)]);
    } catch (e) {
      throw StateError('setUrls failed: $e');
    }
  }

  @override
  Future<void> play() => _p.play();

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> stop() => _p.stop();

  @override
  Future<void> dispose() => _p.dispose();
}

/// Maps player callbacks to [EngineEvent]s (streams from the network, no
/// downloads).
class JustAudioEngine implements AudioEngine {
  JustAudioEngine({PlayerPort? port}) : _port = port ?? JustAudioPort() {
    _subs.add(
      _port.currentIndex.listen((i) {
        if (i != null) _emit(IndexChanged(i));
      }),
    );
    _subs.add(
      _port.completed.listen((done) {
        if (done) _emit(const Completed());
      }),
    );
    _subs.add(_port.errors.listen((r) => _emit(Failed(r))));
    _subs.add(
      _port.playingChanges.listen((p) {
        // true -> false without our own pause/stop = the platform paused us.
        if (!p && _wantPlaying) {
          _wantPlaying = false;
          _emit(const PausedByPlatform());
        }
      }),
    );
  }

  final PlayerPort _port;
  final _out = StreamController<EngineEvent>.broadcast();
  final _subs = <StreamSubscription<Object?>>[];
  bool _wantPlaying = false;

  void _emit(EngineEvent e) {
    if (!_out.isClosed) _out.add(e);
  }

  @override
  Stream<EngineEvent> get events => _out.stream;

  @override
  Future<void> setUrls(List<Uri> urls) => _port.setUrls(urls);

  @override
  Future<void> play() async {
    _wantPlaying = true;
    // just_audio's play() completes only when playback stops; do not await.
    unawaited(_port.play().catchError((Object e) => _emit(Failed('$e'))));
  }

  /// If the player is not playing (e.g. an audio-focus interruption is
  /// pending), stop() clears just_audio's internal "resume when focus
  /// returns" flag. Queue and position are kept, so play() resumes later.
  @override
  Future<void> pause() {
    _wantPlaying = false;
    return _port.playing ? _port.pause() : _port.stop();
  }

  @override
  Future<void> stop() {
    _wantPlaying = false;
    return _port.stop();
  }

  @override
  Future<void> dispose() async {
    _wantPlaying = false;
    for (final s in _subs) {
      await s.cancel();
    }
    await _port.dispose();
    await _out.close();
  }
}
