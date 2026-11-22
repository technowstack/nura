import 'package:flutter/services.dart';
import '../../../core/hadith_reference.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../content_pipeline/content_schema.dart';
import '../../../core/ui_state.dart';
import '../../../data/models/hadith.dart';
import '../../../data/models/reading_prefs.dart';
import '../../../data/repositories/hadith_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../hadith_detail_args.dart';
import '../hadith_detail_content.dart';

class HadithDetailController extends GetxController {
  HadithDetailController(this.args) : _ref = HadithRef(args.slug, args.number);

  final HadithDetailArgs args;
  final HadithRepository _hadith = Get.find();
  final UserRepository _user = Get.find();

  final state = Rx<UiState<HadithDetailContent>>(const UiLoading());
  final bookmarked = false.obs;
  // Defaults until load() reads the stored prefs; never touch user.db in build.
  final prefs = Rx<ReadingPrefs>(
    const ReadingPrefs(arabicFontSize: 28, showTranslation: true),
  );
  final hasPrevious = false.obs;
  final hasNext = false.obs;

  HadithRef _ref;
  HadithRef? _prev;
  HadithRef? _next;

  /// Bumped by every open; results from an older generation change nothing.
  int _gen = 0;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// (Re)loads the hadith currently shown; also the error-state retry.
  void load() {
    final gen = ++_gen;
    state.value = const UiLoading();
    // Deferred so the loading state is rendered before the data.
    Future.microtask(() => _open(_ref, gen, readPrefs: true));
  }

  Future<void> goTo({required bool next}) async {
    final target = next ? _next : _prev;
    if (target == null || state.value is! UiData<HadithDetailContent>) return;
    await _open(target, ++_gen);
  }

  Future<void> _open(HadithRef ref, int gen, {bool readPrefs = false}) async {
    if (gen != _gen || isClosed) return;
    if (ref.slug.isEmpty) {
      state.value = const UiError('Hadis tidak ditemukan.');
      return;
    }
    try {
      final h = await _hadith.getHadith(ref);
      if (gen != _gen || isClosed) return;
      final (prev, next) = await _neighbors(ref);
      final count = await _bookCount(ref.slug);
      if (gen != _gen || isClosed) return;
      if (readPrefs) _readPrefs();
      _ref = ref;
      _prev = prev;
      _next = next;
      hasPrevious.value = prev != null;
      hasNext.value = next != null;
      bookmarked.value = _readBookmark(ref);
      state.value = UiData(_content(h, count));
    } on Object catch (e) {
      if (gen != _gen || isClosed) return;
      debugPrint('HadithDetailController: load failed: $e');
      _ref = ref; // retry targets the hadith the user asked for
      state.value = const UiError('Konten tidak dapat dibaca.');
    }
  }

  /// Any failure leaves both null: navigation is optional, reading is not.
  Future<(HadithRef?, HadithRef?)> _neighbors(HadithRef ref) async {
    try {
      final prev = await _hadith.neighbor(ref, next: false);
      final next = await _hadith.neighbor(ref, next: true);
      return (prev, next);
    } on Object catch (e) {
      debugPrint('HadithDetailController: neighbors unavailable: $e');
      return (null, null);
    }
  }

  void _readPrefs() {
    try {
      prefs.value = _user.getReadingPrefs();
    } on Object catch (e) {
      debugPrint('HadithDetailController: prefs unavailable: $e');
    }
  }

  bool _readBookmark(HadithRef ref) {
    try {
      return _user.bookmarkedHadithNumbers(ref.slug).contains(ref.number);
    } on Object catch (e) {
      debugPrint('HadithDetailController: bookmark unavailable: $e');
      return false;
    }
  }

  final _counts = <String, int>{};

  /// Optional hero info: a failure shows 0 rather than blocking reading.
  Future<int> _bookCount(String slug) async {
    final cached = _counts[slug];
    if (cached != null) return cached;
    try {
      for (final b in await _hadith.listBooks()) {
        _counts[b.slug] = b.hadithCount;
      }
    } on Object catch (e) {
      debugPrint('HadithDetailController: book count unavailable: $e');
    }
    return _counts[slug] ?? 0;
  }

  HadithDetailContent _content(Hadith h, int count) => HadithDetailContent(
    ref: h.ref,
    title: h.bookName,
    subtitle: 'No. ${h.ref.number}',
    arab: h.arab,
    translation: h.translation,
    showTruncationNote: h.arabTruncated || h.translationTruncated,
    referenceLabel: hadithReference(h.ref.slug, h.ref.number),
    hadithCount: count,
    nameArab: hadithBookNameArab(h.ref.slug),
  );

  void toggleBookmark() {
    if (state.value is! UiData<HadithDetailContent>) return;
    try {
      bookmarked.value = _user.toggleHadithBookmark(_ref);
    } on Object catch (e) {
      debugPrint('HadithDetailController: bookmark failed: $e');
      _notify('Gagal menyimpan bookmark');
    }
  }

  Future<void> copy() async {
    final s = state.value;
    if (s is! UiData<HadithDetailContent>) return;
    final c = s.value;
    try {
      await Clipboard.setData(
        ClipboardData(
          text: '${c.arab}\n\n${c.translation}\n\n${c.referenceLabel}',
        ),
      );
      _notify('Hadis disalin');
    } on Object catch (e) {
      debugPrint('HadithDetailController: copy failed: $e');
      _notify('Gagal menyalin hadis');
    }
  }

  void _notify(String message) => Get.showSnackbar(
    GetSnackBar(message: message, duration: const Duration(seconds: 2)),
  );
}
