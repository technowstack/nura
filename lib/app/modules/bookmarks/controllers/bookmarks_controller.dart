import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/errors.dart';
import '../../../core/ui_state.dart';
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
    try {
      final result = <BookmarkItem>[];
      for (final b in _user.listBookmarks()) {
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
      items.value = result.isEmpty ? const UiEmpty() : UiData(result);
    } on ContentUnavailable {
      items.value = const UiError('Bookmark tidak dapat dibaca.');
    }
  }
}
