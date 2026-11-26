import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/prayer_clock.dart';
import 'package:nura/app/data/models/prayer_regions.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/services/online_service.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/shell/views/shell_view.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';
import '../../../support/fake_daily.dart';
import '../../../support/fake_prayer.dart';
import '../../../support/fake_repositories.dart';

void main() {
  setUp(() {
    Get.reset();
    final tmp = Directory.systemTemp.createTempSync('nura_shell_');
    final db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(() {
      db.close();
      tmp.deleteSync(recursive: true);
    });
    Get.put<DailyContentRepository>(FakeDailyContentRepository());
    Get.put<DailySettingsStore>(FakeDailySettingsStore());
    Get.put<QuranRepository>(FakeQuranRepository());
    Get.put<UserRepository>(FakeUserRepository());
    Get.put<HadithRepository>(FakeHadithRepository());
    Get.put<PrayerRepository>(FakePrayerRepository());
    Get.put<PrayerClock>(FakeClock(DateTime.utc(2026, 11, 15)));
    Get.put<PrayerRegions>(PrayerRegions({}));
    Get.put<OnlineService>(OnlineService(db, probe: () async => false));
  });
  tearDown(Get.reset);

  const shell = MaterialApp(home: ShellView());

  testWidgets('has five labelled destinations and Hadis shows the book list', (
    tester,
  ) async {
    await tester.pumpWidget(shell);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    for (final l in ['Beranda', "Al-Qur'an", 'Hadis', 'Sholat', 'Setelan']) {
      expect(
        find.descendant(of: find.byType(NavigationBar), matching: find.text(l)),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('Hadis'));
    await tester.pumpAndSettle();
    expect(find.text('Segera hadir'), findsNothing);
    expect(find.text('Daftar kitab belum tersedia'), findsOneWidget);
    await tester.tap(find.text('Sholat'));
    await tester.pumpAndSettle();
    expect(
      find.text('Pilih wilayah untuk melihat jadwal sholat'),
      findsOneWidget,
    );
    // Cancels the midnight timer before the pending-timer check.
    Get.delete<HomeController>(force: true);
  });

  testWidgets('Latin 130% at 360x640 does not throw', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: shell,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sholat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Get.delete<HomeController>(force: true);
  });
}
