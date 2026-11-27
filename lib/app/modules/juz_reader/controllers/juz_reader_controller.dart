import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/errors.dart';
import '../../../core/ui_state.dart';
import '../../../data/models/ayah.dart';
import '../../../data/repositories/quran_range_repository.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/online_service.dart';
import '../../quran_detail/controllers/quran_detail_controller.dart'
    show AyahAudioState;
import '../../quran_detail/notify_last_read_changed.dart';
import '../../quran_detail/reading_prefs_mixin.dart';
import '../../quran_list/controllers/quran_list_controller.dart';
import '../juz_args.dart';
import '../juz_item.dart';

/// Ayat of one surah inside the juz, for the tafsir sheet.
typedef TafsirTarget = ({List<Ayah> ayahs, int index, String surahName});

class JuzReaderController extends GetxController with ReadingPrefsMixin {
  JuzReaderController(this.args);

  final JuzArgs args;
  final QuranRepository _quran = Get.find();
  final QuranRangeRepository _range = Get.find();
  final UserRepository _user = Get.find();
  // Optional so the reading screen works without them.
  final OnlineService? _online = Get.isRegistered<OnlineService>()
      ? Get.find<OnlineService>()
      : null;
  final AudioPlayerService? _player = Get.isRegistered<AudioPlayerService>()
      ? Get.find<AudioPlayerService>()
      : null;
  final _subs = <StreamSubscription<Object?>>[];
  final _workers = <Worker>[];

  final state = Rx<UiState<List<JuzItem>>>(const UiLoading());

  /// 'Al-Fatihah 1 – Al-Baqarah 141'; empty until loaded.
  final rangeText = ''.obs;

  /// Bookmarks of the surahs in this juz, keyed by (surah, ayah).
  final bookmarked = <AyahRef>{}.obs;

  /// Ayah marked as last read; null when none or outside this juz.
  final lastRead = Rxn<AyahRef>();

  /// True when the device looks offline (only matters while [audioVisible]).
  final offline = false.obs;

  /// Ayah playing or paused within this juz; null means none.
  final playingRef = Rxn<AyahRef>();
  final _pendingRef = Rxn<AyahRef>();
  int _startToken = 0;

  /// Player state, read by the view so audio changes rebuild it.
  PlaybackState? get playerState => _player?.state.value;

  final audioVisible = false.obs;

  final ListController listController = ListController();
  final ScrollController scrollController = ScrollController();

  String _basmalah = '';
  // Playable ayat of the juz in order, their list index and surah totals.
  var _refs = const <AyahRef>[];
  var _indexOf = const <AyahRef, int>{};
  var _totals = const <int, int>{};
  int _loadId = 0;

  @override
  UserRepository get userRepository => _user;

  String? get basmalah => _basmalah.isEmpty ? null : _basmalah;

  @override
  void onInit() {
    super.onInit();
    _initAudio();
    load();
  }

