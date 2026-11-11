import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../routes/app_routes.dart';
import '../../quran_detail/surah_args.dart';
import '../controllers/quran_list_controller.dart';
import '../widgets/juz_list_item.dart';
import '../widgets/surah_list_item.dart';

class QuranListView extends StatelessWidget {
  const QuranListView({super.key});

  @override
  Widget build(BuildContext context) => GetBuilder<QuranListController>(
    init: QuranListController(),
    builder: (c) => DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Surah'),
              Tab(text: 'Juz'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Obx(
                  () => _body(
                    c.surahs.value,
                    c.load,
                    'Daftar surah belum tersedia',
                    (list) => ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final s = list[i];
                        return SurahListItem(
                          surah: s,
                          state: c.lastReadSurah.value == s.number
                              ? SurahItemState.lastRead
                              : c.bookmarkedSurahs.contains(s.number)
                              ? SurahItemState.bookmarked
                              : SurahItemState.normal,
                          onTap: () => Get.toNamed(
                            Routes.surah,
                            arguments: SurahArgs(s.number),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Obx(
                  () => _body(
                    c.juz.value,
                    c.load,
                    'Daftar juz belum tersedia',
                    (list) => ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => JuzListItem(
                        juz: list[i],
                        onTap: () => Get.toNamed(
                          Routes.surah,
                          arguments: SurahArgs(
                            list[i].startSurah,
                            list[i].startAyah,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _body<T>(
    UiState<List<T>> state,
    VoidCallback retry,
    String emptyTitle,
    Widget Function(List<T>) list,
  ) => switch (state) {
    UiLoading() => const Center(child: CircularProgressIndicator()),
    UiEmpty() => EmptyState(title: emptyTitle),
    UiError(:final message) => ErrorState(
      title: 'Gagal memuat',
      description: message,
      onRetry: retry,
    ),
    UiData(:final value) => list(value),
  };
}
