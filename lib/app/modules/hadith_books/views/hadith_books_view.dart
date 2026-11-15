import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../routes/app_routes.dart';
import '../../hadith_list/hadith_list_args.dart';
import '../../search/search_args.dart';
import '../controllers/hadith_books_controller.dart';
import '../widgets/hadith_book_tile.dart';

class HadithBooksView extends GetView<HadithBooksController> {
  const HadithBooksView({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // The tab has no AppBar: a single right-aligned action row.
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: IconButton(
          tooltip: 'Cari',
          icon: const Icon(Icons.search),
          onPressed: () => Get.toNamed(
            Routes.search,
            arguments: const SearchArgs(SearchScope.hadith),
          ),
        ),
      ),
      Expanded(
        child: Obx(
          () => switch (controller.books.value) {
            UiLoading() => const Center(child: CircularProgressIndicator()),
            UiEmpty() => const EmptyState(title: 'Daftar kitab belum tersedia'),
            UiError(:final message) => ErrorState(
              title: 'Gagal memuat',
              description: message,
              onRetry: controller.load,
            ),
            UiData(:final value) => ListView.builder(
              itemCount: value.length,
              itemBuilder: (_, i) => HadithBookTile(
                item: value[i],
                onTap: () => Get.toNamed(
                  Routes.hadithList,
                  arguments: HadithListArgs(
                    value[i].book.slug,
                    value[i].book.name,
                  ),
                ),
              ),
            ),
          },
        ),
      ),
    ],
  );
}
