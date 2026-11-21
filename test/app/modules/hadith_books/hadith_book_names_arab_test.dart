import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/nura_icons.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/widgets/nura_card.dart';
import 'package:nura/app/data/models/hadith_book.dart';
import 'package:nura/app/modules/hadith_books/controllers/hadith_books_controller.dart';
import 'package:nura/app/modules/hadith_books/widgets/hadith_book_tile.dart';
import 'package:nura/content_pipeline/content_schema.dart';

/// Owner-supplied names, written independently of the production map.
const _owner = {
  'bukhari': 'صحيح البخاري',
  'muslim': 'صحيح مسلم',
  'abu-daud': 'سنن أبي داود',
  'tirmidzi': 'سنن الترمذي',
  'nasai': 'سنن النسائي',
  'ibnu-majah': 'سنن ابن ماجه',
  'ahmad': 'مسند أحمد',
  'malik': 'موطأ مالك',
  'darimi': 'سنن الدارمي',
};

void main() {
  test('nine Arabic names match the owner list exactly', () {
    expect(hadithBookNamesArab, _owner);
    expect(hadithBookNamesArab.keys.toList(), hadithBookNames.keys.toList());
    for (final e in _owner.entries) {
      expect(hadithBookNameArab(e.key), e.value);
    }
    // U+0635 U+062D U+064A U+062D then space, U+0627 ... for "sahih al-bukhari".
    expect(hadithBookNamesArab['bukhari']!.runes.take(4).toList(), [
      0x0635,
      0x062D,
      0x064A,
      0x062D,
    ]);
  });

  test('unknown slug gives null', () {
    expect(hadithBookNameArab('nope'), isNull);
  });

  Future<void> pump(
    WidgetTester tester,
    String slug, {
    Brightness brightness = Brightness.light,
    double scale = 1,
    VoidCallback? onTap,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: HadithBookTile(
            item: HadithBookItem(
              HadithBook(
                slug: slug,
                name: 'Shahih Bukhari',
                hadithCount: 6638,
                sortOrder: 1,
              ),
              '6.638 hadis',
            ),
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('tile shows Latin name, count, Arabic name, icon, chevron', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, 'bukhari', onTap: () => taps++);
    expect(find.byType(NuraCard), findsOneWidget);
    expect(find.text('Shahih Bukhari'), findsOneWidget);
    expect(find.text('6.638 hadis'), findsOneWidget);
    final arab = tester.widget<Text>(find.text('صحيح البخاري'));
    final theme = tester.element(find.byType(HadithBookTile)).nuraText;
    expect(arab.style?.fontFamily, theme.arabicTitle.fontFamily);
    expect(arab.textDirection, TextDirection.rtl);
    expect(
      find.byWidgetPredicate(
        (w) => w is NuraIcon && w.icon == NuraIcons.menuBook,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is NuraIcon && w.icon == NuraIcons.chevronRight,
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(HadithBookTile));
    expect(taps, 1);
  });

  testWidgets('unknown slug: no Arabic text, no error', (tester) async {
    await pump(tester, 'nope');
    expect(tester.takeException(), isNull);
    expect(find.text('Shahih Bukhari'), findsOneWidget);
    expect(find.text('صحيح البخاري'), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('uses theme tokens in $b', (tester) async {
      await pump(tester, 'bukhari', brightness: b);
      final colors = tester.element(find.byType(HadithBookTile)).nuraColors;
      final arab = tester.widget<Text>(find.text('صحيح البخاري'));
      expect(arab.style?.color, colors.iconAccent);
    });
  }

  testWidgets('130% at 360x640 does not overflow', (tester) async {
    await pump(tester, 'ibnu-majah', scale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
