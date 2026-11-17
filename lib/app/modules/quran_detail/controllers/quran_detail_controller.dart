import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/ui_state.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/reading_prefs.dart';
import '../../../data/models/surah.dart';
import '../../../data/repositories/audio_settings_store.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/online_service.dart';
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

class QuranDetailController extends GetxController with WidgetsBindingObserver {
  QuranDetailController(
    this.args, {
    this.lastReadDebounce = const Duration(seconds: 3),
  });

  final Duration lastReadDebounce;

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
  final AudioSettingsStore? _audioSettings =
      Get.isRegistered<AudioSettingsStore>()
      ? Get.find<AudioSettingsStore>()
      : null;

  /// Online audio switch; all audio controls are hidden while false.
  final audioVisible = false.obs;

  /// True when the device looks offline (only matters while [audioVisible]).
  final offline = false.obs;

  /// Ayah of this surah that is playing or paused; 0 means none.
  final playingAyah = 0.obs;

  /// Selected qari id (empty when no settings store is available).
  final qariId = ''.obs;

  // Ayah whose play request is in flight (shows the loading state).
  final _pendingAyah = 0.obs;
  final _subs = <StreamSubscription<Object?>>[];
  final _workers = <Worker>[];

  final state = Rx<UiState<SurahContent>>(const UiLoading());
  final bookmarked = <int>{}.obs;
  // Defaults until load() reads the stored prefs; never touch user.db in build.
  final prefs = Rx<ReadingPrefs>(
    const ReadingPrefs(arabicFontSize: 28, showTranslation: true),
  );
  final ListController listController = ListController();
  final ScrollController scrollController = ScrollController();

  /// Last-read ayah within this surah as stored at load; 0 means none.
  /// Not updated while reading, so the highlight does not follow the user.
  final lastReadAyah = 0.obs;

  Timer? _timer;
  int _pending = 0;
  int _saved = 0;
  // Ignore list reports until the user scrolls, so merely opening a
  // surah never overwrites the stored last read.
  bool _tracking = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    listController.addListener(_onVisibleRange);
    _initAudio();
    load();
  }

  void _initAudio() {
    final online = _online;
    final player = _player;
    qariId.value = _audioSettings?.qariId ?? '';
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
          _notify(e);
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

  Future<void> stopAudio() async => _player?.stop();

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
    if (result == PlayResult.needsInternet) _notify('Butuh internet');
  }

  void setAudioEnabled(bool on) => _online?.setAudioEnabled(on);

  void setQari(String id) {
    final store = _audioSettings;
    if (store == null) return;
    try {
      store.setQariId(id);
    } on Object catch (e) {
      debugPrint('QuranDetailController: save qari failed: $e');
      _notify('Gagal menyimpan pengaturan');
      return;
    }
    qariId.value = id;
    _player?.onQariChanged();
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
    flushLastRead();
    WidgetsBinding.instance.removeObserver(this);
    listController.removeListener(_onVisibleRange);
    listController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) flushLastRead();
  }

  void _onVisibleRange() {
    final range = listController.visibleRange;
    // Layout notices also fire without user input (item measuring); only
    // start tracking once the user scrolls. jumpTo leaves it idle.
    if (!_tracking &&
        scrollController.hasClients &&
        scrollController.position.userScrollDirection != ScrollDirection.idle) {
      _tracking = true;
    }
    if (!_tracking || range == null) return;
    // Index 0 is the surah header and counts as ayah 1.
    final ayah = range.$1 < 1 ? 1 : range.$1;
    // Relayouts re-notify with the same range; don't restart the debounce.
    if (ayah != _pending) onVisibleAyahChanged(ayah);
  }

  void onVisibleAyahChanged(int ayahNumber) {
    _pending = ayahNumber;
    _timer?.cancel();
    _timer = Timer(lastReadDebounce, flushLastRead);
  }

  void flushLastRead() {
    _timer?.cancel();
    _timer = null;
    if (_pending == 0 || _pending == _saved) return;
    try {
      _user.setLastRead(AyahRef(args.surah, _pending));
      _saved = _pending;
    } on Object catch (e) {
      debugPrint('QuranDetailController: save last read failed: $e');
    }
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
        _saved = ref.ayah;
      }
    } on Object catch (e) {
      debugPrint('QuranDetailController: read last read failed: $e');
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
      _notify('Gagal menyimpan bookmark');
    }
  }

  void setArabicFontSize(double size) {
    final p = prefs.value;
    _savePrefs(
      () => _user.setArabicFontSize(size),
      ReadingPrefs(arabicFontSize: size, showTranslation: p.showTranslation),
    );
  }

  void setShowTranslation(bool show) {
    final p = prefs.value;
    _savePrefs(
      () => _user.setShowTranslation(show),
      ReadingPrefs(arabicFontSize: p.arabicFontSize, showTranslation: show),
    );
  }

  /// Persists first; the UI only changes when storage succeeded.
  void _savePrefs(void Function() save, ReadingPrefs next) {
    try {
      save();
    } on Object catch (e) {
      debugPrint('QuranDetailController: save prefs failed: $e');
      _notify('Gagal menyimpan pengaturan');
      return;
    }
    prefs.value = next;
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
      _notify('Ayat disalin');
    } on Object catch (e) {
      debugPrint('QuranDetailController: copy failed: $e');
      _notify('Gagal menyalin ayat');
    }
  }

  void _notify(String message) => Get.showSnackbar(
    GetSnackBar(message: message, duration: const Duration(seconds: 2)),
  );
}
