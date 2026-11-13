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
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
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

class QuranDetailController extends GetxController with WidgetsBindingObserver {
  QuranDetailController(
    this.args, {
    this.lastReadDebounce = const Duration(seconds: 3),
  });

  final Duration lastReadDebounce;

  final SurahArgs args;
  final QuranRepository _quran = Get.find();
  final UserRepository _user = Get.find();

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
    load();
  }

  @override
  void onClose() {
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
