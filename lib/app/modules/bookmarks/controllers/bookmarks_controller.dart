import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/errors.dart';
import '../../../core/ui_state.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
import 'bookmark_item.dart';

class BookmarksController extends GetxController {
  final QuranRepository _quran = Get.find();
  final UserRepository _user = Get.find();

  final items = Rx<UiState<List<BookmarkItem>>>(const UiLoading());

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void load() {
    // Keep showing the current list while reloading after returning.
    if (items.value is! UiData) items.value = const UiLoading();
    // Deferred so the loading state is rendered before the data.
    Future.microtask(_read);
  }

  void _read() {
    final List<Bookmark> all;
    try {
      all = _user.listBookmarks();
    } catch (e) {
      // Any storage failure must reach the UI as an error, never escape.
      debugPrint('BookmarksController: cannot read bookmarks: $e');
      items.value = const UiError('Bookmark tidak dapat dibaca.');
      return;
    }
    final result = <BookmarkItem>[];
    for (final b in all) {
      try {
        result.add(
          BookmarkItem(
            bookmark: b,
            surah: _quran.getSurah(b.ref.surah),
            ayah: _quran.getAyah(b.ref),
          ),
        );
      } on ContentUnavailable catch (e) {
        debugPrint(
          'BookmarksController: skipped ${b.ref.surah}:${b.ref.ayah}: $e',
        );
      }
    }
    // Every entry failing points at a broken content.db, not an empty list.
    items.value = all.isEmpty
        ? const UiEmpty()
        : result.isEmpty
        ? const UiError('Konten tidak dapat dibaca.')
        : UiData(result);
  }
}
