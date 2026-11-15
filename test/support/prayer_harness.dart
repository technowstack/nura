import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/prayer_clock.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/models/prayer_regions.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/modules/prayer/controllers/prayer_controller.dart';
import 'package:nura/app/modules/shell/controllers/shell_controller.dart';
import 'package:nura/app/services/online_service.dart';
import 'fake_prayer.dart';

const jakarta = PrayerRegion(
  provinsi: 'DKI Jakarta',
  kabkota: 'Kota Jakarta',
  zone: PrayerZone.wib,
);
const makassar = PrayerRegion(
  provinsi: 'Sulawesi Selatan',
  kabkota: 'Kota Makassar',
  zone: PrayerZone.wita,
);
const jayapura = PrayerRegion(
  provinsi: 'Papua',
  kabkota: 'Kota Jayapura',
  zone: PrayerZone.wit,
);

DayResult api(String date, {String? dhuha = '05:50'}) =>
    DayResult(DayOutcome.api, fullDay(date, dhuha: dhuha));

class Harness {
  Harness(this.repo, this.clock, this.db);

  final FakePrayerRepository repo;
  final FakeClock clock;
  final UserDatabase db;

  PrayerController get c => Get.find<PrayerController>();
  PrayerScreen get screen => ((c.screen.value) as UiData<PrayerScreen>).value;
}

Harness setup(
  WidgetTester tester, {
  required PrayerRegion? region,
  required DateTime now,
  Map<String, DayResult> days = const {},
  ShellController? shell,
}) {
  Get.reset();
  final tmp = Directory.systemTemp.createTempSync('nura_prayer_');
  final db = UserDatabase.open(File('${tmp.path}/user.db'));
  addTearDown(() {
    Get.delete<PrayerController>(force: true);
    db.close();
    tmp.deleteSync(recursive: true);
    Get.reset();
  });
  final repo = FakePrayerRepository(region: region, days: {...days});
  final clock = FakeClock(now);
  Get.put<PrayerRepository>(repo);
  Get.put<PrayerClock>(clock);
  Get.put<OnlineService>(OnlineService(db, probe: () async => true));
  Get.put<PrayerRegions>(
    PrayerRegions({
      'DKI Jakarta': ['Kota Jakarta'],
    }),
  );
  if (shell != null) Get.put<ShellController>(shell);
  Get.put<PrayerController>(PrayerController());
  return Harness(repo, clock, db);
}

/// Like testWidgets, but closes the controller (cancelling its timer) before
/// the framework checks for pending timers.
void tp(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) async {
      await body(tester);
      Get.delete<PrayerController>(force: true);
    });
