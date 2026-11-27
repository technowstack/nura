import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/ui_state.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/surah.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/online_service.dart';
import '../notify_last_read_changed.dart';
import '../reading_prefs_mixin.dart';
import '../surah_args.dart';

class SurahContent {
  const SurahContent({
    required this.surah,
    required this.basmalah,
    required this.ayahs,
  });

  final Surah surah;
  final String basmalah;
  final List<Ayah> ayahs;
}

/// Audio control state of one ayah of the open surah.
enum AyahAudioState { hidden, ready, needsInternet, loading, playing, paused }

class QuranDetailController extends GetxController with ReadingPrefsMixin {
  QuranDetailController(this.args);

  final SurahArgs args;
  final QuranRepository _quran = Get.find();
  final UserRepository _user = Get.find();
  // Audio services are optional so the reading screen works without them.
  final OnlineService? _online = Get.isRegistered<OnlineService>()
      ? Get.find<OnlineService>()
      : null;
  final AudioPlayerService? _player = Get.isRegistered<AudioPlayerService>()
      ? Get.find<AudioPlayerService>()
      : null;

  /// Online audio switch; all audio controls are hidden while false.
  final audioVisible = false.obs;

  /// True when the device looks offline (only matters while [audioVisible]).
  final offline = false.obs;

  /// Ayah of this surah that is playing or paused; 0 means none.
  final playingAyah = 0.obs;

  // Ayah whose play request is in flight (shows the loading state).
  final _pendingAyah = 0.obs;
  final _subs = <StreamSubscription<Object?>>[];
  final _workers = <Worker>[];

  final state = Rx<UiState<SurahContent>>(const UiLoading());
  final bookmarked = <int>{}.obs;
  final ListController listController = ListController();
  final ScrollController scrollController = ScrollController();

