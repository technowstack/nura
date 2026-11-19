import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/app_lifecycle_stream.dart';
import 'core/widgets/daily_widget_image.dart';
import 'core/prayer_clock.dart';
import 'core/theme/theme_controller.dart';
import 'data/repositories/audio_settings_store.dart';
import 'data/repositories/daily_content_repository.dart';
import 'data/repositories/daily_settings_store.dart';
import 'data/repositories/default_prayer_repository.dart';
import 'data/repositories/prayer_repository.dart';
import 'data/repositories/prayer_store.dart';
import 'data/repositories/sqlite_audio_settings_store.dart';
import 'data/repositories/sqlite_daily_content_repository.dart';
import 'data/repositories/sqlite_daily_settings_store.dart';
import 'data/repositories/sqlite_prayer_store.dart';
import 'data/repositories/hadith_repository.dart';
import 'data/repositories/isolate_hadith_repository.dart';
import 'data/repositories/isolate_search_repository.dart';
import 'data/repositories/quran_repository.dart';
import 'data/repositories/search_repository.dart';
import 'data/repositories/sqlite_quran_repository.dart';
import 'data/repositories/sqlite_user_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/sources/audio_api_client.dart';
import 'data/sources/content_database.dart';
import 'data/sources/content_db_installer.dart';
import 'data/sources/prayer_adjustments.dart';
import 'data/sources/prayer_api_client.dart';
import 'data/sources/prayer_calculator.dart';
import 'data/sources/prayer_regions_source.dart';
import 'data/sources/region_coordinates.dart';
import 'data/sources/widget_storage.dart';
import 'data/sources/user_database.dart';
import 'services/audio_engine.dart';
import 'services/audio_player_service.dart';
import 'services/daily_link_router.dart';
import 'services/daily_notifier.dart';
import 'services/daily_refresher.dart';
import 'services/flutter_local_notifications_scheduler.dart';
import 'services/hijri_date_service.dart';
import 'services/home_widget_service.dart';
import 'services/notification_scheduler.dart';
import 'services/online_service.dart';
import 'services/prayer_notifier.dart';

sealed class BootstrapResult {
  const BootstrapResult();
}

class BootstrapSuccess extends BootstrapResult {
  const BootstrapSuccess(this.content, this.user);

  final ContentDatabase content;
  final UserDatabase user;
}

class BootstrapFailure extends BootstrapResult {
  const BootstrapFailure(this.error);

  final Object error;
}

