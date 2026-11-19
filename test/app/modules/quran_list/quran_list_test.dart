import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/icon_finders.dart';
import 'package:nura/app/core/nura_icons.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/nura_colors.dart';
import 'package:nura/app/core/theme/nura_text_styles.dart';
import 'package:nura/app/core/widgets/nura_card.dart';
import 'package:nura/app/core/widgets/ornament_badge.dart';
import 'package:nura/app/modules/quran_list/widgets/surah_list_item.dart';
import 'package:nura/app/core/widgets/empty_state.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/juz.dart';
import 'package:nura/app/data/models/last_read.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/modules/quran_list/bindings/quran_list_binding.dart';
import 'package:nura/app/modules/quran_list/controllers/quran_list_controller.dart';
import 'package:nura/app/modules/quran_list/views/quran_list_view.dart';
import 'package:nura/app/modules/search/search_args.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';

Surah _s(int n, String rev, {int ayat = 7}) => Surah(
  number: n,
  nameArab: 'ArabSurah$n',
  nameLatin: 'Latin$n',
  nameId: 'Arti$n',
  ayahCount: ayat,
  revelation: rev,
);

void main() {
  late FakeQuranRepository quran;
  late FakeUserRepository user;
  Object? routeArgs;

  setUp(() {
    Get.reset();
    routeArgs = null;
    quran = FakeQuranRepository(
      surahs: [_s(1, 'makkiyah'), _s(2, 'madaniyah'), _s(3, ''), _s(4, 'x')],
      juz: const [
        Juz(number: 1, startSurah: 1, startAyah: 1, endSurah: 1, endAyah: 7),
      ],
    );
    user = FakeUserRepository();
    Get.put<QuranRepository>(quran);
    Get.put<UserRepository>(user);
    Get.put<HadithRepository>(FakeHadithRepository());
    QuranListBinding().dependencies();
  });
  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: QuranListView()),
        getPages: [
          GetPage(
            name: Routes.surah,
            page: () {
              routeArgs = Get.arguments;
              return const Scaffold(body: Text('stub surah'));
            },
          ),
          GetPage(
            name: Routes.search,
            page: () {
              routeArgs = Get.arguments;
              return const Scaffold(body: Text('stub search'));
            },
          ),
        ],
      ),
    );
  }

  testWidgets('shows loading before data, then surah rows', (tester) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Latin1'), findsOneWidget);
    expect(find.text('Arti1'), findsOneWidget);
    expect(find.text('7 ayat'), findsWidgets);
    expect(find.text('ArabSurah1'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('revelation labels', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Makkiyah'), findsOneWidget);
    expect(find.text('Madaniyah'), findsOneWidget);
    expect(find.text('x'), findsNothing);
  });

  testWidgets('last read and bookmarked states', (tester) async {
    user.lastRead = LastRead(
      ref: const AyahRef(1, 3),
      updatedAt: DateTime(2000),
    );
    user.bookmarkedSurahs = {1, 2};
    final handle = tester.ensureSemantics();
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Terakhir dibaca'), findsOneWidget);
    expect(find.byIcon(NuraIcons.history), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.semanticLabel == 'Ditandai bookmark',
      ),
      findsOneWidget,
    );
    expect(bookmarkIcon(filled: true), findsOneWidget);
    handle.dispose();
  });

  testWidgets('error shows retry that reloads', (tester) async {
    quran.failure = const ContentUnavailable('x');
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsOneWidget);
    quran.failure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Latin1'), findsOneWidget);
  });

  testWidgets('juz tab: empty state', (tester) async {
    quran.juz = [];
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juz'));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Daftar juz belum tersedia'), findsOneWidget);
  });

  testWidgets('juz tab: number and range', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juz'));
    await tester.pumpAndSettle();
    expect(find.text('Juz 1'), findsOneWidget);
    expect(find.text('1:1 – 1:7'), findsOneWidget);
  });

  testWidgets('tapping surah opens route with SurahArgs', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latin2'));
    await tester.pumpAndSettle();
    expect(routeArgs, isA<SurahArgs>());
    expect((routeArgs as SurahArgs).surah, 2);
    expect((routeArgs as SurahArgs).ayah, 0);
  });

  testWidgets('markers update when observables change after first pump', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byIcon(NuraIcons.history), findsNothing);
    final c = Get.find<QuranListController>();
    c.lastReadSurah.value = 2;
    c.bookmarkedSurahs.add(1);
    await tester.pumpAndSettle();
    expect(find.byIcon(NuraIcons.history), findsOneWidget);
    expect(bookmarkIcon(filled: true), findsOneWidget);
  });

  testWidgets('returning from surah page refreshes markers', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latin2'));
    await tester.pumpAndSettle();
    user.lastRead = LastRead(
      ref: const AyahRef(2, 1),
      updatedAt: DateTime(2000),
    );
    user.bookmarkedSurahs = {1};
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.byIcon(NuraIcons.history), findsOneWidget);
    expect(bookmarkIcon(filled: true), findsOneWidget);
  });

  testWidgets('tapping juz row opens route with start surah and ayah', (
    tester,
  ) async {
    quran.juz = const [
      Juz(number: 2, startSurah: 2, startAyah: 142, endSurah: 2, endAyah: 252),
    ];
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Juz 2'));
    await tester.pumpAndSettle();
    final args = routeArgs as SurahArgs;
    expect(args.surah, 2);
    expect(args.ayah, 142);
  });

  for (final tab in ['Surah', 'Juz']) {
    testWidgets('Latin 130% on $tab tab at 360x640', (tester) async {
      user.lastRead = LastRead(
        ref: const AyahRef(1, 3),
        updatedAt: DateTime(2000),
      );
      await pump(tester, scale: 1.3);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('user.db failure leaves markers untouched, no exception', (
    tester,
  ) async {
    user.failure = StateError('x');
    await pump(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Latin1'), findsOneWidget);
    expect(Get.find<QuranListController>().lastReadSurah.value, 0);
  });

  testWidgets('returning from surah reloads bookmarks even if markers fail', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();
    user.failure = StateError('x');
    await tester.tap(find.text('Latin1'));
    await tester.pumpAndSettle();
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('search icon opens search with quran scope', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cari'));
    await tester.pumpAndSettle();
    expect(find.text('stub search'), findsOneWidget);
    expect((routeArgs as SearchArgs).scope, SearchScope.quran);
  });

  group('restyle', () {
    testWidgets('surah item is a NuraCard with badge and token colors', (
      tester,
    ) async {
      user.lastRead = LastRead(
        ref: const AyahRef(1, 3),
        updatedAt: DateTime(2000),
      );
      await pump(tester);
      await tester.pumpAndSettle();
      expect(find.byType(NuraCard), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(NuraCard).first,
          matching: find.byType(OrnamentBadge),
        ),
        findsOneWidget,
      );
      final arab = tester.widget<Text>(find.text('ArabSurah1'));
      expect(arab.style?.color, NuraColors.light.iconAccent);
      final card = tester.widget<NuraCard>(
        find.ancestor(of: find.text('Latin1'), matching: find.byType(NuraCard)),
      );
      expect(card.color, NuraColors.light.lastReadHighlight);
      final other = tester.widget<NuraCard>(
        find.ancestor(of: find.text('Latin2'), matching: find.byType(NuraCard)),
      );
      expect(other.color, isNull);
    });

    testWidgets('juz item has badge and chevron', (tester) async {
      await pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juz'));
      await tester.pumpAndSettle();
      expect(find.byType(OrnamentBadge), findsOneWidget);
      expect(find.byIcon(NuraIcons.chevronRight), findsOneWidget);
    });

    testWidgets('dark arabic color and 2px primary tab indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: SurahListItem(
              surah: _s(1, 'makkiyah'),
              state: SurahItemState.normal,
              onTap: () {},
            ),
          ),
        ),
      );
      final arab = tester.widget<Text>(find.text('ArabSurah1'));
      expect(arab.style?.color, NuraColors.dark.iconAccent);
      final tb = AppTheme.light.tabBarTheme;
      expect(tb.labelColor, AppTheme.light.colorScheme.primary);
      final ind = tb.indicator as UnderlineTabIndicator;
      expect(ind.borderSide.width, 2);
      expect(ind.borderSide.color, AppTheme.light.colorScheme.primary);
    });

    testWidgets('arabic size 36 at 130% no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: Theme(
              data: AppTheme.light.copyWith(
                extensions: [
                  NuraColors.light,
                  NuraTextStyles.standard.copyWith(
                    arabicTitle: NuraTextStyles.standard.arabicTitle.copyWith(
                      fontSize: 36,
                    ),
                  ),
                ],
              ),
              child: SurahListItem(
                surah: _s(3, 'madaniyah', ayat: 200),
                state: SurahItemState.bookmarked,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
