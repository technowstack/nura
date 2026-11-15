import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../routes/app_routes.dart';
import '../../hadith_detail/hadith_detail_args.dart';
import '../controllers/hadith_list_controller.dart';
import '../widgets/hadith_list_tile.dart';

class HadithListView extends GetView<HadithListController> {
  const HadithListView({super.key});

  Future<void> _open(HadithListItem item) async {
    await Get.toNamed(
      Routes.hadithDetail,
      arguments: HadithDetailArgs(item.ref.slug, item.ref.number),
    );
    controller.refreshMarkers();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(controller.args.bookName)),
    body: Obx(() {
      final hasMore = controller.hasMore.value;
      final loadingMore = controller.loadingMore.value;
      final failed = controller.loadMoreFailed.value;
      final footer = hasMore || loadingMore || failed ? 1 : 0;
      return switch (controller.items.value) {
        UiLoading() => const Center(child: CircularProgressIndicator()),
        UiEmpty() => const EmptyState(title: 'Belum ada hadis'),
        UiError(:final message) => ErrorState(
          title: 'Gagal memuat',
          description: message,
          onRetry: controller.load,
        ),
        UiData(:final value) => ListView.builder(
          controller: controller.scroll,
          itemCount: value.length + footer,
          itemBuilder: (_, i) {
            if (i < value.length) {
              return HadithListTile(
                item: value[i],
                onTap: () => _open(value[i]),
              );
            }
            if (failed) {
              return ListTile(
                minTileHeight: 56,
                onTap: controller.loadMore,
                title: const Text('Gagal memuat, ketuk untuk mencoba lagi'),
              );
            }
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      };
    }),
  );
}
