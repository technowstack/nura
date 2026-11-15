import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/search_snippet.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/search_hit.dart';
import 'package:nura/app/data/repositories/search_repository.dart';
import 'package:nura/app/modules/search/bindings/search_binding.dart';
import 'package:nura/app/modules/search/controllers/search_results_controller.dart';
import 'package:nura/app/modules/search/search_args.dart';

import '../../../support/fake_repositories.dart';

const _snippet = Snippet(
  text: 'teks',
  highlights: <TextRange>[],
  cutStart: false,
  cutEnd: false,
);

AyahSearchHit _ayah(int rowId, int surah, int ayah, String name) =>
    AyahSearchHit(
      rowId: rowId,
      snippet: _snippet,
      surahNumber: surah,
      ayahNumber: ayah,
      surahName: name,
    );

HadithSearchHit _hadith(int rowId, String slug, int number, String book) =>
    HadithSearchHit(
      rowId: rowId,
      snippet: _snippet,
      ref: HadithRef(slug, number),
      bookName: book,
    );

List<SearchSection> _sections(SearchResultsController c) =>
    (c.state.value as UiData<List<SearchSection>>).value;

/// Timers and microtasks run on the test clock: `tester.pump(d)` advances it.
void main() {
  late FakeSearchRepository repo;

  setUp(() {
    Get.reset();
    repo = FakeSearchRepository(
      ayahPage: SearchPage(
        hits: [
          _ayah(1, 1, 1, 'Al-Fatihah'),
          _ayah(2, 1, 5, 'Al-Fatihah'),
          _ayah(9, 2, 3, 'Al-Baqarah'),
        ],
        hasMore: false,
      ),
    );
    Get.put<SearchRepository>(repo);
  });
  tearDown(Get.reset);

  SearchResultsController make([SearchScope scope = SearchScope.quran]) =>
      Get.put(SearchResultsController(SearchArgs(scope)));

  test('books lists the nine hadith slugs in sort order', () {
    expect(SearchResultsController.books.keys, [
      'bukhari',
      'muslim',
      'abu-daud',
      'tirmidzi',
      'nasai',
      'ibnu-majah',
      'ahmad',
      'malik',
      'darimi',
    ]);
  });

  testWidgets('starts with the initial hint and no repository call', (
    tester,
  ) async {
    final c = make();
    expect(c.hint.value, isNotNull);
    expect(c.hint.value, isNot('Ketik minimal 2 huruf'));
    expect(c.state.value, isNot(isA<UiEmpty<List<SearchSection>>>()));
    expect(c.scope.value, SearchScope.quran);
    expect(repo.calls, isEmpty);
  });

  testWidgets('debounces 300 ms and sends only the last query', (tester) async {
    final c = make();
    c.onQueryChanged('ra');
    await tester.pump(const Duration(milliseconds: 200));
    c.onQueryChanged('rahmat');
    await tester.pump(const Duration(milliseconds: 299));
    expect(repo.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.query.tokens, ['rahmat']);
    expect(repo.calls.single.hadith, isFalse);
    expect(c.hint.value, isNull);
    expect(_sections(c), isNotEmpty);
  });

  testWidgets('empty query clears results and shows the initial hint', (
    tester,
  ) async {
    final c = make();
    final initial = c.hint.value;
    c.onQueryChanged('rahmat');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(_sections(c), isNotEmpty);
    c.onQueryChanged('   ');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.calls, hasLength(1));
    expect(c.hint.value, initial);
    expect(_sections(c), isEmpty);
  });

  testWidgets('one letter shows the minimum-length hint without a call', (
    tester,
  ) async {
    final c = make();
    c.onQueryChanged('r');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(c.hint.value, 'Ketik minimal 2 huruf');
    expect(repo.calls, isEmpty);
  });

  testWidgets('no hits gives UiEmpty', (tester) async {
    repo.ayahPage = SearchPage.empty;
    final c = make();
    c.onQueryChanged('zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(c.state.value, isA<UiEmpty<List<SearchSection>>>());
    expect(c.hint.value, isNull);
  });

  testWidgets('shows loading while the reply is pending', (tester) async {
    final gate = Completer<void>();
    repo.gate = gate;
    final c = make();
    c.onQueryChanged('rahmat');
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.state.value, isA<UiLoading<List<SearchSection>>>());
    gate.complete();
    await tester.pump();
    expect(_sections(c), isNotEmpty);
  });

  testWidgets('a stale reply is discarded', (tester) async {
    final gate = Completer<void>();
    repo.gate = gate;
    final c = make();
    c.onQueryChanged('lama');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.calls, hasLength(1));
    // The newer query answers first with a different page.
    final oldPage = repo.ayahPage;
    repo.ayahPage = SearchPage(
      hits: [_ayah(50, 3, 7, 'Ali Imran')],
      hasMore: false,
    );
    c.onQueryChanged('baru');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(_sections(c).single.title, 'Ali Imran');
    repo.ayahPage = oldPage;
    gate.complete();
    await tester.pump();
    expect(_sections(c).single.title, 'Ali Imran');
  });

  testWidgets('groups adjacent hits by surah with ayah labels', (tester) async {
    final c = make();
    c.onQueryChanged('rahmat');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final s = _sections(c);
    expect(s.map((e) => e.title), ['Al-Fatihah', 'Al-Baqarah']);
    expect(s.first.items.map((e) => e.label), ['Ayat 1', 'Ayat 5']);
    expect(s.first.items.first.hit.rowId, 1);
  });

  testWidgets('hadith scope groups by book with thousands labels', (
    tester,
  ) async {
    repo.hadithPage = SearchPage(
      hits: [
        _hadith(1, 'bukhari', 4066, 'Shahih Bukhari'),
        _hadith(2, 'bukhari', 4067, 'Shahih Bukhari'),
        _hadith(3, 'muslim', 12, 'Shahih Muslim'),
      ],
      hasMore: false,
    );
    final c = make(SearchScope.hadith);
    c.onQueryChanged('sabar');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(repo.calls.single.hadith, isTrue);
    final s = _sections(c);
    expect(s.map((e) => e.title), ['Shahih Bukhari', 'Shahih Muslim']);
    expect(s.first.items.map((e) => e.label), ['No. 4.066', 'No. 4.067']);
  });

  testWidgets('setScope and setBook re-run the current query at once', (
    tester,
  ) async {
    final c = make();
    c.onQueryChanged('sabar');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    c.setScope(SearchScope.hadith);
    await tester.pump();
    expect(c.scope.value, SearchScope.hadith);
    expect(repo.calls, hasLength(2));
    expect(repo.calls.last.hadith, isTrue);
    expect(repo.calls.last.bookSlug, isNull);
    c.setBook('muslim');
    await tester.pump();
    expect(c.bookSlug.value, 'muslim');
    expect(repo.calls, hasLength(3));
    expect(repo.calls.last.bookSlug, 'muslim');
    expect(repo.calls.last.query.tokens, ['sabar']);
    c.setBook('muslim'); // same value: no call
    await tester.pump();
    expect(repo.calls, hasLength(3));
  });

  testWidgets('setBook in quran scope stores the book without a call', (
    tester,
  ) async {
    final c = make();
    c.onQueryChanged('sabar');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    c.setBook('muslim');
    await tester.pump();
    expect(c.bookSlug.value, 'muslim');
    expect(repo.calls, hasLength(1));
    c.setScope(SearchScope.hadith);
    await tester.pump();
    expect(repo.calls.last.bookSlug, 'muslim');
  });

  testWidgets('a stale loadMore reply is discarded after a new query', (
    tester,
  ) async {
    repo.ayahPage = SearchPage(
      hits: [_ayah(1, 1, 1, 'Al-Fatihah')],
      hasMore: true,
    );
    final c = make();
    c.onQueryChanged('lama');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    final gate = Completer<void>();
    repo.gate = gate;
    repo.ayahPage = SearchPage(
      hits: [_ayah(2, 1, 2, 'Al-Fatihah')],
      hasMore: false,
    );
    final more = c.loadMore();
    await tester.pump();
    expect(c.loadingMore.value, isTrue);
    repo.ayahPage = SearchPage(
      hits: [_ayah(50, 3, 7, 'Ali Imran')],
      hasMore: true,
    );
    c.onQueryChanged('baru');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    gate.complete();
    await more;
    await tester.pump();
    final s = _sections(c);
    expect(s.single.title, 'Ali Imran');
    expect(s.single.items.map((e) => e.hit.rowId), [50]);
    expect(c.loadingMore.value, isFalse);
    expect(c.hasMore.value, isTrue);
    final before = repo.calls.length;
    await c.loadMore(); // not blocked by the stale request's _busy
    expect(repo.calls, hasLength(before + 1));
    expect(repo.calls.last.afterRowId, 50);
    expect(repo.calls.last.query.tokens, ['baru']);
  });

  test('empty state text comes from the controller', () {
    expect(SearchResultsController.emptyText, 'Tidak ada hasil');
  });

  testWidgets('setScope before typing makes no call', (tester) async {
    final c = make();
    c.setScope(SearchScope.hadith);
    await tester.pump();
    expect(repo.calls, isEmpty);
    expect(c.hint.value, isNotNull);
  });

  testWidgets('loadMore continues the last section without a new title', (
    tester,
  ) async {
    repo.ayahPage = SearchPage(
      hits: [_ayah(1, 1, 1, 'Al-Fatihah'), _ayah(2, 1, 2, 'Al-Fatihah')],
      hasMore: true,
    );
    final c = make();
    c.onQueryChanged('rahmat');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    repo.ayahPage = SearchPage(
      hits: [_ayah(3, 1, 3, 'Al-Fatihah'), _ayah(8, 2, 1, 'Al-Baqarah')],
      hasMore: false,
    );
    unawaited(c.loadMore());
    unawaited(c.loadMore()); // ignored while the first is running
    await tester.pump();
    expect(repo.calls, hasLength(2));
    expect(repo.calls.last.afterRowId, 2);
    final s = _sections(c);
    expect(s.map((e) => e.title), ['Al-Fatihah', 'Al-Baqarah']);
    expect(s.first.items.map((e) => e.label), ['Ayat 1', 'Ayat 2', 'Ayat 3']);
    expect(c.hasMore.value, isFalse);
    await c.loadMore(); // stops when hasMore is false
    expect(repo.calls, hasLength(2));
  });

  testWidgets('repository failure gives UiError and retry recovers', (
    tester,
  ) async {
    repo.failure = const ContentUnavailable('search');
    final c = make();
    c.onQueryChanged('rahmat');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(c.state.value, isA<UiError<List<SearchSection>>>());
    repo.failure = null;
    c.retry();
    await tester.pump();
    expect(_sections(c), isNotEmpty);
  });

  testWidgets('loadMore failure keeps results and sets moreError', (
    tester,
  ) async {
    repo.ayahPage = SearchPage(
      hits: [_ayah(1, 1, 1, 'Al-Fatihah')],
      hasMore: true,
    );
    final c = make();
    c.onQueryChanged('rahmat');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    repo.failure = const ContentUnavailable('search');
    await c.loadMore();
    expect(c.moreError.value, isTrue);
    expect(c.loadingMore.value, isFalse);
    expect(_sections(c).single.items, hasLength(1));
    repo.failure = null;
    await c.loadMore();
    expect(c.moreError.value, isFalse);
  });

  testWidgets('closing while a reply is pending does not throw', (
    tester,
  ) async {
    final gate = Completer<void>();
    repo.gate = gate;
    final c = make();
    c.onQueryChanged('rahmat');
    await tester.pump(const Duration(milliseconds: 300));
    c.onQueryChanged('rahmat lain'); // pending debounce timer too
    await Get.delete<SearchResultsController>();
    gate.complete();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.calls, hasLength(1));
  });

  testWidgets('binding reads SearchArgs and falls back to quran', (
    tester,
  ) async {
    SearchBinding().dependencies();
    expect(Get.find<SearchResultsController>().scope.value, SearchScope.quran);
  });
}
