import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/ayah_text.dart';
import 'package:nura/app/core/search_snippet.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/widgets/ayah_end_marker.dart';
import 'package:nura/app/core/widgets/nura_card.dart';
import 'package:nura/app/data/models/search_hit.dart';
import 'package:nura/app/modules/bookmarks/controllers/bookmark_item.dart';
import 'package:nura/app/modules/bookmarks/widgets/bookmark_tile.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/modules/search/controllers/search_results_controller.dart';
import 'package:nura/app/modules/search/widgets/search_result_tile.dart';

const _tr = 'Dan mohonlah pertolongan (kepada Allah) dengan sabar dan salat.';
const _ar = 'وَاسْتَعِيْنُوْا بِالصَّبْرِ وَالصَّلٰوةِۗ';

SearchItem _item(Snippet s) => SearchItem(
  AyahSearchHit(
    rowId: 1,
    snippet: s,
    surahNumber: 2,
    ayahNumber: 45,
    surahName: 'Al-Baqarah',
  ),
  'Ayat 45',
);

Widget _host(ThemeData theme, Widget child, {double scale = 1}) => MaterialApp(
  theme: theme,
  builder: (c, w) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: w!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('result and bookmark are NuraCards (${theme.brightness})', (
      t,
    ) async {
      await t.pumpWidget(
        _host(
          theme,
          Column(
            children: [
              SearchResultTile(
                item: _item(buildSnippet(_tr, ['sabar'])),
                onTap: () {},
              ),
              BookmarkTile(
                item: AyahBookmarkItem(
                  ref: const AyahRef(2, 3),
                  title: 'QS. Al-Baqarah: 3',
                  body: 'isi',
                  createdAt: DateTime(2000),
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(find.byType(NuraCard), findsNWidgets(2));
      for (final card in t.widgetList<NuraCard>(find.byType(NuraCard))) {
        expect(card.color, isNull); // default fill: surfaceContainerLowest
      }
      final m = t.widget<Material>(
        find
            .descendant(
              of: find.byType(NuraCard).first,
              matching: find.byType(Material),
            )
            .first,
      );
      expect(m.color, theme.colorScheme.surfaceContainerLowest);
      final side = (m.shape! as RoundedRectangleBorder).side;
      expect(side.color, theme.colorScheme.outlineVariant);
    });
  }

  testWidgets('snippet and highlight unchanged inside the card', (t) async {
    await t.pumpWidget(
      _host(
        AppTheme.light,
        SearchResultTile(
          item: _item(buildSnippet(_tr, ['sabar'])),
          onTap: () {},
        ),
      ),
    );
    final span = t
        .widget<Text>(
          find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
        )
        .textSpan!;
    expect(span.toPlainText(), _tr);
    final hl = <String>[];
    span.visitChildren((s) {
      if (s is TextSpan && s.style?.backgroundColor != null) hl.add(s.text!);
      return true;
    });
    expect(hl, ['sabar']);
  });

  Text rich(WidgetTester t) => t.widget<Text>(
    find.descendant(
      of: find.byType(SearchResultTile),
      matching: find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
    ),
  );
  String plain(WidgetTester t) => rich(t).textSpan!.toPlainText();
  List<String> marked(WidgetTester t) {
    final out = <String>[];
    rich(t).textSpan!.visitChildren((s) {
      if (s is TextSpan && s.style?.backgroundColor != null) out.add(s.text!);
      return true;
    });
    return out;
  }

  testWidgets('full-ayah Arabic gets the end marker, highlights intact', (
    t,
  ) async {
    final s = buildArabicSnippet(_ar, [
      normalizeArabicWithOffsets(_ar).text.substring(0, 3),
    ]);
    expect(s.cutStart || s.cutEnd, isFalse);
    await t.pumpWidget(
      _host(AppTheme.light, SearchResultTile(item: _item(s), onTap: () {})),
    );
    expect(plain(t), ayahSearchPlain(s.text, 45));
    final last = (rich(t).textSpan! as TextSpan).children!.last;
    expect(last, isA<WidgetSpan>());
    expect(((last as WidgetSpan).child as AyahEndMarker).number, 45);
  });

  testWidgets('whole-ayah snippet with a trailing space: one marker space', (
    t,
  ) async {
    const ar = '$_ar ';
    final s = buildArabicSnippet(ar, [
      normalizeArabicWithOffsets(ar).text.substring(0, 3),
    ]);
    expect(s.cutStart || s.cutEnd, isFalse);
    expect(s.text.endsWith(' '), isTrue);
    await t.pumpWidget(
      _host(AppTheme.light, SearchResultTile(item: _item(s), onTap: () {})),
    );
    expect(plain(t), ayahSearchPlain(ar, 45));
    expect(plain(t), isNot(contains('  ')));
    expect(marked(t), isNotEmpty);
  });

  testWidgets('cut Arabic snippet never gets the marker', (t) async {
    final long = List.filled(30, 'بِالصَّبْرِ').join(' ');
    final s = buildArabicSnippet(long, ['بالصبر']);
    expect(s.cutEnd, isTrue);
    await t.pumpWidget(
      _host(AppTheme.light, SearchResultTile(item: _item(s), onTap: () {})),
    );
    expect(plain(t).contains('۝'), isFalse);
  });

  testWidgets('translation never gets a marker', (t) async {
    await t.pumpWidget(
      _host(
        AppTheme.light,
        SearchResultTile(
          item: _item(buildSnippet(_tr, ['sabar'])),
          onTap: () {},
        ),
      ),
    );
    expect(plain(t).contains('۝'), isFalse);
  });

  testWidgets('marker keeps all highlights; end match stops before it', (
    t,
  ) async {
    const ar = 'بِسْمِ اللّٰهِ بِسْمِ';
    final s = buildArabicSnippet(ar, ['بسم']);
    expect(s.highlights.length, 2);
    await t.pumpWidget(
      _host(AppTheme.light, SearchResultTile(item: _item(s), onTap: () {})),
    );
    final hl = marked(t);
    expect(hl.length, 2);
    expect(hl.last, ar.substring(ar.lastIndexOf('بِ')));
    expect(hl.any((h) => h.contains('۝')), isFalse);
    expect(plain(t), ayahSearchPlain(ar, 45));
  });

  testWidgets('hadith hit with Arabic text never gets the marker', (t) async {
    final item = SearchItem(
      HadithSearchHit(
        rowId: 1,
        snippet: buildArabicSnippet(_ar, ['صبر']),
        ref: const HadithRef('bukhari', 1),
        bookName: 'Shahih Bukhari',
      ),
      'No. 1',
    );
    await t.pumpWidget(
      _host(AppTheme.light, SearchResultTile(item: item, onTap: () {})),
    );
    expect(plain(t).contains('۝'), isFalse);
  });

  testWidgets('130% scale at 360x640 does not overflow', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(
        AppTheme.light,
        Column(
          children: [
            SearchResultTile(
              item: _item(buildSnippet(_tr * 3, ['sabar'])),
              onTap: () {},
            ),
            BookmarkTile(
              item: AyahBookmarkItem(
                ref: const AyahRef(2, 3),
                title: 'QS. Al-Baqarah: 3',
                body: _tr * 3,
                createdAt: DateTime(2000),
              ),
              onTap: () {},
            ),
          ],
        ),
        scale: 1.3,
      ),
    );
    expect(t.takeException(), isNull);
  });
}
