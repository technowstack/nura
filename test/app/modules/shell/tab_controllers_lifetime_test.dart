import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/prayer_clock.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/prayer_regions.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/modules/bookmarks/controllers/bookmarks_controller.dart';
import 'package:nura/app/modules/hadith_list/bindings/hadith_list_binding.dart';
import 'package:nura/app/modules/hadith_list/hadith_list_args.dart';
import 'package:nura/app/modules/hadith_list/views/hadith_list_view.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';
import 'package:nura/app/modules/shell/views/shell_view.dart';
import 'package:nura/app/routes/app_routes.dart';
import 'package:nura/app/services/online_service.dart';

import '../../../support/fake_daily.dart';
import '../../../support/fake_prayer.dart';
import '../../../support/fake_repositories.dart';

void main() {
  setUp(() {
    Get.reset();
    final tmp = Directory.systemTemp.createTempSync('nura_life_');
    final db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(() {
      db.close();
      tmp.deleteSync(recursive: true);
    });
    Get.put<DailyContentRepository>(FakeDailyContentRepository());
    Get.put<DailySettingsStore>(FakeDailySettingsStore());
    Get.put<QuranRepository>(FakeQuranRepository());
    Get.put<UserRepository>(FakeUserRepository());
    Get.put<HadithRepository>(
      FakeHadithRepository(
        summaries: {
          'bukhari': [
            HadithSummary(
              ref: const HadithRef('bukhari', 1),
              preview: 'Isi hadis satu',
              length: 14,
            ),
          ],
        },
      ),
    );
    Get.put<PrayerRepository>(FakePrayerRepository());
    Get.put<PrayerClock>(FakeClock(DateTime.utc(2026, 11, 15)));
    Get.put<PrayerRegions>(PrayerRegions({}));
    Get.put<OnlineService>(OnlineService(db, probe: () async => false));
  });
  tearDown(Get.reset);

  testWidgets('Bookmark tab still works after opening and leaving a pushed '
      'hadith list that returned from detail', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: [
          GetPage(
            name: Routes.home,
            page: () => const ShellView(dataVersion: 'v1'),
          ),
          GetPage(
            name: Routes.hadithList,
            page: HadithListView.new,
            binding: HadithListBinding(),
          ),
          GetPage(
            name: Routes.hadithDetail,
            page: () => const Scaffold(body: Text('stub detail')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    Get.toNamed<void>(
      Routes.hadithList,
      arguments: const HadithListArgs('bukhari', 'Shahih Bukhari'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Isi hadis satu'));
    await tester.pumpAndSettle();
    Get.back<void>(); // detail -> list; _open then resolves BookmarksController
    await tester.pumpAndSettle();
    Get.back<void>(); // list -> home
    await tester.pumpAndSettle();

    await tester.tap(find.text("Al-Qur'an"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmark'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not found'), findsNothing);
    expect(find.text('Belum ada bookmark'), findsOneWidget);
    expect(Get.isRegistered<BookmarksController>(), isTrue);
    Get.delete<HomeController>(force: true);
  });
}
