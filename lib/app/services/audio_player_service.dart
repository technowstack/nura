import 'dart:async';
import 'dart:ui' show AppLifecycleState;

import 'package:get/get.dart';

import '../data/models/ayah.dart';
import '../data/models/surah_audio.dart';
import '../data/repositories/audio_settings_store.dart';
import '../data/sources/audio_api_client.dart';
import '../data/sources/audio_api_exception.dart';
import 'audio_engine.dart';
import 'online_service.dart';

sealed class PlaybackState {
  const PlaybackState();
}

class PlaybackIdle extends PlaybackState {
  const PlaybackIdle();
}

class PlaybackLoading extends PlaybackState {
  const PlaybackLoading();
}

class PlaybackPlaying extends PlaybackState {
  const PlaybackPlaying(this.surah, this.ayah);

  final int surah;
  final int ayah;

  @override
  bool operator ==(Object other) =>
      other is PlaybackPlaying && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash('playing', surah, ayah);
}

class PlaybackPaused extends PlaybackState {
  const PlaybackPaused(this.surah, this.ayah);

  final int surah;
  final int ayah;

  @override
  bool operator ==(Object other) =>
      other is PlaybackPaused && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash('paused', surah, ayah);
}

/// A call superseded by a newer play/stop call reports [ok] (nothing to show).
enum PlayResult { ok, switchedOff, needsInternet, failed }

/// Streaming-only ayah playback behind the online audio switch.
///
/// [lastError] (short Indonesian message, cleared on the next successful play;
/// the UI shows a snackbar when it becomes non-null) is set for: engine
/// failure mid-queue, connection lost while loading/playing, and a `failed`
/// result (bad response, not found, qari without URLs, engine setup error).
/// It is NOT set for `needsInternet` or `switchedOff` (the control shows
/// 'Butuh internet' / is hidden).
class AudioPlayerService {
  AudioPlayerService(
    this._online,
    this._api,
    this._settings,
    this._engine, {
    Stream<AppLifecycleState>? lifecycle,
    Stream<bool>? connectivity,
  }) {
    _subs.add(_engine.events.listen(_onEngineEvent));
    _subs.add(
      _online.audioEnabledChanges.listen((on) {
        if (!on) unawaited(stop());
      }),
    );
    if (connectivity != null) {
      _subs.add(
        connectivity.listen((online) {
          if (online || _disposed) return;
          if (_busy || state.value is! PlaybackIdle) {
            unawaited(stop());
            lastError.value = 'Koneksi terputus. Pemutaran dihentikan.';
          }
        }),
      );
    }
    if (lifecycle != null) {
      _subs.add(
        lifecycle.listen((s) {
          // `inactive` is ignored (Android overlays/dialogs).
          if (s == AppLifecycleState.resumed ||
              s == AppLifecycleState.inactive) {
            return;
          }
          // Never auto-resume on return to the foreground. A play still in
          // flight (even before state is loading) is cancelled.
          if (_busy || state.value is PlaybackLoading) {
            unawaited(stop());
          } else {
            unawaited(pause());
          }
        }),
      );
    }
  }

  final OnlineService _online;
  final AudioApiClient _api;
  final AudioSettingsStore _settings;
  final AudioEngine _engine;
  final _subs = <StreamSubscription<Object?>>[];
  final _cache = <int, Future<SurahAudio>>{};

  final Rx<PlaybackState> state = Rx<PlaybackState>(const PlaybackIdle());
  final Rx<String?> lastError = Rx<String?>(null);

  // True while a play call (or a surah switch inside a queue) is between
  // its gate and its engine start.
  bool _busy = false;
  int _gen = 0;
  bool _accepting = false;
  bool _disposed = false;

  // The running queue: one segment per run of ayat of the same surah. The
  // engine only ever holds the current segment; the next one is set when it
  // completes, so a surah's URLs are requested only when playback gets there.
  var _segs = const <_Seg>[];
  int _segIdx = 0;
  Future<List<Uri>>? _nextUrls;

  Future<PlayResult> playAyah(int surah, int ayah, int ayahTotal) =>
      playRange([AyahRef(surah, ayah)], {surah: ayahTotal});

