import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:nura/content_pipeline/content_schema.dart';

import '../../../core/format_thousands.dart';
import '../../../core/search_query.dart';
import '../../../core/ui_state.dart';
import '../../../data/models/search_hit.dart';
import '../../../data/repositories/search_repository.dart';
import '../search_args.dart';

/// One result row: the view only renders these values.
class SearchItem {
  const SearchItem(this.hit, this.label);

  final SearchHit hit;

  /// "Ayat 5" or "No. 4.066".
  final String label;
}

/// Adjacent hits from one surah (ayat) or one book (hadith).
class SearchSection {
  const SearchSection(this.title, this.items);

  final String title;
  final List<SearchItem> items;
}

class SearchResultsController extends GetxController {
  SearchResultsController(SearchArgs args) : scope = args.scope.obs;

  final SearchRepository _repo = Get.find();

  static const _pageSize = 30;
  static const _debounce = Duration(milliseconds: 300);
  static const initialHint =
      'Ketik minimal 2 huruf, misalnya sabar atau ikhlas.';
  static const tooShortHint = 'Ketik minimal 2 huruf';

  /// Hadith books for the book filter: slug to name, in `sort_order`.
  static const books = hadithBookNames;

  /// Text for the view's empty state (`UiEmpty`).
  static const emptyText = 'Tidak ada hasil';

  final Rx<SearchScope> scope;
  final bookSlug = RxnString();

  /// Non-null when the view should show this text instead of [state].
  final hint = RxnString(initialHint);
  final state = Rx<UiState<List<SearchSection>>>(const UiData([]));
  final hasMore = false.obs;
  final loadingMore = false.obs;
  final moreError = false.obs;

  String _query = '';
  ParsedQuery _parsed = parseSearchQuery('');
  final List<SearchHit> _hits = [];
  Timer? _timer;
  bool _busy = false;

  /// Bumped by every new search; a reply from an older generation is dropped.
  int _gen = 0;

  @override
  void onClose() {
    _timer?.cancel();
    _gen++;
    super.onClose();
  }

  void onQueryChanged(String query) {
    _query = query;
    _timer?.cancel();
    _timer = Timer(_debounce, _run);
  }

  void setScope(SearchScope value) {
    if (scope.value == value) return;
    scope.value = value;
    _run();
  }

  void setBook(String? slug) {
    if (bookSlug.value == slug) return;
    bookSlug.value = slug;
    // Ayah search ignores the book filter.
    if (scope.value == SearchScope.hadith) _run();
  }

  void retry() => _run();

  void _run() {
    _timer?.cancel();
    _gen++;
    _busy = false;
    _hits.clear();
    hasMore.value = false;
    loadingMore.value = false;
    moreError.value = false;
    _parsed = parseSearchQuery(_query);
    switch (_parsed.status) {
      case QueryStatus.empty:
        _showHint(initialHint);
      case QueryStatus.tooShort:
        _showHint(tooShortHint);
      case QueryStatus.ok:
        hint.value = null;
        state.value = const UiLoading();
        _first(_gen);
    }
  }

  void _showHint(String text) {
    hint.value = text;
    state.value = const UiData([]);
  }

  Future<void> _first(int gen) async {
    _busy = true;
    try {
      final page = await _search(0);
      if (gen != _gen || isClosed) return;
      _hits.addAll(page.hits);
      hasMore.value = page.hasMore && page.hits.isNotEmpty;
      _publish();
    } on Object catch (e) {
      if (gen != _gen || isClosed) return;
      debugPrint('SearchResultsController: search failed: $e');
      state.value = const UiError('Pencarian gagal. Coba lagi.');
    }
    _busy = false;
  }

  Future<void> loadMore() async {
    if (_busy || !hasMore.value || _hits.isEmpty) return;
    _busy = true;
    final gen = _gen;
    loadingMore.value = true;
    moreError.value = false;
    try {
      final page = await _search(_hits.last.rowId);
      if (gen != _gen || isClosed) return;
      _hits.addAll(page.hits);
      hasMore.value = page.hasMore && page.hits.isNotEmpty;
      _publish();
    } on Object catch (e) {
      if (gen != _gen || isClosed) return;
      debugPrint('SearchResultsController: next page failed: $e');
      moreError.value = true;
    }
    _busy = false;
    loadingMore.value = false;
  }

  Future<SearchPage> _search(int afterRowId) async {
    final label = '${scope.value.name} "${_query.trim()}"';
    final watch = Stopwatch()..start();
    try {
      return scope.value == SearchScope.hadith
          ? await _repo.searchHadith(
              _parsed,
              bookSlug: bookSlug.value,
              afterRowId: afterRowId,
              limit: _pageSize,
            )
          : await _repo.searchAyah(
              _parsed,
              afterRowId: afterRowId,
              limit: _pageSize,
            );
    } finally {
      // Read from `flutter run --profile` to check the < 1 s target on device.
      if (!kReleaseMode) {
        debugPrint('search $label ${watch.elapsedMilliseconds} ms');
      }
    }
  }

  void _publish() {
    if (_hits.isEmpty) {
      state.value = const UiEmpty();
      return;
    }
    final sections = <SearchSection>[];
    Object? lastKey;
    for (final hit in _hits) {
      final (key, title, label) = switch (hit) {
        AyahSearchHit h => (
          h.surahNumber,
          h.surahName,
          'Ayat ${formatThousands(h.ayahNumber)}',
        ),
        HadithSearchHit h => (
          h.ref.slug,
          h.bookName,
          'No. ${formatThousands(h.ref.number)}',
        ),
      };
      if (sections.isEmpty || key != lastKey) {
        sections.add(SearchSection(title, []));
        lastKey = key;
      }
      sections.last.items.add(SearchItem(hit, label));
    }
    state.value = UiData(sections);
  }
}
