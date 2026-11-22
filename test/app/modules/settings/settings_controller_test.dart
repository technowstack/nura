import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/modules/settings/controllers/settings_controller.dart';
import 'package:nura/app/services/audio_player_service.dart';
import 'package:nura/app/services/notification_scheduler.dart';

import '../../../support/prayer_harness.dart' show api, jakarta;
import '../../../support/settings_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsHarness h;
  late SettingsController c;

  setUp(() async {
    h = SettingsHarness.create();
    c = h.controller();
    await SettingsHarness.settle();
  });

  group('loading', () {
    test('reads the stored values of every store', () async {
      expect(c.state.value, isA<UiData<void>>());
      expect(c.prefs.value.arabicFontSize, 28);
      expect(c.prefs.value.translationFontSize, 15);
      expect(c.audioOn.value, isFalse);
      expect(c.syncOn.value, isFalse);
      expect(c.hadithSource.value, HadithSource.defaultBm);
      expect(c.dailyTime.value, '06:00');
      expect(c.hijriAdjust.value, 0);
      expect(c.region.value, isNull);
    });

    test('a failing store gives the error state; retry recovers', () async {
      Get.delete<SettingsController>(force: true);
      h.user.prefsFailure = StateError('disk');
      final bad = h.controller();
      expect(bad.state.value, isA<UiLoading<void>>());
      await SettingsHarness.settle();
      expect(bad.state.value, isA<UiError<void>>());
      h.user.prefsFailure = null;
      bad.load();
      await SettingsHarness.settle();
      expect(bad.state.value, isA<UiData<void>>());
    });

    test('an unreadable preview hides only the preview', () async {
      Get.delete<SettingsController>(force: true);
      Get.delete<SettingsController>(force: true);
      h.db.setSetting('hijri_adjust', '9'); // invalid reads as 0
      final again = h.controller();
      await SettingsHarness.settle();
      expect(again.hijriAdjust.value, 0);
      expect(again.preview.value, isNotNull);
    });
  });

  group('Tampilan', () {
    test('Arabic and translation sizes and the switch persist', () {
      c.setArabicFontSize(36);
      c.setTranslationFontSize(20);
      c.setShowTranslation(false);
      expect(h.user.prefs.arabicFontSize, 36);
      expect(h.user.prefs.translationFontSize, 20);
      expect(h.user.prefs.showTranslation, isFalse);
      expect(c.prefs.value.translationFontSize, 20);
    });

    test('theme change goes through ThemeController and persists', () {
      c.theme.setMode(ThemeMode.dark);
      expect(h.user.themeMode, ThemeMode.dark);
      expect(c.theme.mode.value, ThemeMode.dark);
    });
  });

  group('Fitur online', () {
    test('switch writes online_enabled; off stops a playing ayah', () async {
      c.setAudioEnabled(true);
      expect(h.db.getSetting('online_enabled'), 'true');
      expect(c.audioOn.value, isTrue);
      await h.player.playAyah(94, 1, 5);
      expect(h.player.state.value, isA<PlaybackPlaying>());
      c.setAudioEnabled(false);
      await SettingsHarness.settle();
      expect(h.db.getSetting('online_enabled'), 'false');
      expect(c.audioOn.value, isFalse);
      expect(h.player.state.value, isA<PlaybackIdle>());
      expect(h.engine.calls, contains('stop'));
    });

    test('qari writes qari_id and the next play uses it', () async {
      c.setAudioEnabled(true);
      c.setQari('03');
      expect(h.db.getSetting('qari_id'), '03');
      expect(c.qariId.value, '03');
      await h.player.playAyah(94, 1, 5);
      expect(h.engine.queues.last.single.path, contains('/q03/'));
    });

    test(
      'sync switch flips the repository gate input, syncs, reschedules',
      () async {
        await c.setSyncEnabled(true);
        expect(h.db.getSetting('prayer_sync_enabled'), 'true');
        expect(h.online.prayerSyncEnabled, isTrue);
        expect(c.syncOn.value, isTrue);
        expect(h.prayer.calls, contains('sync'));
        expect(h.scheduler.log, contains('cancel'));
        await c.setSyncEnabled(false);
        expect(h.online.prayerSyncEnabled, isFalse);
        expect(c.syncOn.value, isFalse);
      },
    );
  });

  group('Jadwal sholat', () {
    test(
      'region is saved through the repository and reminders rescheduled',
      () async {
        await c.selectRegion(jakarta);
        expect(h.prayer.region, jakarta);
        expect(h.prayer.calls, contains('select:${jakarta.key}'));
        expect(c.region.value, jakarta);
        expect(h.scheduler.log, contains('cancel'));
      },
    );

    test('a reminder switch writes notify_* and reschedules', () async {
      await c.setNotify(PrayerName.subuh, true);
      expect(h.prayerStore.on, {PrayerName.subuh});
      expect(c.notifyOn[PrayerName.subuh], isTrue);
      expect(h.scheduler.log, contains('cancel'));
      await c.setNotify(PrayerName.subuh, false);
      expect(h.prayerStore.on, isEmpty);
      expect(c.notifyOn[PrayerName.subuh], isFalse);
    });

    test('permission denied keeps the switch off and shows the note', () async {
      h.scheduler
        ..notif = PermissionState.denied
        ..notifAfterRequest = PermissionState.denied;
      await c.setNotify(PrayerName.dzuhur, true);
      expect(h.prayerStore.on, isEmpty);
      expect(c.notifyOn[PrayerName.dzuhur], isFalse);
      expect(c.notifyDenied.value, isTrue);
    });

    test(
      'all-fail scheduling raises the failed flag, success clears it',
      () async {
        h.prayer.region = jakarta;
        h.prayer.days['2026-11-15'] = api('2026-11-15');
        h.scheduler.failAll = true;
        await c.setNotify(PrayerName.maghrib, true);
        expect(c.remindersFailed.value, isTrue);
        h.scheduler.failAll = false;
        await c.setNotify(PrayerName.maghrib, false);
        expect(c.remindersFailed.value, isFalse);
      },
    );
  });

  group('Harian', () {
    test(
      'source change persists, reschedules and forces a widget refresh',
      () async {
        c.setHadithSource(HadithSource.allBooks);
        await SettingsHarness.settle();
        expect(h.daily.hadithSource, HadithSource.allBooks);
        expect(c.hadithSource.value, HadithSource.allBooks);
        expect(h.scheduler.log, contains('cancelDaily'));
        expect(h.renders, 1);
      },
    );

    test('daily switch schedules seven days and time reschedules', () async {
      await c.setDailyNotify(true);
      expect(h.daily.notifyEnabled, isTrue);
      expect(c.dailyOn.value, isTrue);
      expect(h.scheduler.pending.length, 7);
      h.scheduler.log.clear();
      await c.setDailyTime('07:30');
      expect(h.daily.notifyTime, '07:30');
      expect(c.dailyTime.value, '07:30');
      expect(h.scheduler.log, contains('cancelDaily'));
    });

    test(
      'daily permission denied keeps the switch off with the note',
      () async {
        h.scheduler
          ..notif = PermissionState.denied
          ..notifAfterRequest = PermissionState.denied;
        await c.setDailyNotify(true);
        expect(h.daily.notifyEnabled, isFalse);
        expect(c.dailyOn.value, isFalse);
        expect(c.dailyDenied.value, isTrue);
        expect(h.scheduler.pending, isEmpty);
      },
    );

    test('all-fail flags failed; a later success clears it', () async {
      h.scheduler.failAll = true;
      await c.setDailyNotify(true);
      expect(c.dailyFailed.value, isTrue);
      expect(c.dailyOn.value, isTrue);
      h.scheduler.failAll = false;
      await c.setDailyTime('07:00');
      expect(c.dailyFailed.value, isFalse);
    });

    test('a source change keeps a visible denied note', () async {
      h.scheduler
        ..notif = PermissionState.denied
        ..notifAfterRequest = PermissionState.denied;
      h.daily.notifyEnabled = true;
      Get.delete<SettingsController>(force: true);
      final again = h.controller();
      await SettingsHarness.settle();
      expect(again.dailyDenied.value, isTrue);
      again.setHadithSource(HadithSource.allBooks);
      await SettingsHarness.settle();
      expect(again.dailyDenied.value, isTrue);
    });
  });

  group('Tanggal', () {
    test('adjustment persists and the example follows it', () {
      final base = h.hijri.format(DateTime(2026, 11, 15));
      c.setHijriAdjust(1);
      expect(h.db.getSetting('hijri_adjust'), '1');
      expect(c.hijriAdjust.value, 1);
      expect(c.hijriExample.value, h.hijri.format(DateTime(2026, 11, 15)));
      expect(c.hijriExample.value, isNot(base));
      c.setHijriAdjust(-1);
      expect(c.hijriExample.value, isNot(base));
      c.setHijriAdjust(0);
      expect(c.hijriExample.value, base);
    });
  });
}