  @override
  void onClose() {
    final player = _player;
    final playing = playingRef.value;
    if (player != null &&
        ((playing != null && _indexOf.containsKey(playing)) ||
            (player.state.value is PlaybackLoading &&
                _pendingRef.value != null))) {
      unawaited(player.stop());
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

  Future<void> load() async {
    final id = ++_loadId;
    state.value = const UiLoading();
    try {
      final juz = _quran.listJuz().firstWhere(
        (j) => j.number == args.number,
        orElse: () => throw ContentUnavailable('juz ${args.number}'),
      );
      final surahs = {for (final s in _quran.listSurah()) s.number: s};
      _basmalah = _quran.getAyah(const AyahRef(1, 1)).arab;
      final ayahs = await _range.getAyahRange(juz.start, juz.end);
      if (isClosed || id != _loadId) return;
      if (ayahs.isEmpty) {
        state.value = const UiEmpty();
        return;
      }
      final items = <JuzItem>[];
      var current = 0;
      for (final a in ayahs) {
        if (a.surahNumber != current) {
          current = a.surahNumber;
          final surah = surahs[current];
          if (surah == null) throw ContentUnavailable('surah $current');
          items.add(
            SurahHeaderItem(
              surah,
              withBasmalah: a.ayahNumber == 1 && current != 1 && current != 9,
            ),
          );
        }
        items.add(AyahItem(a));
      }
      _refs = [
        for (final i in items)
          if (i is AyahItem) AyahRef(i.ayah.surahNumber, i.ayah.ayahNumber),
      ];
      _indexOf = {
        for (var i = 0; i < items.length; i++)
          if (items[i] case AyahItem(:final ayah))
            AyahRef(ayah.surahNumber, ayah.ayahNumber): i,
      };
      _totals = {for (final s in surahs.values) s.number: s.ayahCount};
      rangeText.value = QuranListController.juzRange(juz, {
        for (final s in surahs.values) s.number: s.nameLatin,
      });
      prefs.value = _user.getReadingPrefs();
      refreshBookmarks(items);
      _loadLastRead(items);
      state.value = UiData(items);
      _openAtLastRead(items);
    } on Object catch (e) {
      debugPrint('JuzReaderController: load failed: $e');
      if (!isClosed && id == _loadId) {
        state.value = const UiError('Konten tidak dapat dibaca.');
      }
    }
  }

  /// Re-reads bookmarks of the surahs in the juz (e.g. after the tafsir sheet).
  void refreshBookmarks([List<JuzItem>? from]) {
    final s = state.value;
    final items = from ?? (s is UiData<List<JuzItem>> ? s.value : null);
    if (items == null) return;
    try {
      final marks = <AyahRef>{};
      for (final surah in {
        for (final i in items)
          if (i is SurahHeaderItem) i.surah.number,
      }) {
        for (final n in _user.bookmarkedAyahNumbers(surah)) {
          marks.add(AyahRef(surah, n));
        }
      }
      bookmarked.assignAll(marks);
    } on Object catch (e) {
      debugPrint('JuzReaderController: read bookmarks failed: $e');
    }
  }

  void _loadLastRead(List<JuzItem> items) {
    lastRead.value = null; // a reload must not keep a stale highlight
    try {
      final ref = _user.getLastRead()?.ref;
      if (ref == null) return;
      final inJuz = items.any(
        (i) =>
            i is AyahItem &&
            i.ayah.surahNumber == ref.surah &&
            i.ayah.ayahNumber == ref.ayah,
      );
      if (inJuz) lastRead.value = ref;
    } on Object catch (e) {
      debugPrint('JuzReaderController: read last read failed: $e');
    }
  }

  void _openAtLastRead(List<JuzItem> items) {
    final ref = lastRead.value;
    if (ref == null) return;
    final index = items.indexWhere(
      (i) =>
          i is AyahItem &&
          i.ayah.surahNumber == ref.surah &&
          i.ayah.ayahNumber == ref.ayah,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || !listController.isAttached) return;
      listController.jumpToItem(
        index: index,
        scrollController: scrollController,
        alignment: 0.0,
      );
    });
  }

  void markLastRead(AyahRef ref) {
    try {
      _user.setLastRead(ref);
      lastRead.value = ref;
      notifyLastReadChanged();
    } on Object catch (e) {
      debugPrint('JuzReaderController: mark last read failed: $e');
      notify('Gagal menandai ayat');
    }
  }

  void toggleBookmark(Ayah ayah) {
    final ref = AyahRef(ayah.surahNumber, ayah.ayahNumber);
    try {
      if (_user.toggleBookmark(ref)) {
        bookmarked.add(ref);
      } else {
        bookmarked.remove(ref);
      }
    } on Object catch (e) {
      debugPrint('JuzReaderController: bookmark failed: $e');
      notify('Gagal menyimpan bookmark');
    }
  }

