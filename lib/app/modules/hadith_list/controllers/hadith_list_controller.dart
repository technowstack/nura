import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../data/models/hadith.dart';
import '../../../data/repositories/hadith_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../hadith_list_args.dart';

/// Display model for one row: the view only renders these values.
class HadithListItem {
  const HadithListItem({
    required this.ref,
    required this.numberLabel,
    required this.preview,
    required this.bookmarked,
  });

  final HadithRef ref;
  final String numberLabel;
  final String preview;
  final bool bookmarked;
}

class HadithListController extends GetxController {
  HadithListController(this.args);

  final HadithListArgs args;
  final HadithRepository _hadith = Get.find();
  final UserRepository _user = Get.find();

  static const _pageSize = 30;
  static const _nearEnd = 300.0;

  final items = Rx<UiState<List<HadithListItem>>>(const UiLoading());
  final hasMore = false.obs;
  final loadingMore = false.obs;
  final loadMoreFailed = false.obs;
  final scroll = ScrollController();

  final List<HadithSummary> _loaded = [];
  Set<int> _marked = {};
  bool _busy = false;

  /// Bumped by load(); a request from an older generation changes no state.
  int _gen = 0;

  @override
  void onInit() {
    super.onInit();
    scroll.addListener(_onScroll);
    load();
  }

  @override
  void onClose() {
    scroll.dispose();
    super.onClose();
  }

  // shortcut: assumes one page (30 rows >= 56 px) overflows the viewport, so a
  // scroll event always happens; revisit if page size or viewport changes.
  void _onScroll() {
    // After a failure only the retry row reloads, scrolling must not loop.
    if (loadMoreFailed.value) return;
    if (scroll.hasClients && scroll.position.extentAfter < _nearEnd) {
      loadMore();
    }
  }

  void load() {
    _gen++;
    _busy = false;
    loadingMore.value = false;
    items.value = const UiLoading();
    hasMore.value = false;
    loadMoreFailed.value = false;
    _loaded.clear();
    // Deferred so the loading state is rendered before the data.
    final gen = _gen;
    Future.microtask(() => _first(gen));
  }

  Future<void> _first(int gen) async {
    if (gen != _gen || isClosed) return;
    if (args.slug.isEmpty) {
      items.value = const UiError('Kitab tidak ditemukan.');
      return;
    }
    _busy = true;
    try {
      final page = await _hadith.listPage(args.slug, limit: _pageSize);
      if (gen != _gen || isClosed) return;
      _loaded.addAll(page.items);
      hasMore.value = page.hasMore;
      _readMarkers();
      _publish();
    } on Object catch (e) {
      if (gen != _gen || isClosed) return;
      debugPrint('HadithListController: list unavailable: $e');
      items.value = const UiError('Konten tidak dapat dibaca.');
    }
    _busy = false;
  }

  Future<void> loadMore() async {
    if (_busy || !hasMore.value || _loaded.isEmpty) return;
    _busy = true;
    final gen = _gen;
    loadingMore.value = true;
    loadMoreFailed.value = false;
    try {
      final page = await _hadith.listPage(
        args.slug,
        afterNumber: _loaded.last.ref.number,
        limit: _pageSize,
      );
      if (gen != _gen || isClosed) return;
      _loaded.addAll(page.items);
      hasMore.value = page.hasMore && page.items.isNotEmpty;
      _publish();
    } on Object catch (e) {
      if (gen != _gen || isClosed) return;
      debugPrint('HadithListController: next page failed: $e');
      loadMoreFailed.value = true;
    }
    _busy = false;
    loadingMore.value = false;
  }

  /// Re-reads bookmark markers (e.g. after leaving the detail page).
  void refreshMarkers() {
    _readMarkers();
    if (_loaded.isNotEmpty) _publish();
  }

  void _readMarkers() {
    try {
      _marked = _user.bookmarkedHadithNumbers(args.slug);
    } on Object catch (e) {
      // Markers are decoration; the list stays usable without them.
      debugPrint('HadithListController: markers unavailable: $e');
    }
  }

  void _publish() {
    items.value = _loaded.isEmpty
        ? const UiEmpty()
        : UiData([
            for (final h in _loaded)
              HadithListItem(
                ref: h.ref,
                numberLabel: 'No. ${h.ref.number}',
                preview: h.preview,
                bookmarked: _marked.contains(h.ref.number),
              ),
          ]);
  }
}
