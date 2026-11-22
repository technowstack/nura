import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nura/app/core/widgets/nura_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/nura_icons.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/nura_colors.dart';
import 'package:nura/app/core/theme/tokens.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/last_read.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';
import 'package:nura/app/modules/home/home_view.dart';
import 'package:nura/app/modules/home/widgets/hero_silhouette.dart';
import 'package:nura/app/modules/home/widgets/home_hero.dart';
import 'package:nura/app/modules/home/widgets/home_hero_data.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/routes/app_routes.dart';
import 'package:nura/app/services/hijri_date_service.dart';

import '../../../support/fake_daily.dart';
import '../../../support/fake_repositories.dart';

const _surah = Surah(
  number: 2,
  nameArab: 'البقرة',
  nameLatin: 'Al-Baqarah',
  nameId: 'Sapi',
  ayahCount: 286,
  revelation: 'madaniyah',
);

const _times = [
  HeroPrayerTime(name: 'Subuh', time: '04:06', icon: NuraIcons.schedule),
  HeroPrayerTime(name: 'Terbit', time: '05:24', icon: NuraIcons.schedule),
  HeroPrayerTime(name: 'Dzuhur', time: '11:36', icon: NuraIcons.schedule),
  HeroPrayerTime(name: 'Ashar', time: '14:55', icon: NuraIcons.schedule),
  HeroPrayerTime(name: 'Maghrib', time: '17:44', icon: NuraIcons.schedule),
  HeroPrayerTime(name: 'Isya', time: '18:55', icon: NuraIcons.schedule),
];

class _Recorder implements Canvas {
  final paints = <Paint>[];

  @override
  dynamic noSuchMethod(Invocation i) {
    for (final a in i.positionalArguments) {
      if (a is Paint) paints.add(a);
    }
    return null;
  }
}

