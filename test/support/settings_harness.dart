import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/prayer_clock.dart';
import 'package:nura/app/core/theme/theme_controller.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/prayer_regions.dart';
import 'package:nura/app/data/models/qari.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/audio_settings_store.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/repositories/prayer_store.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/sqlite_audio_settings_store.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/data/sources/audio_api_client.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/modules/settings/controllers/settings_controller.dart';
import 'package:nura/app/services/audio_player_service.dart';
import 'package:nura/app/services/daily_notifier.dart';
import 'package:nura/app/services/daily_refresher.dart';
import 'package:nura/app/services/hijri_date_service.dart';
import 'package:nura/app/services/notification_scheduler.dart';
import 'package:nura/app/services/online_service.dart';
import 'package:nura/app/services/prayer_notifier.dart';

import 'fake_audio.dart';
import 'fake_daily.dart';
import 'fake_notifications.dart';
import 'fake_prayer.dart';
import 'fake_repositories.dart';

String _audioBody(int surah, int n) {
  String url(String q, int i) =>
      'https://cdn.equran.id/audio-partial/q$q/${surah.toString().padLeft(3, '0')}${i.toString().padLeft(3, '0')}.mp3';
  final ayat = [
    for (var i = 1; i <= n; i++)
      '{"nomorAyat":$i,"audio":{${[for (final q in kQaris) '"${q.id}":"${url(q.id, i)}"'].join(',')}}}',
  ];
  return '{"data":{"nomor":$surah,"ayat":[${ayat.join(',')}]}}';
}

/// Every service Settings talks to, backed by fakes (a real user.db only for
/// the services that need one).
class SettingsHarness {
  SettingsHarness._();

  late final Directory tmp;
  late final UserDatabase db;
  late final FakeUserRepository user;
  late final OnlineService online;
  late final AudioSettingsStore audioStore;
  late final FakeAudioEngine engine;
  late final AudioPlayerService player;
  late final FakePrayerRepository prayer;
  late final MemoryPrayerStore prayerStore;
  late final ThrowingScheduler scheduler;
  late final PrayerNotifier prayerNotifier;
  late final FakeDailySettingsStore daily;
  late final DailyNotifier dailyNotifier;
  late final HijriDateService hijri;
  late final ThemeController theme;
  int renders = 0;

  static const regions = {
    'DKI Jakarta': ['Kota Jakarta'],
    'Sulawesi Selatan': ['Kota Makassar'],
  };

  /// Registers everything in GetX (after a reset). Call from `setUp`.
  static SettingsHarness create() {
    Get.reset();
    final h = SettingsHarness._();
    h.tmp = Directory.systemTemp.createTempSync('nura_settings_');
    h.db = UserDatabase.open(File('${h.tmp.path}/user.db'));
    addTearDown(() {
      Get.reset();
      h.db.close();
      h.tmp.deleteSync(recursive: true);
    });
    h.user = FakeUserRepository();
    h.online = OnlineService(h.db, probe: () async => true);
    h.audioStore = SqliteAudioSettingsStore(h.db);
    h.engine = FakeAudioEngine();
    h.player = AudioPlayerService(
      h.online,
      AudioApiClient((uri, {jsonBody}) async {
        final s = int.parse(uri.pathSegments.last);
        return (status: 200, body: _audioBody(s, 5));
      }),
      h.audioStore,
      h.engine,
      // Never the platform connectivity channel (hangs in widget tests).
      connectivity: const Stream<bool>.empty(),
    );
    h.prayer = FakePrayerRepository();
    h.prayerStore = MemoryPrayerStore();
    h.scheduler = ThrowingScheduler();
    final clock = FakeClock(DateTime.utc(2026, 11, 15, 3));
    h.prayerNotifier = PrayerNotifier(
      scheduler: h.scheduler,
      repository: h.prayer,
      store: h.prayerStore,
      clock: clock,
    );
    h.daily = FakeDailySettingsStore();
    final dailyRepo = FakeDailyContentRepository();
    h.dailyNotifier = DailyNotifier(
      scheduler: h.scheduler,
      repository: dailyRepo,
      store: h.daily,
      now: () => DateTime(2026, 11, 15, 5),
    );
    h.hijri = HijriDateService(user: h.db);
    Get.put<UserRepository>(h.user);
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: const [
          Surah(
            number: 1,
            nameArab: 'a',
            nameLatin: 'Al-Fatihah',
            nameId: 'x',
            ayahCount: 1,
            revelation: 'makkiyah',
          ),
        ],
        ayahs: const [
          Ayah(
            surahNumber: 1,
            ayahNumber: 1,
            arab: 'بِسْمِ ٱللَّهِ',
            translation: 'Dengan nama Allah',
            tafsir: 't',
          ),
        ],
      ),
    );
    Get.put<OnlineService>(h.online);
    Get.put<AudioSettingsStore>(h.audioStore);
    Get.put<AudioPlayerService>(h.player);
    Get.put<PrayerRepository>(h.prayer);
    Get.put<PrayerStore>(h.prayerStore);
    Get.put<PrayerClock>(clock);
    Get.put<PrayerNotifier>(h.prayerNotifier);
    Get.put<NotificationScheduler>(h.scheduler);
    Get.put<DailyContentRepository>(dailyRepo);
    Get.put<DailySettingsStore>(h.daily);
    Get.put<DailyNotifier>(h.dailyNotifier);
    Get.put<DailyRefresher>(
      DailyRefresher(
        renderWidgets: () async {
          h.renders++;
          return true;
        },
        reschedule: h.dailyNotifier.reschedule,
        now: () => DateTime(2026, 11, 15, 5),
      ),
    );
    Get.put<HijriDateService>(h.hijri);
    Get.put<PrayerRegions>(PrayerRegions({...regions}));
    h.theme = Get.put(ThemeController());
    return h;
  }

  /// A fresh controller (loads in a microtask; pump or await [settle]).
  SettingsController controller() =>
      Get.put(SettingsController(now: () => DateTime(2026, 11, 15, 5)));

  static Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> pumpSettled(WidgetTester t) async {
  await t.runAsync(SettingsHarness.settle);
  for (var i = 0; i < 3; i++) {
    await t.pump();
  }
  // Lets zero-delay timers (DailyRefresher) fire before teardown.
  await t.pump(const Duration(milliseconds: 10));
}

Widget scaled(Widget child, double scale) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
  child: child,
);
