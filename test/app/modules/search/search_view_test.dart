import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/search_snippet.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/nura_colors.dart';
import 'package:nura/app/core/theme/nura_text_styles.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/search_hit.dart';
import 'package:nura/app/data/repositories/search_repository.dart';
import 'package:nura/app/modules/hadith_detail/hadith_detail_args.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/modules/search/bindings/search_binding.dart';
import 'package:nura/app/modules/search/controllers/search_results_controller.dart';
import 'package:nura/app/modules/search/search_args.dart';
import 'package:nura/app/modules/search/views/search_view.dart';
import 'package:nura/app/modules/search/widgets/search_result_tile.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';

// Real translations (same as test/app/core/search_snippet_test.dart).
const _baqarah45 =
    'Dan mohonlah pertolongan (kepada Allah) dengan sabar dan salat. Dan (salat) itu sungguh berat, kecuali bagi orang-orang yang khusyuk,';
const _baqarah153 =
    'Wahai orang-orang yang beriman! Mohonlah pertolongan (kepada Allah) dengan sabar dan salat. Sungguh, Allah beserta orang-orang yang sabar.';
const _ali146 =
    'Dan betapa banyak nabi yang berperang didampingi sejumlah besar dari pengikut(nya) yang bertakwa. Mereka tidak (menjadi) lemah karena bencana yang menimpanya di jalan Allah, tidak patah semangat dan tidak (pula) menyerah (kepada musuh). Dan Allah mencintai orang-orang yang sabar.';
const _nahl42 =
    '(yaitu) orang yang sabar dan hanya kepada Tuhan mereka bertawakal.';
const _basmalah = 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيْمِ';

const _base = TextStyle(fontSize: 15);
const _hl = Color(0xFFABCDEF);

String _plain(InlineSpan span) => span.toPlainText();

List<String> _highlightedTexts(InlineSpan span) {
  final out = <String>[];
  span.visitChildren((s) {
    if (s is TextSpan && s.style?.backgroundColor != null) {
      out.add(s.text ?? '');
    }
    return true;
  });
  return out;
}

AyahSearchHit _ayah(int row, int surah, int ayah, String name, String text) =>
    AyahSearchHit(
      rowId: row,
      snippet: buildSnippet(text, ['sabar']),
      surahNumber: surah,
      ayahNumber: ayah,
      surahName: name,
    );

final _ayahPage = SearchPage(
  hits: [
    _ayah(52, 2, 45, 'Al-Baqarah', _baqarah45),
    _ayah(160, 2, 153, 'Al-Baqarah', _baqarah153),
    _ayah(439, 3, 146, "Ali 'Imran", _ali146),
    _ayah(1943, 16, 42, 'An-Nahl', _nahl42),
  ],
  hasMore: false,
);

final _hadithPage = SearchPage(
  hits: [
    HadithSearchHit(
      rowId: 7,
      snippet: buildSnippet('Orang yang sabar akan mendapat pahala', ['sabar']),
      ref: const HadithRef('bukhari', 4066),
      bookName: 'Shahih Bukhari',
    ),
  ],
  hasMore: false,
);