  /// Ayah of this surah the user marked as last read; 0 means none.
  final lastReadAyah = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _initAudio();
    load();
  }

  void _initAudio() {
    final online = _online;
    final player = _player;
    if (online == null || player == null) return;
    audioVisible.value = online.audioEnabled;
    if (audioVisible.value) unawaited(_refreshOffline());
    _subs
      ..add(
        online.audioEnabledChanges.listen((on) {
          audioVisible.value = on;
          if (on) unawaited(_refreshOffline());
        }),
      )
      ..add(online.connectivityChanges.listen((up) => offline.value = !up));
    _workers
      ..add(ever(player.state, (_) => _syncPlaying(player)))
      ..add(ever(playingAyah, _followAyah))
      ..add(
        ever(player.lastError, (e) {
          if (e == null) return;
          notify(e);
          // Consume so a repeated identical failure is shown again, once.
          player.lastError.value = null;
        }),
      );
  }

  Future<void> _refreshOffline() async {
    final online = _online;
    if (online == null) return;
    final reachable = await online.canReach();
    if (!isClosed) offline.value = !reachable;
  }

  void _syncPlaying(AudioPlayerService player) {
    final s = player.state.value;
    playingAyah.value = switch (s) {
      PlaybackPlaying(:final surah, :final ayah) when surah == args.surah =>
        ayah,
      PlaybackPaused(:final surah, :final ayah) when surah == args.surah =>
        ayah,
      _ => 0,
    };
  }

  /// Scrolls to the playing ayah once per change, unless already visible.
  void _followAyah(int ayah) {
    if (ayah < 1 || !listController.isAttached) return;
    final range = listController.visibleRange;
    if (range != null && ayah >= range.$1 && ayah <= range.$2) return;
    listController.animateToItem(
      index: ayah,
      scrollController: scrollController,
      alignment: 0.0,
      duration: (_) => const Duration(milliseconds: 300),
      curve: (_) => Curves.easeInOut,
    );
  }

  /// Audio state of [ayah] of this surah; other surahs' playback is ignored.
  AyahAudioState audioStateOf(int ayah) {
    if (!audioVisible.value || _player == null) return AyahAudioState.hidden;
    final s = _player.state.value;
    if (s is PlaybackPlaying && s.surah == args.surah && s.ayah == ayah) {
      return AyahAudioState.playing;
    }
    if (s is PlaybackPaused && s.surah == args.surah && s.ayah == ayah) {
      return AyahAudioState.paused;
    }
    if (s is PlaybackLoading && _pendingAyah.value == ayah) {
      return AyahAudioState.loading;
    }
    return offline.value ? AyahAudioState.needsInternet : AyahAudioState.ready;
  }

  Future<void> toggleAyahAudio(int ayah) async {
    final player = _player;
    if (player == null) return;
    switch (audioStateOf(ayah)) {
      case AyahAudioState.playing:
        await player.pause();
      case AyahAudioState.paused:
        await player.resume();
      case AyahAudioState.ready:
        await _start(ayah, (total) => player.playAyah(args.surah, ayah, total));
      case AyahAudioState.hidden ||
          AyahAudioState.needsInternet ||
          AyahAudioState.loading:
        break;
    }
  }

  Future<void> playSurah() => playFromAyah(1);

  Future<void> playFromAyah(int ayah) async {
    final player = _player;
    if (player == null || audioStateOf(ayah) == AyahAudioState.hidden) return;
    if (offline.value) return;
    await _start(ayah, (total) => player.playFrom(args.surah, ayah, total));
  }

  Future<void> _start(
    int ayah,
    Future<PlayResult> Function(int total) play,
  ) async {
    final current = state.value;
    if (current is! UiData<SurahContent>) return;
    _pendingAyah.value = ayah;
    final result = await play(current.value.ayahs.length);
    _pendingAyah.value = 0;
    if (isClosed) return;
    // Not marked offline: the connectivity stream owns that flag, and a
    // server-side failure must not disable the controls for good.
    if (result == PlayResult.needsInternet) notify('Butuh internet');
  }

  @override
  void onClose() {
    final player = _player;
    if (player != null) {
      final s = player.state.value;
      final ours =
          (s is PlaybackPlaying && s.surah == args.surah) ||
          (s is PlaybackPaused && s.surah == args.surah) ||
          (s is PlaybackLoading && _pendingAyah.value > 0);
      if (ours) unawaited(player.stop());
    }
    for (final w in _workers) {
      w.dispose();
    }
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    listController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void _openAtTarget() {
    final target = args.ayah > 0 ? args.ayah : lastReadAyah.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      if (target > 0 && listController.isAttached) {
        listController.jumpToItem(
          index: target,
          scrollController: scrollController,
          alignment: 0.0,
        );
      }
    });
  }

  void load() {
    state.value = const UiLoading();
    // Deferred so the loading state is rendered before the data.
    Future.microtask(() {
      try {
        final ayahs = _quran.listAyah(args.surah);
        if (ayahs.isEmpty) {
          state.value = const UiEmpty();
          return;
        }
        final content = SurahContent(
          surah: _quran.getSurah(args.surah),
          basmalah: _quran.getAyah(const AyahRef(1, 1)).arab,
          ayahs: ayahs,
        );
        final marks = _user.bookmarkedAyahNumbers(args.surah);
        final readingPrefs = _user.getReadingPrefs();
        bookmarked.assignAll(marks);
        prefs.value = readingPrefs;
        _loadLastRead();
        state.value = UiData(content);
        _openAtTarget();
      } on Object catch (e) {
        debugPrint('QuranDetailController: load failed: $e');
        state.value = const UiError('Konten tidak dapat dibaca.');
      }
    });
  }

  void _loadLastRead() {
    try {
      final ref = _user.getLastRead()?.ref;
      if (ref != null && ref.surah == args.surah) {
        lastReadAyah.value = ref.ayah;
      }
    } on Object catch (e) {
      debugPrint('QuranDetailController: read last read failed: $e');
    }
  }

  void markLastRead(int ayahNumber) {
    try {
      _user.setLastRead(AyahRef(args.surah, ayahNumber));
      lastReadAyah.value = ayahNumber;
      notifyLastReadChanged();
    } on Object catch (e) {
      debugPrint('QuranDetailController: mark last read failed: $e');
      notify('Gagal menandai ayat');
    }
  }

  void toggleBookmark(int ayahNumber) {
    try {
      final on = _user.toggleBookmark(AyahRef(args.surah, ayahNumber));
      if (on) {
        bookmarked.add(ayahNumber);
      } else {
        bookmarked.remove(ayahNumber);
      }
    } on Object catch (e) {
      debugPrint('QuranDetailController: bookmark failed: $e');
      notify('Gagal menyimpan bookmark');
    }
  }

  Future<void> copyAyah(Ayah ayah) async {
    final current = state.value;
    if (current is! UiData<SurahContent>) return;
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${ayah.arab}\n\n${ayah.translation}\n\nQS. ${current.value.surah.nameLatin}: ${ayah.ayahNumber}',
        ),
      );
      notify('Ayat disalin');
    } on Object catch (e) {
      debugPrint('QuranDetailController: copy failed: $e');
      notify('Gagal menyalin ayat');
    }
  }

  @override
  UserRepository get userRepository => _user;
}
