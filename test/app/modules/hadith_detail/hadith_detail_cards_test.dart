import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/nura_colors.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/hadith_book.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/hadith_detail/controllers/hadith_detail_controller.dart';
import 'package:nura/app/modules/hadith_detail/hadith_detail_args.dart';
import 'package:nura/app/modules/hadith_detail/views/hadith_detail_view.dart';

import '../../../support/fake_repositories.dart';

Hadith _h(String slug, int n, {String? arab}) => Hadith(
  ref: HadithRef(slug, n),
  bookName: 'Shahih Bukhari',
  arab: arab ?? 'arab$n',
  translation: 'trans$n',
  translationLength: 6,
  arabTruncated: false,
  translationTruncated: false,
);

void main() {
  late FakeHadithRepository repo;
  late FakeUserRepository user;

  setUp(() {
    Get.reset();
    repo = FakeHadithRepository(
      hadith: [_h('bukhari', 1), _h('bukhari', 2), _h('zzz', 1)],
      books: const [
        HadithBook(
          slug: 'bukhari',
          name: 'Shahih Bukhari',
          hadithCount: 6638,
          sortOrder: 1,
        ),
        HadithBook(slug: 'zzz', name: 'Zzz', hadithCount: 5, sortOrder: 2),
      ],
    );
    user = FakeUserRepository();
    Get.put<HadithRepository>(repo);
    Get.put<UserRepository>(user);
  });
  tearDown(Get.reset);

  Future<void> pump(
    WidgetTester t,
    String slug,
    int n, {
    double scale = 1,
    ThemeMode mode = ThemeMode.light,
  }) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Get.put(HadithDetailController(HadithDetailArgs(slug, n)));
    await t.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HadithDetailView(),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('hero shows kitab, nomor, formatted count and Arabic name', (
    t,
  ) async {
    await pump(t, 'bukhari', 1);
    expect(find.textContaining('Kitab', findRichText: true), findsOneWidget);
    expect(find.textContaining('Nomor', findRichText: true), findsOneWidget);
    expect(find.textContaining('6.638', findRichText: true), findsOneWidget);
    expect(find.text('صحيح البخاري'), findsOneWidget);
  });

  testWidgets('unknown slug has no Arabic name in hero', (t) async {
    await pump(t, 'zzz', 1);
    expect(find.textContaining('Kitab', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('hadith-hero-arab')), findsNothing);
  });

  testWidgets('reference row and copy string unchanged', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await pump(t, 'bukhari', 1);
    expect(find.text('HR. Shahih Bukhari No. 1'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Salin hadis'));
    await t.pump();
    expect(copied, 'arab1\n\ntrans1\n\nHR. Shahih Bukhari No. 1');
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('action cells are 48 dp, outside the app bar, bookmark fills', (
    t,
  ) async {
    await pump(t, 'bukhari', 1);
    final cell = find.ancestor(
      of: find.bySemanticsLabel('Tambah bookmark'),
      matching: find.byType(IconButton),
    );
    expect(t.getSize(cell).height, 48);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.bySemanticsLabel('Salin hadis'),
      ),
      findsNothing,
    );
    await t.tap(cell);
    await t.pump();
    expect(find.bySemanticsLabel('Hapus bookmark'), findsOneWidget);
  });

  testWidgets('prev/next disabled at the ends', (t) async {
    await pump(t, 'bukhari', 1);
    expect(
      t
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Sebelumnya'),
          )
          .onPressed,
      isNull,
    );
    expect(
      t
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Berikutnya'),
          )
          .onPressed,
      isNotNull,
    );
  });

  for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
    testWidgets('hero uses token colors ($mode)', (t) async {
      await pump(t, 'bukhari', 1, mode: mode);
      final colors = t.element(find.byType(HadithDetailView)).nuraColors;
      final hero = t.widget<DecoratedBox>(
        find.byKey(const ValueKey('hadith-hero')),
      );
      expect((hero.decoration as BoxDecoration).color, colors.hero);
      expect(colors, isA<NuraColors>());
    });
  }

  testWidgets('Bukhari No. 3 from data-source scrolls, no overflow, 130%', (
    t,
  ) async {
    final list =
        jsonDecode(File('data-source/hadith/bukhari.json').readAsStringSync())
            as List;
    final arab =
        (list.firstWhere((e) => e['number'] == 3) as Map)['arab'] as String;
    repo.hadith = [_h('bukhari', 3, arab: arab)];
    user.prefs = const ReadingPrefs(arabicFontSize: 40, showTranslation: true);
    await pump(t, 'bukhari', 3, scale: 1.3);
    expect(t.takeException(), isNull);
    final p = t.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(p.maxScrollExtent, greaterThan(0));
    p.jumpTo(p.maxScrollExtent);
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
