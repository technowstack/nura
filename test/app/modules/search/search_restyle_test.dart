import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/ayah_marker.dart';
import 'package:nura/app/core/nura_icons.dart';
import 'package:nura/app/core/search_snippet.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/nura_colors.dart';
import 'package:nura/app/core/widgets/nura_card.dart';
import 'package:nura/app/data/models/search_hit.dart';
import 'package:nura/app/modules/bookmarks/controllers/bookmark_item.dart';
import 'package:nura/app/modules/bookmarks/widgets/bookmark_tile.dart';
import 'package:nura/app/data/models/ayah.dart';
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
  for (final (theme, colors) in [
    (AppTheme.light, NuraColors.light),
    (AppTheme.dark, NuraColors.dark),
  ]) {
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
      final icon = t.widget<Icon>(
        find.descendant(
          of: find.byType(BookmarkTile),
          matching: find.byIcon(NuraIcons.bookmark),
        ),
      );
      expect(icon.color, colors.iconAccent);
      expect(icon.fill, 1);
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

  String plain(WidgetTester t) => t
      .widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      )
      .textSpan!
      .toPlainText();

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
    expect(plain(t), ayahDisplayText(s.text, 45));
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
