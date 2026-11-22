import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/errors.dart';
import '../../../core/ui_state.dart';
import '../../../data/models/ayah.dart';
import '../../../data/repositories/audio_settings_store.dart';
import '../../../data/repositories/quran_range_repository.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/online_service.dart';
import '../../quran_detail/last_read_tracker.dart';
import '../../quran_detail/reading_prefs_mixin.dart';
import '../../quran_detail/reading_settings_host.dart';
import '../../quran_list/controllers/quran_list_controller.dart';
import '../juz_args.dart';
import '../juz_item.dart';

/// Ayat of one surah inside the juz, for the tafsir sheet.
typedef TafsirTarget = ({List<Ayah> ayahs, int index, String surahName});

class JuzReaderController extends GetxController
    with WidgetsBindingObserver, ReadingPrefsMixin
    implements ReadingSettingsHost {
  JuzReaderController(
    this.args, {
    Duration lastReadDebounce = const Duration(seconds: 3),
  }) {
    _tracker = LastReadTracker(
      (ref) => _user.setLastRead(ref),
      debounce: lastReadDebounce,
    );
  }

  final JuzArgs args;
  final QuranRepository _quran = Get.find();
  final QuranRangeRepository _range = Get.find();
  final UserRepository _user = Get.find();
  // Optional so the reading screen works without them. Audio playback
  // is not wired here yet; only the settings sheet uses them.
  final OnlineService? _online = Get.isRegistered<OnlineService>()
      ? Get.find<OnlineService>()
      : null;
  final AudioSettingsStore? _audioSettings =
      Get.isRegistered<AudioSettingsStore>()
      ? Get.find<AudioSettingsStore>()
      : null;
  late final LastReadTracker _tracker;
  StreamSubscription<bool>? _audioSub;

  final state = Rx<UiState<List<JuzItem>>>(const UiLoading());

  /// 'Al-Fatihah 1 – Al-Baqarah 141'; empty until loaded.
  final rangeText = ''.obs;

  /// Bookmarks of the surahs in this juz, keyed by (surah, ayah).
  final bookmarked = <AyahRef>{}.obs;

  /// Last-read ayah as stored at load; null when none or outside this juz.
  final lastRead = Rxn<AyahRef>();

  @override
  final audioVisible = false.obs;
  @override
  final qariId = ''.obs;

  final ListController listController = ListController();
  final ScrollController scrollController = ScrollController();

  String _basmalah = '';
  int _loadId = 0;

  @override
  UserRepository get userRepository => _user;

  @override
  String? get previewText => _basmalah.isEmpty ? null : _basmalah;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    listController.addListener(_onVisibleRange);
    qariId.value = _audioSettings?.qariId ?? '';
    final online = _online;
    if (online != null) {
      audioVisible.value = online.audioEnabled;
      _audioSub = online.audioEnabledChanges.listen(
        (on) => audioVisible.value = on,
      );
    }
    load();
  }

  @override
  void onClose() {
    unawaited(_audioSub?.cancel());
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

  void flushLastRead() => _tracker.flush();

  // A header stands for the first ayah that follows it, like the surah
  // screen where the header counts as ayah 1.
  void _onVisibleRange() =>
      _tracker.onVisibleRange(listController, scrollController, ayahRefAt);

  /// Ayah a visible item index stands for (null: none after it).
  AyahRef? ayahRefAt(int index) {
    final s = state.value;
    if (s is! UiData<List<JuzItem>>) return null;
    final items = s.value;
    for (var i = index < 0 ? 0 : index; i < items.length; i++) {
      final item = items[i];
      if (item is AyahItem) {
        return AyahRef(item.ayah.surahNumber, item.ayah.ayahNumber);
      }
    }
    return null;
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
    try {
      final ref = _user.getLastRead()?.ref;
      if (ref == null) return;
      _tracker.markSaved(ref);
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

  @override
  void setAudioEnabled(bool on) => _online?.setAudioEnabled(on);

  @override
  void setQari(String id) {
    final store = _audioSettings;
    if (store == null) return;
    try {
      store.setQariId(id);
    } on Object catch (e) {
      debugPrint('JuzReaderController: save qari failed: $e');
      notify('Gagal menyimpan pengaturan');
      return;
    }
    qariId.value = id;
  }
}
