import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/models/search_hit.dart';
import '../../../routes/app_routes.dart';
import '../../hadith_detail/hadith_detail_args.dart';
import '../../quran_detail/surah_args.dart';
import '../controllers/search_results_controller.dart';
import '../search_args.dart';
import '../widgets/search_result_tile.dart';

class SearchView extends GetView<SearchResultsController> {
  const SearchView({super.key});

  void _open(SearchHit hit) => switch (hit) {
    AyahSearchHit h => Get.toNamed(
      Routes.surah,
      arguments: SurahArgs(h.surahNumber, h.ayahNumber),
    ),
    HadithSearchHit h => Get.toNamed(
      Routes.hadithDetail,
      arguments: HadithDetailArgs(h.ref.slug, h.ref.number),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Cari')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NuraSpace.s16,
              NuraSpace.s8,
              NuraSpace.s16,
              0,
            ),
            child: _SearchField(onChanged: c.onQueryChanged),
          ),
          Obx(() => _filters(c.scope.value, c.bookSlug.value)),
          Expanded(child: Obx(_results)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: NuraSpace.s8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );

  Widget _filters(SearchScope scope, String? book) {
    final c = controller;
    Widget row(List<Widget> chips) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: NuraSpace.s16),
      child: Row(children: chips),
    );
    return Column(
      children: [
        row([
          _chip(
            "Al-Qur'an",
            scope == SearchScope.quran,
            () => c.setScope(SearchScope.quran),
          ),
          _chip(
            'Hadis',
            scope == SearchScope.hadith,
            () => c.setScope(SearchScope.hadith),
          ),
        ]),
        // UI sementara: the hadith book filter is not designed yet.
        if (scope == SearchScope.hadith)
          row([
            _chip('Semua kitab', book == null, () => c.setBook(null)),
            for (final MapEntry(:key, :value)
                in SearchResultsController.books.entries)
              _chip(value, book == key, () => c.setBook(key)),
          ]),
      ],
    );
  }

  Widget _results() {
    final c = controller;
    final hint = c.hint.value;
    final state = c.state.value;
    final hasMore = c.hasMore.value;
    final loadingMore = c.loadingMore.value;
    final failed = c.moreError.value;
    if (hint != null) return EmptyState(title: hint);
    return switch (state) {
      UiLoading() => const Center(child: CircularProgressIndicator()),
      UiEmpty() => const EmptyState(title: SearchResultsController.emptyText),
      UiError(:final message) => ErrorState(
        title: 'Gagal memuat',
        description: message,
        onRetry: c.retry,
      ),
      UiData(:final value) => _list(value, hasMore || loadingMore, failed),
    };
  }

  Widget _list(List<SearchSection> sections, bool more, bool failed) {
    final rows = <_Row>[
      for (final s in sections) ...[
        _HeaderRow(s.title),
        for (final item in s.items) _ItemRow(item),
      ],
    ];
    final footer = more || failed ? 1 : 0;
    return NotificationListener<ScrollUpdateNotification>(
      // shortcut: load-more fires only on scroll; assumes the first page
      // (30 rows >= 56 px) always overflows the viewport, like
      // HadithListController. Revisit if page size or viewport changes.
      onNotification: (n) {
        // After a failure only the retry row reloads; scrolling must not loop.
        if (!controller.moreError.value && n.metrics.extentAfter < 300) {
          controller.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: rows.length + footer,
        itemBuilder: (context, i) {
          if (i < rows.length) {
            return switch (rows[i]) {
              _ItemRow(:final item) => SearchResultTile(
                item: item,
                onTap: () => _open(item.hit),
              ),
              _HeaderRow(:final title) => _SectionHeader(title),
            };
          }
          if (failed) {
            return ListTile(
              minTileHeight: 56, // M3 two-line tile minimum
              onTap: controller.loadMore,
              title: const Text('Gagal memuat, ketuk untuk mencoba lagi'),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(NuraSpace.s16),
            child: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}

/// One ListView row: a section title or a result.
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.title);

  final String title;
}

class _ItemRow extends _Row {
  const _ItemRow(this.item);

  final SearchItem item;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      NuraSpace.s16,
      NuraSpace.s16,
      NuraSpace.s16,
      NuraSpace.s4,
    ),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

/// Plain themed TextField (ruling G) with a clear button while filled.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _clear() {
    _text.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _text,
    builder: (context, value, _) => TextField(
      controller: _text,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: "Cari kata di Al-Qur'an dan hadis",
        prefixIcon: const Icon(Icons.search),
        suffixIcon: value.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Hapus',
                icon: const Icon(Icons.close),
                onPressed: _clear,
              ),
        border: const OutlineInputBorder(),
        constraints: const BoxConstraints(minHeight: NuraSpace.s48),
      ),
    ),
  );
}
