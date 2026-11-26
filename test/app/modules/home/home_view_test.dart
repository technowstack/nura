import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/theme/arabic_font.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/widgets/nura_card.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/modules/hadith_detail/hadith_detail_args.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';
import 'package:nura/app/modules/home/home_view.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_daily.dart';
import '../../../support/fake_prayer.dart';
import '../../../support/prayer_harness.dart' show jakarta, api;
import 'package:nura/app/data/repositories/prayer_repository.dart';

void main() {
  late FakeDailyContentRepository repo;
  late FakeDailySettingsStore store;
  Object? routeArgs;
  String? routeName;

  setUp(() {
    Get.reset();
    routeArgs = null;
    routeName = null;
    repo = FakeDailyContentRepository();
    store = FakeDailySettingsStore();
    Get.put<DailyContentRepository>(repo);
    Get.put<DailySettingsStore>(store);
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
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // A fixed clock: the fakes derive their text from the day of the month.
    Get.put(HomeController(now: () => DateTime.utc(2026, 11, 15, 4).toLocal()));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HomeView(),
        getPages: [stub(Routes.surah), stub(Routes.hadithDetail)],
      ),
    );
    await tester.pump();
  }

  // Runs before the framework's pending-timer check, unlike tearDown.
  void tw(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        Get.delete<HomeController>(force: true);
      });

  tw('ayah card above hadith card, labels and references visible', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Ayat hari ini'), findsOneWidget);
    expect(find.text('Hadis hari ini'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Ayat hari ini')).dy,
      lessThan(tester.getTopLeft(find.text('Hadis hari ini')).dy),
    );
    expect(find.text('QS. Asy-Syarh: 15'), findsOneWidget);
    expect(find.text('HR. Bukhari No. 15'), findsOneWidget);
    expect(find.text('Baca selengkapnya'), findsOneWidget);
    expect(find.textContaining('data_version'), findsNothing);
  });

  tw('ayah hidden leaves no gap above the hadith card', (tester) async {
    repo.withAyah = false;
    await pump(tester);
    expect(find.text('Ayat hari ini'), findsNothing);
    final card = find.ancestor(
      of: find.text('Hadis hari ini'),
      matching: find.byType(NuraCard),
    );
    final lastRead = find.ancestor(
      of: find.text('Belum ada bacaan terakhir'),
      matching: find.byType(NuraCard),
    );
    final gap = tester.getTopLeft(card).dy - tester.getBottomLeft(lastRead).dy;
    expect(gap, lessThan(40));
  });

  tw('both empty shows the empty text', (tester) async {
    repo.withAyah = false;
    repo.withHadith = false;
    await pump(tester);
    expect(find.text('Belum ada konten harian'), findsOneWidget);
  });

  tw('error shows retry that recovers', (tester) async {
    repo.failure = const ContentUnavailable('x');
    await pump(tester);
    expect(find.text('Konten harian tidak dapat dibaca'), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    expect(find.text('Hadis hari ini'), findsOneWidget);
  });

  tw('hadith reference and Baca selengkapnya open the detail', (tester) async {
    await pump(tester);
    for (final label in ['HR. Bukhari No. 15', 'Baca selengkapnya']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(routeName, Routes.hadithDetail);
      final args = routeArgs as HadithDetailArgs;
      expect((args.slug, args.number), ('bukhari', 15));
      Get.back<void>();
      await tester.pumpAndSettle();
      routeName = null;
    }
  });

  tw('ayah reference and card open the surah at that ayah', (tester) async {
    await pump(tester);
    for (final target in [
      find.text('QS. Asy-Syarh: 15'),
      find.text('Ayat hari 15'),
    ]) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(routeName, Routes.surah);
      final args = routeArgs as SurahArgs;
      expect((args.surah, args.ayah), (94, 15));
      Get.back<void>();
      await tester.pumpAndSettle();
      routeName = null;
    }
  });

  tw('arabic is rendered right-to-left with the Arabic style', (tester) async {
    await pump(tester);
    final t = tester.widget<Text>(find.text(fakeAyah(15).arab));
    expect(t.textDirection, TextDirection.rtl);
    expect(t.style?.fontFamily, nuraArabicFont);
  });

  tw('tap targets are at least 48dp', (tester) async {
    await pump(tester);
    for (final f in [
      find.widgetWithText(TextButton, 'HR. Bukhari No. 15'),
      find.widgetWithText(TextButton, 'Baca selengkapnya'),
    ]) {
      expect(tester.getSize(f.first).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(f.first).width, greaterThanOrEqualTo(48));
    }
  });

  for (final dark in [false, true]) {
    tw('130% text at 360x640 has no overflow (dark=$dark)', (tester) async {
      await pump(
        tester,
        scale: 1.3,
        theme: dark ? AppTheme.dark : AppTheme.light,
      );
      expect(tester.takeException(), isNull);
    });
  }

  tw('hero shows real prayer times when a schedule exists', (tester) async {
    Get.put<PrayerRepository>(
      FakePrayerRepository(
        region: jakarta,
        days: {'2026-11-15': api('2026-11-15')},
      ),
    );
    await pump(tester);
    await tester.pump();
    expect(find.text('04:30'), findsOneWidget);
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('Dzuhur dalam 50 menit'), findsOneWidget);
  });

  tw('hero shows the honest empty state without a schedule', (tester) async {
    await pump(tester);
    expect(
      find.text('Pilih wilayah untuk melihat jadwal sholat'),
      findsOneWidget,
    );
    expect(find.text('04:30'), findsNothing);
  });
}
