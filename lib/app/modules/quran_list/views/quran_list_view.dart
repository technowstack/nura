import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../routes/app_routes.dart';
import '../../bookmarks/controllers/bookmarks_controller.dart';
import '../../bookmarks/views/bookmarks_tab.dart';
import '../../quran_detail/surah_args.dart';
import '../../search/search_args.dart';
import '../controllers/quran_list_controller.dart';
import '../widgets/juz_list_item.dart';
import '../widgets/surah_list_item.dart';

class QuranListView extends GetView<QuranListController> {
  const QuranListView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: TabBar(
                  tabs: [
                    Tab(text: 'Surah'),
                    Tab(text: 'Juz'),
                    Tab(text: 'Bookmark'),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cari',
                icon: const NuraIcon(NuraIcons.search),
                onPressed: () => Get.toNamed(
                  Routes.search,
                  arguments: const SearchArgs(SearchScope.quran),
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Obx(() {
                  // Read inside Obx so marker changes rebuild the list.
                  final last = c.lastReadSurah.value;
                  final marked = c.bookmarkedSurahs.toSet();
                  return _body(
                    c.surahs.value,
                    c.load,
                    'Daftar surah belum tersedia',
                    (list) => ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final s = list[i];
                        return SurahListItem(
                          surah: s,
                          state: last == s.number
                              ? SurahItemState.lastRead
                              : marked.contains(s.number)
                              ? SurahItemState.bookmarked
                              : SurahItemState.normal,
                          onTap: () => _open(c, SurahArgs(s.number)),
                        );
                      },
                    ),
                  );
                }),
                Obx(() {
                  final names = c.surahNames; // read here to rebuild on change
                  return _body(
                    c.juz.value,
                    c.load,
                    'Daftar juz belum tersedia',
                    (list) => ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => JuzListItem(
                        juz: list[i],
                        range: QuranListController.juzRange(list[i], names),
                        onTap: () => _open(
                          c,
                          SurahArgs(list[i].startSurah, list[i].startAyah),
                        ),
                      ),
                    ),
                  );
                }),
                BookmarksTab(onReturn: c.refreshMarkers),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _open(QuranListController c, SurahArgs args) async {
    await Get.toNamed(Routes.surah, arguments: args);
    c.refreshMarkers();
    Get.find<BookmarksController>().load();
  }

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