  Future<PlayResult> playFrom(int surah, int ayah, int ayahTotal) => playRange(
    [
      // Out of range: one invalid ref so the call fails like before.
      if (ayah > ayahTotal) AyahRef(surah, ayah),
      for (var a = ayah; a <= ayahTotal; a++) AyahRef(surah, a),
    ],
    {surah: ayahTotal},
  );

  /// Plays [refs] in order, possibly across surahs. [ayahTotals] gives the
  /// ayah count of each surah in [refs] (validates the API response).
  Future<PlayResult> playRange(
    List<AyahRef> refs,
    Map<int, int> ayahTotals,
  ) async {
    if (_disposed || !_online.audioEnabled) return PlayResult.switchedOff;
    if (refs.isEmpty) return PlayResult.failed;
    final gen = ++_gen;
    _busy = true;
    try {
      return await _run(gen, _segments(refs, ayahTotals));
    } finally {
      if (gen == _gen) _busy = false;
    }
  }

  static List<_Seg> _segments(List<AyahRef> refs, Map<int, int> totals) {
    final segs = <_Seg>[];
    for (final r in refs) {
      if (segs.isEmpty || segs.last.surah != r.surah) {
        segs.add(_Seg(r.surah, totals[r.surah] ?? 0));
      }
      segs.last.ayahs.add(r.ayah);
    }
    return segs;
  }

  Future<PlayResult> _run(int gen, List<_Seg> segs) async {
    if (!await _online.canReach()) {
      return gen == _gen ? PlayResult.needsInternet : PlayResult.ok;
    }
    if (gen != _gen) return PlayResult.ok;
    _accepting = false;
    state.value = const PlaybackLoading();
    await _safeStop();
    try {
      if (gen != _gen) return PlayResult.ok;
      final queue = await _segUrls(segs.first);
      if (gen != _gen) return PlayResult.ok;
      _segs = segs;
      _segIdx = 0;
      _nextUrls = null;
      await _engine.setUrls(queue);
      if (gen != _gen) {
        await _safeStop();
        return PlayResult.ok;
      }
      _accepting = true;
      await _engine.play();
      if (gen != _gen) return PlayResult.ok;
      lastError.value = null;
      if (state.value is PlaybackLoading) {
        state.value = PlaybackPlaying(segs.first.surah, segs.first.ayahs.first);
      }
      return PlayResult.ok;
    } on AudioNetwork {
      return _giveUp(gen, PlayResult.needsInternet);
    } catch (_) {
      // AudioBadResponse, AudioNotFound, engine StateError, anything else.
      await _safeStop();
      return _giveUp(gen, PlayResult.failed);
    }
  }

  Future<List<Uri>> _segUrls(_Seg seg) async {
    final audio = await _fetch(seg.surah, seg.total);
    final urls = audio.urlsFor(_settings.qariId);
    if (urls == null || seg.ayahs.any((a) => a < 1 || a > urls.length)) {
      throw StateError('no audio for surah ${seg.surah}');
    }
    return [for (final a in seg.ayahs) urls[a - 1]];
  }

  /// Current segment finished: set the next one (its URLs were prefetched
  /// when the last ayah of the previous segment started).
  Future<void> _advance() async {
    final gen = _gen;
    _busy = true; // backgrounding now stops instead of pausing
    final next = _segIdx + 1;
    try {
      final pre = _nextUrls;
      List<Uri> urls;
      try {
        urls = await (pre ?? _segUrls(_segs[next]));
      } catch (_) {
        if (gen != _gen) return;
        if (pre == null) rethrow;
        // The prefetch failed (and was evicted from the cache): one retry.
        _nextUrls = null;
        urls = await _segUrls(_segs[next]);
      }
      if (gen != _gen) return;
      if (state.value is! PlaybackPlaying) return await stop();
      _segIdx = next;
      _nextUrls = null;
      await _engine.setUrls(urls);
      if (gen != _gen) return;
      await _engine.play();
      if (gen != _gen) return;
      final seg = _segs[next];
      state.value = PlaybackPlaying(seg.surah, seg.ayahs.first);
    } on AudioNetwork {
      await _failAdvance(gen, 'Koneksi terputus. Pemutaran dihentikan.');
    } catch (_) {
      await _failAdvance(gen, 'Audio tidak dapat diputar.');
    } finally {
      if (gen == _gen) _busy = false;
    }
  }