void main() {
  late FakeUserRepository user;
  late UserDatabase db;
  late HijriDateService hijri;
  String? routeName;
  Object? routeArgs;

  setUp(() {
    Get.reset();
    routeName = null;
    routeArgs = null;
    final tmp = Directory.systemTemp.createTempSync('nura_hero_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    hijri = HijriDateService(user: db);
    user = FakeUserRepository();
    Get.put<DailyContentRepository>(FakeDailyContentRepository());
    Get.put<DailySettingsStore>(FakeDailySettingsStore());
    Get.put<UserRepository>(user);
    Get.put<QuranRepository>(FakeQuranRepository(surahs: [_surah]));
    Get.put<HijriDateService>(hijri);
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

  Future<void> pumpApp(
    WidgetTester tester, {
    double scale = 1,
    ThemeData? theme,
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (home == null) {
      Get.put(HomeController(now: () => DateTime(2026, 11, 15, 9, 5)));
    }
    await tester.pumpWidget(
      GetMaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: home ?? const HomeView(dataVersion: 'v1'),
        getPages: [
          stub(Routes.surah),
          stub(Routes.search),
          stub(Routes.settings),
        ],
      ),
    );
    await tester.pump();
  }

  void tw(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        Get.delete<HomeController>(force: true);
      });

  const data = HomeHeroData(
    locationLabel: 'Sampang',
    hijriDate: '28 Jumadilawal 1448 H',
    clock: '17:17',
    countdownLabel: 'Maghrib dalam ',
    countdownDuration: '27 menit',
    times: _times,
    nextIndex: 4,
    approximate: true,
  );

  Widget hero(HomeHeroData d) => Scaffold(
    body: HomeHero(data: d),
  );

  for (final (dark, colors) in [
    (false, NuraColors.light),
    (true, NuraColors.dark),
  ]) {
    tw('hero uses tokens and marks next time (dark=$dark)', (tester) async {
      await pumpApp(
        tester,
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: hero(data),
      );
      final box = tester.widget<Container>(find.byType(Container).first);
      expect(box.color, colors.hero);
      expect(
        tester.widget<Text>(find.text('17:17')).style?.color,
        colors.onHero,
      );
      expect(
        tester.widget<Text>(find.text('17:44')).style?.color,
        colors.onHeroAccent,
      );
      expect(
        tester.widget<Text>(find.text('04:06')).style?.color,
        colors.onHero,
      );
      final cd = tester.widget<Text>(find.text('Maghrib dalam 27 menit'));
      final root = cd.textSpan! as TextSpan;
      expect(root.text, 'Maghrib dalam ');
      expect(root.style?.color, colors.onHero);
      final dur = root.children!.single as TextSpan;
      expect(dur.text, '27 menit');
      expect(dur.style?.color, colors.onHeroAccent);
      expect(find.byKey(const Key('hero-next-dot')), findsOneWidget);
      expect(find.text('Jadwal perkiraan, dihitung offline'), findsOneWidget);
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<HeroSilhouettePainter>()
          .single;
      final rec = _Recorder();
      painter.paint(rec as Canvas, const Size(360, 110));
      expect(rec.paints, isNotEmpty);
      for (final paint in rec.paints) {
        expect(paint.color.toARGB32(), colors.heroShape.toARGB32());
        expect(paint.shader, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  tw('empty times show the honest line and no digits', (tester) async {
    await pumpApp(
      tester,
      home: hero(
        const HomeHeroData(
          locationLabel: 'Pilih wilayah',
          hijriDate: '',
          clock: '09:05',
          emptyText: 'Pilih wilayah untuk melihat jadwal sholat',
        ),
      ),
    );
    expect(
      find.text('Pilih wilayah untuk melihat jadwal sholat'),
      findsOneWidget,
    );
    expect(find.text('Subuh'), findsNothing);
    expect(find.byKey(const Key('hero-next-dot')), findsNothing);
    expect(find.textContaining(RegExp(r'\d\d:\d\d')), findsOneWidget);
  });

  tw('sheet cap overlaps hero by 24 with xl radius; body follows', (
    tester,
  ) async {
    await pumpApp(tester);
    final heroRect = tester.getRect(find.byType(HomeHero));
    final cap = find.byKey(const Key('home-sheet-cap'));
    expect(tester.getSize(cap).height, NuraSpace.s24);
    expect(tester.getRect(cap).bottom, heroRect.bottom);
    final deco = tester.widget<DecoratedBox>(cap).decoration as BoxDecoration;
    expect(
      deco.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(NuraRadius.xl)),
    );
    // No dead scroll space: the body starts exactly where the hero ends.
    expect(
      tester.getTopLeft(find.byKey(const Key('home-sheet'))).dy,
      heroRect.bottom,
    );
    expect(heroRect.top, 0);
  });

  tw('top edge of the last read card is tappable', (tester) async {
    user.lastRead = LastRead(
      ref: const AyahRef(2, 3),
      updatedAt: DateTime(2026),
    );
    await pumpApp(tester);
    final card = tester.getRect(
      find.ancestor(
        of: find.text('Lanjutkan'),
        matching: find.byType(NuraCard),
      ),
    );
    final hit = tester.hitTestOnBinding(card.topCenter + const Offset(0, 2));
    expect(
      hit.path.any(
        (e) =>
            e.target is RenderBox && (e.target as RenderBox).size == card.size,
      ),
      isTrue,
    );
  });

  tw('status bar icons are light and the page has a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const Key('home-overlay')),
    );
    expect(region.value.statusBarColor, Colors.transparent);
    expect(
      region.value.statusBarIconBrightness,
      SystemUiOverlayStyle.light.statusBarIconBrightness,
    );
    final node = tester.getSemantics(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Beranda',
      ),
    );
    expect(node.getSemanticsData().flagsCollection.isHeader, isTrue);
    // Only a tiny node is the heading, not the whole hero block.
    expect(node.rect.size, const Size(1, 1));
    final hero = tester.getSemantics(find.byKey(const Key('home-hero')));
    expect(hero.getSemanticsData().flagsCollection.isHeader, isFalse);
    handle.dispose();
  });

  tw('countdown reads as one sentence once', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, home: hero(data));
    final label = tester.getSemantics(find.byKey(const Key('home-hero'))).label;
    expect('Maghrib dalam 27 menit'.allMatches(label), hasLength(1));
    handle.dispose();
  });

  tw('six real times at 130% on 360x640 have no overflow', (tester) async {
    await pumpApp(tester, scale: 1.3, home: hero(data));
    expect(tester.takeException(), isNull);
    expect(find.text('18:55'), findsOneWidget);
  });

  tw('last read empty shows a message and no button', (tester) async {
    await pumpApp(tester);
    expect(find.text('Belum ada bacaan terakhir'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsNothing);
  });

  tw('last read filled continues to the surah at that ayah', (tester) async {
    user.lastRead = LastRead(
      ref: const AyahRef(2, 3),
      updatedAt: DateTime(2026),
    );
    await pumpApp(tester);
    expect(find.text('QS. Al-Baqarah: 3'), findsOneWidget);
    expect(find.text('البقرة'), findsOneWidget);
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();
    expect(routeName, Routes.surah);
    final args = routeArgs as SurahArgs;
    expect((args.surah, args.ayah), (2, 3));
  });

  tw('hijri date follows the adjustment; clock is the device time', (
    tester,
  ) async {
    hijri.adjustDays = 1;
    final expected = hijri.format(DateTime(2026, 11, 15));
    await pumpApp(tester);
    expect(find.text(expected), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
    hijri.adjustDays = 0;
    expect(hijri.format(DateTime(2026, 11, 15)), isNot(expected));
  });

  tw('hero has no settings icon (it is a bottom tab); search opens search', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byTooltip('Pengaturan'), findsNothing);
    expect(find.byTooltip('Pengaturan harian'), findsNothing);
    await tester.tap(find.byTooltip('Cari'));
    await tester.pumpAndSettle();
    expect(routeName, Routes.search);
  });

  tw('whole page scrolls as one at 130% text (360x640)', (tester) async {
    await pumpApp(tester, scale: 1.3);
    expect(tester.takeException(), isNull);
    final before = tester.getTopLeft(find.byType(HomeHero)).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(HomeHero)).dy, lessThan(before));
    expect(tester.takeException(), isNull);
  });
}
