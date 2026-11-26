import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/repositories/default_prayer_repository.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/modules/onboarding/controllers/onboarding_controller.dart';
import 'package:nura/app/modules/settings/controllers/settings_controller.dart';
import 'package:nura/app/services/notification_scheduler.dart';

import '../../../support/fake_prayer.dart';
import '../../../support/prayer_harness.dart' show jakarta;
import '../../../support/settings_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsHarness h;
  late OnboardingController c;

  OnboardingController make() {
    Get.put<UserDatabase>(h.db);
    return Get.put(OnboardingController());
  }

  setUp(() async {
    h = SettingsHarness.create();
    c = make();
    await SettingsHarness.settle();
  });

  test('loads the stored values', () {
    expect(c.state.value, isA<UiData<void>>());
    expect(c.step.value, 0);
    expect(c.region.value, isNull);
    expect(c.syncOn.value, isTrue);
    expect(h.db.getSetting('prayer_sync_enabled'), isNull);
    expect(c.prayerOn.value, isFalse);
    expect(c.dailyOn.value, isFalse);
    expect(c.dailyTime.value, '06:00');
  });

  test('a failing store gives the error state; retry recovers', () async {
    Get.delete<OnboardingController>(force: true);
    final broken = _ThrowingRegion();
    Get.replace<PrayerRepository>(broken);
    final bad = Get.put(OnboardingController());
    await SettingsHarness.settle();
    expect(bad.state.value, isA<UiError<void>>());
    broken.fail = false;
    bad.load();
    await SettingsHarness.settle();
    expect(bad.state.value, isA<UiData<void>>());
  });

  test('steps go a, b, c with Lanjut/Kembali, bounded at both ends', () {
    c.back();
    expect(c.step.value, 0);
    c.next();
    c.next();
    expect(c.step.value, 2);
    expect(c.isLast, isTrue);
    c.next();
    expect(c.step.value, 2);
    c.back();
    expect(c.step.value, 1);
  });

  test('onboarding_done is written only by finish()', () async {
    Get.testMode = true; // finish() navigates
    c.next();
    c.next();
    c.selectRegion(jakarta);
    c.setSyncEnabled(true);
    await c.setPrayerReminders(true);
    expect(h.db.getSetting('onboarding_done'), isNull);
    c.finish();
    expect(h.db.getSetting('onboarding_done'), 'true');
  });

  group('download switch (default on, written on Lanjut)', () {
    late FakePrayerApi api;

    Future<OnboardingController> fresh() async {
      Get.delete<OnboardingController>(force: true);
      final x = make();
      await SettingsHarness.settle();
      return x;
    }

    setUp(() async {
      api = FakePrayerApi((r, y, m) async => monthDays(y, m));
      Get.replace<PrayerRepository>(
        DefaultPrayerRepository(
          store: h.prayerStore,
          api: api,
          online: h.online,
          clock: FakeClock(DateTime.utc(2026, 11, 15, 3)),
          calculator: FakeCalculator(),
          coordinates: FixedCoordinates(),
        ),
      );
      c = await fresh();
      c.next(); // step 2
    });

    String? stored() => h.db.getSetting('prayer_sync_enabled');

    Future<void> lanjut() async {
      c.next();
      await SettingsHarness.settle();
    }

    test('shows on; region and toggles send and store nothing', () async {
      expect(c.syncOn.value, isTrue);
      c.selectRegion(jakarta);
      c.setSyncEnabled(false);
      c.setSyncEnabled(true);
      await c.setPrayerReminders(true);
      await c.setDailyNotify(true);
      expect(stored(), isNull);
      expect(api.calls, isEmpty);
    });

    test('Lanjut with it on stores true and syncs once', () async {
      c.selectRegion(jakarta);
      await lanjut();
      expect(stored(), 'true');
      expect(api.calls, hasLength(2)); // this month and the next
      expect(h.db.getSetting('online_enabled'), isNull);
    });

    test('Lanjut without a region only stores the switch', () async {
      await lanjut();
      expect(stored(), 'true');
      expect(api.calls, isEmpty);
    });

    test('off then Lanjut stores false and never calls', () async {
      c.selectRegion(jakarta);
      c.setSyncEnabled(false);
      await lanjut();
      expect(stored(), 'false');
      expect(api.calls, isEmpty);
      expect(h.db.getSetting('online_enabled'), isNull);
    });

    test('Kembali or closing the app on step 2 stores nothing', () async {
      c.selectRegion(jakarta);
      c.back();
      await SettingsHarness.settle();
      expect(stored(), isNull);
      c = await fresh(); // restart
      expect(c.syncOn.value, isTrue);
      expect(stored(), isNull);
      expect(api.calls, isEmpty);
    });

    test('going back to step 2 shows the last choice', () async {
      c.setSyncEnabled(false);
      c.back();
      c.next();
      expect(c.syncOn.value, isFalse);
      await lanjut();
      c.back();
      expect(c.syncOn.value, isFalse);
    });

    for (final value in ['true', 'false']) {
      test('a stored $value is shown and kept', () async {
        h.db.setSetting('prayer_sync_enabled', value);
        c = await fresh();
        expect(c.syncOn.value, value == 'true');
        c.next();
        await lanjut();
        expect(stored(), value);
      });
    }

    test('a stored true does not sync a region before Lanjut', () async {
      h.db.setSetting('prayer_sync_enabled', 'true');
      c = await fresh();
      c.next();
      c.selectRegion(jakarta);
      expect(api.calls, isEmpty);
    });
  });

  test('region is saved through the shared repository', () async {
    c.selectRegion(jakarta);
    expect(c.region.value, jakarta);
    expect(h.prayer.region, jakarta);
    expect(h.prayer.calls, isNot(contains('sync')));
  });

  group('notification step', () {
    test('no permission request until a switch is turned on', () {
      expect(h.scheduler.log, isNot(contains('requestNotif')));
    });

    test('Pengingat adzan enables all five and asks permission', () async {
      h.scheduler.notif = PermissionState.denied;
      await c.setPrayerReminders(true);
      expect(h.scheduler.log, contains('requestNotif'));
      expect(c.prayerOn.value, isTrue);
      expect(c.denied.value, isFalse);
      for (final p in PrayerName.values) {
        expect(h.prayerNotifier.isEnabled(p), isTrue);
      }
      await c.setPrayerReminders(false);
      expect(c.prayerOn.value, isFalse);
    });

    test('denied leaves the switch off with the note; retry works', () async {
      h.scheduler.notif = PermissionState.denied;
      h.scheduler.notifAfterRequest = PermissionState.denied;
      await c.setPrayerReminders(true);
      expect(c.prayerOn.value, isFalse);
      expect(c.denied.value, isTrue);
      h.scheduler.notifAfterRequest = PermissionState.granted;
      await c.setPrayerReminders(true);
      expect(c.prayerOn.value, isTrue);
      expect(c.denied.value, isFalse);
    });

    test('daily switch: default 06:00, denied keeps it off', () async {
      h.scheduler.notif = PermissionState.denied;
      h.scheduler.notifAfterRequest = PermissionState.denied;
      await c.setDailyNotify(true);
      expect(c.dailyOn.value, isFalse);
      expect(c.denied.value, isTrue);
      h.scheduler.notifAfterRequest = PermissionState.granted;
      await c.setDailyNotify(true);
      expect(c.dailyOn.value, isTrue);
      expect(c.dailyTime.value, '06:00');
    });
  });

  test(
    'choices are the same state Settings reads; a restart keeps them',
    () async {
      c.next();
      c.selectRegion(jakarta);
      c.next(); // leaves step 2: stores the switch
      await c.setPrayerReminders(true);
      await c.setDailyNotify(true);

      final s = h.controller();
      await SettingsHarness.settle();
      expect(s, isA<SettingsController>());
      expect(s.region.value, jakarta);
      expect(s.syncOn.value, isTrue);
      expect(s.dailyOn.value, isTrue);
      expect(s.notifyOn.values.every((v) => v), isTrue);

      Get.delete<OnboardingController>(force: true);
      final again = Get.put(OnboardingController());
      await SettingsHarness.settle();
      expect(again.step.value, 0);
      expect(again.region.value, jakarta);
      expect(again.syncOn.value, isTrue);
      expect(again.prayerOn.value, isTrue);
      expect(again.dailyOn.value, isTrue);
      expect(h.db.getSetting('onboarding_done'), isNull);
    },
  );
}

class _ThrowingRegion extends FakePrayerRepository {
  @override
  PrayerRegion? get region => fail ? throw StateError('disk') : null;

  bool fail = true;
}