  Future<void> _failAdvance(int gen, String message) async {
    if (gen != _gen) return;
    _gen++;
    _busy = false;
    _accepting = false;
    state.value = const PlaybackIdle();
    lastError.value = message;
    await _safeStop();
  }

  PlayResult _giveUp(int gen, PlayResult r) {
    if (gen != _gen) return PlayResult.ok;
    state.value = const PlaybackIdle();
    if (r == PlayResult.failed) lastError.value = 'Audio tidak dapat diputar.';
    return r;
  }

  /// One request per surah per session; concurrent callers share it.
  Future<SurahAudio> _fetch(int surah, int total) async {
    final f = _cache[surah] ??= _api.fetchSurah(
      surah,
      expectedAyahCount: total,
    );
    try {
      return await f;
    } catch (_) {
      if (identical(_cache[surah], f)) _cache.remove(surah);
      rethrow;
    }
  }

  void _onEngineEvent(EngineEvent e) {
    if (_disposed || !_accepting) return;
    switch (e) {
      case IndexChanged(:final index):
        final s = state.value;
        final seg = _segs[_segIdx];
        if ((s is PlaybackLoading || s is PlaybackPlaying) &&
            index < seg.ayahs.length) {
          state.value = PlaybackPlaying(seg.surah, seg.ayahs[index]);
          // Last ayah of this surah: fetch the next surah's URLs now.
          if (index == seg.ayahs.length - 1 &&
              _segIdx + 1 < _segs.length &&
              _nextUrls == null) {
            _nextUrls = _segUrls(_segs[_segIdx + 1])..ignore();
          }
        }
      case PausedByPlatform():
        final s = state.value;
        if (s is PlaybackPlaying) state.value = PlaybackPaused(s.surah, s.ayah);
      case Completed():
        if (_segIdx + 1 < _segs.length && state.value is PlaybackPlaying) {
          unawaited(_advance());
        } else {
          state.value = const PlaybackIdle();
        }
      case Failed():
        unawaited(_failMidQueue());
    }
  }

  Future<void> _failMidQueue() async {
    _gen++;
    _busy = false;
    _accepting = false;
    state.value = const PlaybackIdle();
    lastError.value = 'Audio gagal diputar. Coba lagi nanti.';
    await _safeStop();
  }

  Future<void> pause() async {
    final s = state.value;
    if (s is PlaybackPaused) {
      // Already paused (maybe by the platform): still make sure the engine
      // will not resume by itself when audio focus returns.
      try {
        await _engine.pause();
      } catch (_) {}
      return;
    }
    if (s is! PlaybackPlaying) return;
    state.value = PlaybackPaused(s.surah, s.ayah);
    try {
      await _engine.pause();
    } catch (_) {
      await _failMidQueue();
    }
  }

  Future<void> resume() async {
    final s = state.value;
    if (s is! PlaybackPaused) return;
    if (!_online.audioEnabled) return stop();
    state.value = PlaybackPlaying(s.surah, s.ayah);
    try {
      await _engine.play();
    } catch (_) {
      await _failMidQueue();
    }
  }

  Future<void> stop() async {
    _gen++;
    _busy = false;
    _accepting = false;
    final wasIdle = state.value is PlaybackIdle;
    state.value = const PlaybackIdle();
    if (!wasIdle) await _safeStop();
  }

  /// Task 4 calls this after the qari setting changed.
  void onQariChanged() {
    // The cached SurahAudio already holds every qari; only playback stops.
    unawaited(stop());
  }

  Future<void> _safeStop() async {
    try {
      await _engine.stop();
    } catch (_) {
      // Stopping is best effort; state is already idle or being replaced.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _gen++;
    _busy = false;
    state.value = const PlaybackIdle();
    for (final s in _subs) {
      await s.cancel();
    }
    await _engine.dispose();
  }
}

/// Ayat of one surah in a queue, played as one engine queue.
class _Seg {
  _Seg(this.surah, this.total);

  final int surah;
  final int total;
  final ayahs = <int>[];
}
