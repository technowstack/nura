import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/prayer_clock.dart';
import 'core/theme/theme_controller.dart';
import 'data/repositories/default_prayer_repository.dart';
import 'data/repositories/prayer_repository.dart';
import 'data/repositories/prayer_store.dart';
import 'data/repositories/sqlite_prayer_store.dart';
import 'data/repositories/hadith_repository.dart';
import 'data/repositories/isolate_hadith_repository.dart';
import 'data/repositories/isolate_search_repository.dart';
import 'data/repositories/quran_repository.dart';
import 'data/repositories/search_repository.dart';
import 'data/repositories/sqlite_quran_repository.dart';
import 'data/repositories/sqlite_user_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/sources/content_database.dart';
import 'data/sources/content_db_installer.dart';
import 'data/sources/prayer_api_client.dart';
import 'data/sources/prayer_calculator.dart';
import 'data/sources/prayer_regions_source.dart';
import 'data/sources/region_coordinates.dart';
import 'data/sources/user_database.dart';
import 'services/flutter_local_notifications_scheduler.dart';
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
}) async {
  ContentDatabase? content;
  UserDatabase? user;
  IsolateHadithRepository? hadith;
  IsolateSearchRepository? search;
  try {
    final file = await installer.ensureInstalled();
    content = ContentDatabase.open(file);
    hadith = await startHadith(content.file);
    search = await startSearch(content.file);
    user = UserDatabase.open(File('${dataDir.path}/user.db'));
    final regions = await loadRegions();
    final online = OnlineService(user);
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
    Get.put<PrayerStore>(store, permanent: true);
    Get.put<PrayerRepository>(
      DefaultPrayerRepository(
        store: store,
        api: PrayerApiClient(defaultPrayerHttp),
        online: online,
        clock: clock,
        calculator: const AdhanPrayerCalculator(),
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
    // Lazy so the stored mode is read when the app first builds.
    Get.lazyPut<ThemeController>(ThemeController.new, fenix: true);
    return BootstrapSuccess(content, user);
  } catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: 'nura bootstrap'),
    );
    await hadith?.close();
    await search?.close();
    content?.close();
    user?.close();
    return BootstrapFailure(e);
  }
}

Future<PrayerRegions> _defaultLoadRegions() => loadPrayerRegions(rootBundle);