void main() {
  group('snippetSpan', () {
    void check(String source, bool cutStart, bool cutEnd) {
      final s = buildSnippet(source, ['sabar']);
      expect(s.cutStart, cutStart);
      expect(s.cutEnd, cutEnd);
      final span = snippetSpan(s, _base, _hl);
      final text = _plain(span);
      expect(text.startsWith('…'), cutStart);
      expect(text.endsWith('…'), cutEnd);
      final inner = text.substring(
        cutStart ? 1 : 0,
        text.length - (cutEnd ? 1 : 0),
      );
      expect(inner, s.text);
      expect(_highlightedTexts(span), [
        for (final h in s.highlights) s.text.substring(h.start, h.end),
      ]);
      expect(_highlightedTexts(span), everyElement('sabar'));
      expect((span as TextSpan).style, _base);
    }

    test('Al-Baqarah 45: trailing ellipsis', () {
      check(_baqarah45, false, true);
    });
    test('Al-Baqarah 153: both ellipses', () {
      check(_baqarah153, true, true);
    });
    test("Ali 'Imran 146: leading ellipsis", () {
      check(_ali146, true, false);
    });
    test('An-Nahl 42: whole text, no ellipsis', () {
      check(_nahl42, false, false);
      expect(
        _plain(snippetSpan(buildSnippet(_nahl42, ['sabar']), _base, _hl)),
        _nahl42,
      );
    });
    List<(String, Color?)> parts(InlineSpan span) {
      final out = <(String, Color?)>[];
      span.visitChildren((s) {
        if (s is TextSpan && s.text != null) {
          out.add((s.text ?? '', s.style?.backgroundColor));
        }
        return true;
      });
      return out;
    }

    test('highlight at offset 0 and ending at text end with cutEnd', () {
      const s = Snippet(
        text: 'sabar dan sabar',
        highlights: [
          TextRange(start: 0, end: 5),
          TextRange(start: 10, end: 15),
        ],
        cutStart: true,
        cutEnd: true,
      );
      expect(parts(snippetSpan(s, _base, _hl)), [
        ('…', null),
        ('sabar', _hl),
        (' dan ', null),
        ('sabar', _hl),
        ('…', null),
      ]);
    });

    test('touching ranges stay separate and ellipses are unhighlighted', () {
      const s = Snippet(
        text: 'abcdef',
        highlights: [TextRange(start: 0, end: 3), TextRange(start: 3, end: 6)],
        cutStart: false,
        cutEnd: true,
      );
      expect(parts(snippetSpan(s, _base, _hl)), [
        ('abc', _hl),
        ('def', _hl),
        ('…', null),
      ]);
    });

    test('highlights use the given background color', () {
      final span = snippetSpan(buildSnippet(_nahl42, ['sabar']), _base, _hl);
      final colors = <Color?>[];
      span.visitChildren((s) {
        if (s is TextSpan && s.style?.backgroundColor != null) {
          colors.add(s.style?.backgroundColor);
        }
        return true;
      });
      expect(colors, [_hl]);
    });
  });

  group('SearchView', () {
    late FakeSearchRepository repo;
    Object? routeArgs;
    String? routeName;

    setUp(() {
      Get.reset();
      routeArgs = null;
      routeName = null;
      repo = FakeSearchRepository(ayahPage: _ayahPage, hadithPage: _hadithPage);
      Get.put<SearchRepository>(repo);
    });
    tearDown(Get.reset);

    GetPage<dynamic> stub(String name) => GetPage(
      name: name,
      page: () {
        routeName = name;
        routeArgs = Get.arguments;
        return const Scaffold(body: Text('stub'));
      },
    );

    Future<void> pump(
      WidgetTester tester, {
      double scale = 1,
      ThemeData? theme,
      SearchScope scope = SearchScope.quran,
    }) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: theme ?? AppTheme.light,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('home')),
          getPages: [
            GetPage(
              name: Routes.search,
              page: SearchView.new,
              binding: SearchBinding(),
            ),
            stub(Routes.surah),
            stub(Routes.hadithDetail),
          ],
        ),
      );
      Get.toNamed(Routes.search, arguments: SearchArgs(scope));
      await tester.pumpAndSettle();
    }

    SearchResultsController ctl() => Get.find<SearchResultsController>();

    Future<void> type(WidgetTester tester, String q) async {
      await tester.enterText(find.byType(TextField), q);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    Finder richOf(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(SearchResultTile),
      ),
      matching: find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
    );

    testWidgets('initial hint, then too-short hint', (tester) async {
      await pump(tester);
      expect(find.text(SearchResultsController.initialHint), findsOneWidget);
      await type(tester, 's');
      expect(find.text('Ketik minimal 2 huruf'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('search field is at least 48 high and has a clear button', (
      tester,
    ) async {
      await pump(tester);
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.byTooltip('Hapus'), findsNothing);
      await type(tester, 'sabar');
      expect(find.byTooltip('Hapus'), findsOneWidget);
      await tester.tap(find.byTooltip('Hapus'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hapus'), findsNothing);
      expect(find.text(SearchResultsController.initialHint), findsOneWidget);
    });

    testWidgets('loading, then results grouped under surah headers', (
      tester,
    ) async {
      await pump(tester);
      final gate = Completer<void>();
      repo.gate = gate;
      await tester.enterText(find.byType(TextField), 'sabar');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Al-Baqarah'), findsOneWidget);
      expect(find.text("Ali 'Imran"), findsOneWidget);
      expect(find.text('Ayat 45'), findsOneWidget);
      expect(find.text('Ayat 153'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Al-Baqarah')).dy,
        lessThan(tester.getTopLeft(find.text('Ayat 45')).dy),
      );
    });

    testWidgets('snippet is one Text.rich capped at 3 lines with ellipsis', (
      tester,
    ) async {
      repo.ayahPage = SearchPage(
        hits: [_ayah(1, 2, 45, 'Al-Baqarah', 'sabar ${'kata panjang ' * 40}')],
        hasMore: false,
      );
      await pump(tester);
      await type(tester, 'sabar');
      final rich = richOf('Ayat 45');
      expect(rich, findsOneWidget);
      final text = tester.widget<Text>(rich);
      expect(text.maxLines, 3);
      expect(text.overflow, TextOverflow.ellipsis);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: rich, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
    });

    for (final (name, theme, color) in [
      ('Light', AppTheme.light, NuraColors.light.searchHighlight),
      ('Dark', AppTheme.dark, NuraColors.dark.searchHighlight),
    ]) {
      testWidgets('highlight uses searchHighlight in $name', (tester) async {
        await pump(tester, theme: theme);
        await type(tester, 'sabar');
        final text = tester.widget<Text>(richOf('Ayat 42'));
        final colors = <Color?>[];
        text.textSpan?.visitChildren((s) {
          if (s is TextSpan && s.style?.backgroundColor != null) {
            colors.add(s.style?.backgroundColor);
          }
          return true;
        });
        expect(colors, [color]);
      });
    }

    testWidgets('empty results show Tidak ada hasil', (tester) async {
      repo.ayahPage = SearchPage.empty;
      await pump(tester);
      await type(tester, 'zzzz');
      expect(find.text('Tidak ada hasil'), findsOneWidget);
    });

    testWidgets('error shows retry that searches again', (tester) async {
      repo.failure = Exception('boom');
      await pump(tester);
      await type(tester, 'sabar');
      expect(find.byType(ErrorState), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Ayat 45'), findsOneWidget);
    });

    testWidgets('failed next page shows a retry row', (tester) async {
      repo.ayahPage = SearchPage(
        hits: [
          for (var i = 1; i <= 30; i++) _ayah(i, 2, i, 'Al-Baqarah', _nahl42),
        ],
        hasMore: true,
      );
      await pump(tester);
      await type(tester, 'sabar');
      repo.failure = Exception('boom');
      await tester.fling(find.byType(ListView), const Offset(0, -20000), 8000);
      await tester.pumpAndSettle();
      expect(ctl().moreError.value, isTrue);
      final retry = find.text('Gagal memuat, ketuk untuk mencoba lagi');
      expect(retry, findsOneWidget);
      // Scrolling after a failure must not fire more requests.
      final calls = repo.calls.length;
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView), const Offset(0, -20000), 8000);
      await tester.pumpAndSettle();
      expect(repo.calls.length, calls);
      expect(ctl().moreError.value, isTrue);
      repo.failure = null;
      repo.ayahPage = SearchPage.empty;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repo.calls.length, calls + 1);
      expect(ctl().moreError.value, isFalse);
      expect(retry, findsNothing);
    });

    testWidgets('tapping an ayah opens the surah at that ayah', (tester) async {
      await pump(tester);
      await type(tester, 'sabar');
      await tester.tap(find.text('Ayat 153'));
      await tester.pumpAndSettle();
      expect(routeName, Routes.surah);
      final args = routeArgs as SurahArgs;
      expect((args.surah, args.ayah), (2, 153));
    });

    testWidgets('hadith scope: book header, label and detail navigation', (
      tester,
    ) async {
      await pump(tester, scope: SearchScope.hadith);
      await type(tester, 'sabar');
      final header = find.descendant(
        of: find.byType(ListView),
        matching: find.text('Shahih Bukhari'),
      );
      expect(header, findsOneWidget);
      expect(
        tester.getTopLeft(header).dy,
        lessThan(tester.getTopLeft(find.text('No. 4.066')).dy),
      );
      expect(find.text('No. 4.066'), findsOneWidget);
      await tester.tap(find.text('No. 4.066'));
      await tester.pumpAndSettle();
      expect(routeName, Routes.hadithDetail);
      final args = routeArgs as HadithDetailArgs;
      expect((args.slug, args.number), ('bukhari', 4066));
    });

    testWidgets('scope chips and book chips drive the controller', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Semua kitab'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, "Al-Qur'an"))
            .selected,
        isTrue,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hadis'));
      await tester.pumpAndSettle();
      expect(ctl().scope.value, SearchScope.hadith);
      expect(find.text('Semua kitab'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Shahih Muslim'), findsOneWidget);

      await type(tester, 'sabar');
      final muslim = find.widgetWithText(ChoiceChip, 'Shahih Muslim');
      await tester.ensureVisible(muslim);
      await tester.pumpAndSettle();
      await tester.tap(muslim);
      await tester.pumpAndSettle();
      expect(ctl().bookSlug.value, 'muslim');
      expect(repo.calls.last.bookSlug, 'muslim');

      final all = find.widgetWithText(ChoiceChip, 'Semua kitab');
      await tester.ensureVisible(all);
      await tester.pumpAndSettle();
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(ctl().bookSlug.value, isNull);
      expect(repo.calls.last.bookSlug, isNull);

      await tester.tap(find.widgetWithText(ChoiceChip, "Al-Qur'an"));
      await tester.pumpAndSettle();
      expect(ctl().scope.value, SearchScope.quran);
      expect(find.text('Semua kitab'), findsNothing);
    });

    testWidgets('Arabic results render RTL with the Arabic font', (
      tester,
    ) async {
      repo.ayahPage = SearchPage(
        hits: [
          AyahSearchHit(
            rowId: 1,
            snippet: buildArabicSnippet(_basmalah, ['الرحمن']),
            surahNumber: 1,
            ayahNumber: 1,
            surahName: 'Al-Fatihah',
          ),
        ],
        hasMore: false,
      );
      await pump(tester);
      await type(tester, 'الرحمن');
      final text = tester.widget<Text>(richOf('Ayat 1'));
      expect(text.textDirection, TextDirection.rtl);
      expect(text.textSpan?.style?.fontFamily, nuraArabicFont);
      expect(text.textSpan?.toPlainText(), _basmalah);
    });

    testWidgets('Latin results stay LTR', (tester) async {
      await pump(tester);
      await type(tester, 'sabar');
      final text = tester.widget<Text>(richOf('Ayat 45'));
      expect(text.textDirection, TextDirection.ltr);
    });

    testWidgets('Latin 130% at 360x640 with results does not overflow', (
      tester,
    ) async {
      await pump(tester, scale: 1.3, scope: SearchScope.hadith);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(ChoiceChip, "Al-Qur'an"));
      await type(tester, 'sabar');
      expect(find.text('Ayat 45'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hadis'));
      await tester.pumpAndSettle();
      expect(find.text('No. 4.066'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
