import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../routes/app_routes.dart';
import '../../quran_detail/surah_args.dart';
import '../controllers/bookmarks_controller.dart';
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
            final ref = value[i].bookmark.ref;
            await Get.toNamed(
              Routes.surah,
              arguments: SurahArgs(ref.surah, ref.ayah),
            );
            controller.load();
            onReturn?.call();
          },
        ),
      ),
    },
  );
}
