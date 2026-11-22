import 'package:flutter/foundation.dart';
import '../../../core/hadith_reference.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/repositories/hadith_repository.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
import 'bookmark_item.dart';

class BookmarksController extends GetxController {
  final QuranRepository _quran = Get.find();
  final UserRepository _user = Get.find();
  final HadithRepository _hadith = Get.find();

  final items = Rx<UiState<List<BookmarkItem>>>(const UiLoading());

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Bumped by load(); a read from an older generation changes no state.
  int _gen = 0;

  @override
  void onClose() {
    _gen++;
    super.onClose();
  }

  void load() {
    _gen++;
    // Keep showing the current list while reloading after returning.
    if (items.value is! UiData) items.value = const UiLoading();
    // Deferred so the loading state is rendered before the data.
    final gen = _gen;
    Future.microtask(() => _read(gen));
  }

  bool _stale(int gen) => gen != _gen || isClosed;

  Future<void> _read(int gen) async {
    if (_stale(gen)) return;
    final List<Bookmark> ayat;
    final List<HadithBookmark> hadith;
    try {
      ayat = _user.listBookmarks();
      hadith = _user.listHadithBookmarks();
    } on Object catch (e) {
      // Any storage failure must reach the UI as an error, never escape.
      debugPrint('BookmarksController: cannot read bookmarks: $e');
      items.value = const UiError('Bookmark tidak dapat dibaca.');
      return;
    }
    final result = <BookmarkItem>[];
    for (final b in ayat) {
      try {
        final surah = _quran.getSurah(b.ref.surah);
        final ayah = _quran.getAyah(b.ref);
        result.add(
          AyahBookmarkItem(
            ref: b.ref,
            title: '${surah.nameLatin} · ayat ${ayah.ayahNumber}',
            body: ayah.translation,
            createdAt: b.createdAt,
          ),
        );
      } on Object catch (e) {
        debugPrint(
          'BookmarksController: skipped ${b.ref.surah}:${b.ref.ayah}: $e',
        );
      }
    }
    for (final b in hadith) {
      if (_stale(gen)) return;
      try {
        final h = await _hadith.getHadith(b.ref);
        if (_stale(gen)) return;
        result.add(
          HadithBookmarkItem(
            ref: b.ref,
            title: hadithReference(b.ref.slug, b.ref.number),
            body: h.translation,
            createdAt: b.createdAt,
          ),
        );
      } on Object catch (e) {
        debugPrint(
          'BookmarksController: skipped ${b.ref.slug}:${b.ref.number}: $e',
        );
      }
    }
    if (_stale(gen)) return;
    // List.sort is not stable: tie-break on the source index (ayat first).
    final order = {for (var i = 0; i < result.length; i++) result[i]: i};
    result.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      // Every item is a key: order was built from result.
      return byTime != 0 ? byTime : order[a]!.compareTo(order[b]!);
    });
    // Every entry failing points at a broken content.db, not an empty list.
    items.value = ayat.isEmpty && hadith.isEmpty
        ? const UiEmpty()
        : result.isEmpty
        ? const UiError('Konten tidak dapat dibaca.')
        : UiData(result);
  }
}