/// Installs and opens both databases and the hadith and search workers;
/// registers everything in GetX only after all of them are up, so a failure at
/// any step closes what was opened (including the workers) and registers
/// nothing. Order: content db, hadith worker, search worker, user db, then
/// registration.
Future<BootstrapResult> bootstrap({
  required ContentDbInstaller installer,
  required Directory dataDir,
  @visibleForTesting
  Future<IsolateHadithRepository> Function(File) startHadith =
      IsolateHadithRepository.start,
  @visibleForTesting
  Future<IsolateSearchRepository> Function(File) startSearch =
      IsolateSearchRepository.start,
  @visibleForTesting
  Future<PrayerRegions> Function() loadRegions = _defaultLoadRegions,
  @visibleForTesting
  AudioEngine Function() createAudioEngine = JustAudioEngine.new,
}) async {
  ContentDatabase? content;
  UserDatabase? user;
  IsolateHadithRepository? hadith;
  IsolateSearchRepository? search;
  AudioPlayerService? player;
  AppLifecycleStream? lifecycle;
  try {
    final file = await installer.ensureInstalled();
    content = ContentDatabase.open(file);
    hadith = await startHadith(content.file);
    search = await startSearch(content.file);
    user = UserDatabase.open(File('${dataDir.path}/user.db'));
    final online = OnlineService(user);
    lifecycle = AppLifecycleStream();
    player = AudioPlayerService(
      online,
      AudioApiClient(defaultAudioHttp),
      SqliteAudioSettingsStore(user),
      createAudioEngine(),
      lifecycle: lifecycle.stream,
      connectivity: online.connectivityChanges,
    );
    final regions = await loadRegions();
    final store = SqlitePrayerStore(user);
    const clock = PrayerClock();
    Get.put<ContentDatabase>(content, permanent: true);
    Get.put<UserDatabase>(user, permanent: true);
    Get.put<QuranRepository>(SqliteQuranRepository(content), permanent: true);
    Get.put<UserRepository>(SqliteUserRepository(user), permanent: true);
    Get.put<HadithRepository>(hadith, permanent: true);
    Get.put<SearchRepository>(search, permanent: true);
    Get.put<PrayerRegions>(regions, permanent: true);
    Get.put<PrayerClock>(clock, permanent: true);
    Get.put<OnlineService>(online, permanent: true);
    Get.put<HijriDateService>(HijriDateService(user: user), permanent: true);
    Get.put<AudioSettingsStore>(
      SqliteAudioSettingsStore(user),
      permanent: true,
    );
    Get.put<AudioPlayerService>(player, permanent: true);
    Get.put<PrayerStore>(store, permanent: true);
    Get.put<PrayerRepository>(
      DefaultPrayerRepository(
        store: store,
        api: PrayerApiClient(
          defaultPrayerHttp,
          nowMs: () => clock.nowUtc().millisecondsSinceEpoch,
        ),
        online: online,
        clock: clock,
        calculator: AdhanPrayerCalculator(
          adjustMinutes: prayerAdjustmentsFrom(user),
        ),
        coordinates: const NoRegionCoordinates(),
      ),
      permanent: true,
    );
    final scheduler = FlutterLocalNotificationsScheduler();
    // Not awaited and never fatal: reminders are optional.
    unawaited(
      scheduler.init().catchError((Object e) {
        debugPrint('Notification init failed: $e');
      }),
    );
    Get.put<NotificationScheduler>(scheduler, permanent: true);
    Get.put<PrayerNotifier>(
      PrayerNotifier(
        scheduler: scheduler,
        repository: Get.find<PrayerRepository>(),
        store: store,
        clock: clock,
      ),
      permanent: true,
    );
    Get.put<DailyContentRepository>(
      SqliteDailyContentRepository(content),
      permanent: true,
    );
    Get.put<DailySettingsStore>(
      SqliteDailySettingsStore(user),
      permanent: true,
    );
    Get.put<DailyNotifier>(
      DailyNotifier(
        scheduler: scheduler,
        repository: Get.find<DailyContentRepository>(),
        store: Get.find<DailySettingsStore>(),
      ),
      permanent: true,
    );
    final widgets = HomeWidgetService(
      repository: Get.find<DailyContentRepository>(),
      settings: Get.find<DailySettingsStore>(),
      storage: const HomeWidgetStorage(),
      directory: Directory('${dataDir.path}/widget'),
      render: renderDailyImage,
      now: DateTime.now,
      // Capped so 56 bitmaps stay within memory on dense screens.
      pixelRatio: () => min(
        PlatformDispatcher.instance.views.firstOrNull?.devicePixelRatio ?? 2.0,
        3.0,
      ),
    );
    final notifier = Get.find<DailyNotifier>();
    final router = DailyLinkRouter.platform();
    scheduler.onTap = router.onNotificationTap;
    Get.put<HomeWidgetService>(widgets, permanent: true);
    Get.put<DailyRefresher>(
      DailyRefresher(
        renderWidgets: widgets.refresh,
        reschedule: notifier.reschedule,
        now: DateTime.now,
      ),
      permanent: true,
    );
    Get.put<DailyLinkRouter>(router, permanent: true);
    // Lazy so the stored mode is read when the app first builds.
    Get.lazyPut<ThemeController>(ThemeController.new, fenix: true);
    return BootstrapSuccess(content, user);
  } catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: 'nura bootstrap'),
    );
    await lifecycle?.close();
    await player?.dispose();
    await hadith?.close();
    await search?.close();
    content?.close();
    user?.close();
    return BootstrapFailure(e);
  }
}

Future<PrayerRegions> _defaultLoadRegions() => loadPrayerRegions(rootBundle);