  /// The ayat of [ayah]'s surah within the juz, for paging in the tafsir sheet.
  TafsirTarget? tafsirFor(Ayah ayah) {
    final s = state.value;
    if (s is! UiData<List<JuzItem>>) return null;
    final list = [
      for (final i in s.value)
        if (i is AyahItem && i.ayah.surahNumber == ayah.surahNumber) i.ayah,
    ];
    final name = s.value
        .whereType<SurahHeaderItem>()
        .firstWhere((h) => h.surah.number == ayah.surahNumber)
        .surah
        .nameLatin;
    return (
      ayahs: list,
      index: list.indexWhere((a) => a.ayahNumber == ayah.ayahNumber),
      surahName: name,
    );
  }

  Future<void> copyAyah(Ayah ayah) async {
    final target = tafsirFor(ayah);
    if (target == null) return;
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${ayah.arab}\n\n${ayah.translation}\n\nQS. ${target.surahName}: ${ayah.ayahNumber}',
        ),
      );
      notify('Ayat disalin');
    } on Object catch (e) {
      debugPrint('JuzReaderController: copy failed: $e');
      notify('Gagal menyalin ayat');
    }
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
      ..add(ever(playingRef, _followAyah))
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
    final ref = switch (player.state.value) {
      PlaybackPlaying(:final surah, :final ayah) => AyahRef(surah, ayah),
      PlaybackPaused(:final surah, :final ayah) => AyahRef(surah, ayah),
      _ => null,
    };
    playingRef.value = ref != null && _indexOf.containsKey(ref) ? ref : null;
  }

  /// Scrolls to the playing ayah once per change, unless already visible.
  void _followAyah(AyahRef? ref) {
    final index = ref == null ? null : _indexOf[ref];
    if (index == null || !listController.isAttached) return;
    final range = listController.visibleRange;
    if (range != null && index >= range.$1 && index <= range.$2) return;
    listController.animateToItem(
      index: index,
      scrollController: scrollController,
      alignment: 0.0,
      duration: (_) => const Duration(milliseconds: 300),
      curve: (_) => Curves.easeInOut,
    );
  }

  /// Audio state of [ref]; other playback (other surahs/screens) is ignored.
  AyahAudioState audioStateOf(AyahRef ref) {
    final player = _player;
    if (!audioVisible.value || player == null) return AyahAudioState.hidden;
    final s = player.state.value;
    if (s is PlaybackPlaying && AyahRef(s.surah, s.ayah) == ref) {
      return AyahAudioState.playing;
    }
    if (s is PlaybackPaused && AyahRef(s.surah, s.ayah) == ref) {
      return AyahAudioState.paused;
    }
    if (s is PlaybackLoading && _pendingRef.value == ref) {
      return AyahAudioState.loading;
    }
    return offline.value ? AyahAudioState.needsInternet : AyahAudioState.ready;
  }

  Future<void> toggleAyahAudio(AyahRef ref) async {
    final player = _player;
    if (player == null) return;
    switch (audioStateOf(ref)) {
      case AyahAudioState.playing:
        await player.pause();
      case AyahAudioState.paused:
        await player.resume();
      case AyahAudioState.ready:
        await _start(
          ref,
          () => player.playAyah(ref.surah, ref.ayah, _totals[ref.surah] ?? 0),
        );
      case AyahAudioState.hidden ||
          AyahAudioState.needsInternet ||
          AyahAudioState.loading:
        break;
    }
  }

  /// Plays from the first ayah of the juz to its last.
  Future<void> playJuz() async {
    if (_refs.isNotEmpty) await playFromAyah(_refs.first);
  }

  /// Plays from [ref] to the last ayah of the juz.
  Future<void> playFromAyah(AyahRef ref) async {
    final player = _player;
    final at = _refs.indexOf(ref);
    if (player == null || at < 0) return;
    if (audioStateOf(ref) == AyahAudioState.hidden || offline.value) return;
    await _start(ref, () => player.playRange(_refs.sublist(at), _totals));
  }

  Future<void> _start(AyahRef ref, Future<PlayResult> Function() play) async {
    final token = ++_startToken;
    _pendingRef.value = ref;
    final result = await play();
    if (token == _startToken) _pendingRef.value = null;
    if (isClosed) return;
    // Not marked offline: the connectivity stream owns that flag.
    if (result == PlayResult.needsInternet) notify('Butuh internet');
  }
}
