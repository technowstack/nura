import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../routes/app_routes.dart';
import '../../hadith_detail/hadith_detail_args.dart';
import '../../quran_detail/surah_args.dart';
import '../controllers/bookmarks_controller.dart';
import '../controllers/bookmark_item.dart';
import '../widgets/bookmark_tile.dart';

class BookmarksTab extends GetView<BookmarksController> {
  const BookmarksTab({super.key, this.onReturn});

  /// Called after the reading screen opened from a bookmark closes.
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) => Obx(
    () => switch (controller.items.value) {
      UiLoading() => const Center(child: CircularProgressIndicator()),
      UiEmpty() => const EmptyState(
        title: 'Belum ada bookmark',
        description: 'Tandai ayat di layar baca agar mudah ditemukan lagi.',
      ),
      UiError(:final message) => ErrorState(
        title: 'Gagal memuat',
        description: message,
        onRetry: controller.load,
      ),
      UiData(:final value) => ListView.builder(
        itemCount: value.length,
        itemBuilder: (_, i) => BookmarkTile(
          item: value[i],
          onTap: () async {
            await switch (value[i]) {
              AyahBookmarkItem(:final ref) => Get.toNamed<void>(
                Routes.surah,
                arguments: SurahArgs(ref.surah, ref.ayah),
              ),
              HadithBookmarkItem(:final ref) => Get.toNamed<void>(
                Routes.hadithDetail,
                arguments: HadithDetailArgs(ref.slug, ref.number),
              ),
            };
            controller.load();
            onReturn?.call();
          },
        ),
      ),
    },
  );
}
