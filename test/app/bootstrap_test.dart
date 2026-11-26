import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/app_bootstrap.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/theme/theme_controller.dart';
import 'package:nura/app/core/theme/theme_mode_setting.dart';
import 'package:nura/app/core/prayer_clock.dart';
import 'package:nura/app/data/models/prayer_regions.dart';
import 'package:nura/app/data/repositories/default_prayer_repository.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/services/audio_player_service.dart';
import 'package:nura/app/data/repositories/audio_settings_store.dart';
import 'package:nura/app/services/hijri_date_service.dart';
import 'package:nura/app/services/online_service.dart';
import 'package:nura/app/data/repositories/isolate_hadith_repository.dart';
import 'package:nura/app/data/repositories/isolate_search_repository.dart';
import 'package:nura/app/data/repositories/isolate_quran_range_repository.dart';
import 'package:nura/app/data/repositories/quran_range_repository.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/search_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/app/data/sources/content_db_installer.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/nura_app.dart';
import 'package:nura/app/services/daily_link_router.dart';
import 'package:nura/app/services/daily_refresher.dart';
import 'package:nura/app/services/home_widget_service.dart';
import 'package:nura/app/data/repositories/prayer_store.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';
import 'package:nura/app/modules/home/home_view.dart';

import '../support/fake_audio.dart';
import '../support/fixture_db.dart';
import '../support/fake_repositories.dart';

void main() {
  late Directory tmp;
  late Uint8List bytes;
  late String version;

  setUp(() {
    Get.reset();
    tmp = Directory.systemTemp.createTempSync('nura_boot_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final built = buildFixtureDb(tmp, 'fixture');
    bytes = built.bytes;
    version = built.version;
  });

  ContentDbInstaller installer() => ContentDbInstaller(
    copyAsset: (_, dest) async => dest.writeAsBytes(bytes),
    loadVersion: (_) async => version,
    targetDir: Directory('${tmp.path}/data'),
  );

  Future<BootstrapSuccess> ready({
    String? onboardingDone,
    bool swapHadithForFake = false,
  }) async {
    final r = await bootstrap(installer: installer(), dataDir: tmp);
    expect(r, isA<BootstrapSuccess>());
    final s = r as BootstrapSuccess;
    addTearDown(s.content.close);
    addTearDown(s.user.close);
    final hadith = Get.find<HadithRepository>() as IsolateHadithRepository;
    addTearDown(hadith.close);
    final range =
        Get.find<QuranRangeRepository>() as IsolateQuranRangeRepository;
    addTearDown(range.close);
    final search = Get.find<SearchRepository>() as IsolateSearchRepository;
    addTearDown(search.close);
    if (swapHadithForFake) {
      // Real isolates never reply under fake async, which would keep loading
      // spinners animating forever.
      Get.replace<HadithRepository>(FakeHadithRepository());
      Get.replace<SearchRepository>(FakeSearchRepository());
    }
    if (onboardingDone != null) {
      s.user.setSetting(SettingKeys.onboardingDone, onboardingDone);
    }
    return s;
  }

  test('themeModeFromSetting maps values', () {
    expect(themeModeFromSetting('dark'), ThemeMode.dark);
    expect(themeModeFromSetting('light'), ThemeMode.light);
    expect(themeModeFromSetting(null), ThemeMode.system);
    expect(themeModeFromSetting('garbage'), ThemeMode.system);
  });

  test('bootstrap registers both databases on success', () async {
    await ready();
    expect(Get.find<ContentDatabase>().dataVersion, isNotEmpty);
    expect(Get.isRegistered<UserDatabase>(), isTrue);
    expect(Get.find<QuranRepository>(), isA<QuranRepository>());
    expect(Get.find<UserRepository>(), isA<UserRepository>());
    expect(Get.find<HadithRepository>(), isA<IsolateHadithRepository>());
    expect(Get.find<SearchRepository>(), isA<IsolateSearchRepository>());
  });

  test('bootstrap registers the prayer services', () async {
    await ready();
    expect(Get.find<PrayerRepository>(), isA<DefaultPrayerRepository>());
    expect(Get.find<PrayerRegions>().provinces, isNotEmpty);
    expect(Get.isRegistered<OnlineService>(), isTrue);
    expect(Get.isRegistered<HijriDateService>(), isTrue);
    expect(Get.isRegistered<PrayerClock>(), isTrue);
  });

  test('bootstrap registers the daily content services', () async {
    await ready();
    expect(Get.find<DailyContentRepository>(), isA<DailyContentRepository>());
    expect(Get.find<DailySettingsStore>(), isA<DailySettingsStore>());
    expect(Get.find<HomeWidgetService>(), isA<HomeWidgetService>());
    expect(Get.find<DailyRefresher>(), isA<DailyRefresher>());
    expect(Get.find<DailyLinkRouter>(), isA<DailyLinkRouter>());
  });

  test('bootstrap registers the audio services', () async {
    await ready();
    expect(Get.find<AudioPlayerService>(), isA<AudioPlayerService>());
    expect(Get.find<AudioSettingsStore>(), isA<AudioSettingsStore>());
  });

  test(
    'failed bootstrap disposes the audio engine, registers nothing',
    () async {
      final engine = FakeAudioEngine();
      final r = await bootstrap(
        installer: installer(),
        dataDir: tmp,
        createAudioEngine: () => engine,
        loadRegions: () async => throw StateError('boom'),
      );
      expect(r, isA<BootstrapFailure>());
      expect(engine.disposed, isTrue);
      expect(Get.isRegistered<AudioPlayerService>(), isFalse);
      expect(Get.isRegistered<AudioSettingsStore>(), isFalse);
    },
  );

  test('failed region load registers nothing', () async {
    final r = await bootstrap(
      installer: installer(),
      dataDir: tmp,
      loadRegions: () async => throw StateError('boom'),
    );
    expect(r, isA<BootstrapFailure>());
    expect(Get.isRegistered<PrayerRepository>(), isFalse);
    expect(Get.isRegistered<UserDatabase>(), isFalse);
    expect(Get.isRegistered<DailyContentRepository>(), isFalse);
    expect(Get.isRegistered<DailySettingsStore>(), isFalse);
    expect(Get.isRegistered<HomeWidgetService>(), isFalse);
    expect(Get.isRegistered<DailyRefresher>(), isFalse);
    expect(Get.isRegistered<DailyLinkRouter>(), isFalse);
  });

  test('search worker starts after the hadith worker', () async {
    final order = <String>[];
    final r = await bootstrap(
      installer: installer(),
      dataDir: tmp,
      startHadith: (f) async {
        order.add('hadith');
        return IsolateHadithRepository.start(f);
      },
      startSearch: (f) async {
        order.add('search');
        return IsolateSearchRepository.start(f);
      },
    );
    final s = r as BootstrapSuccess;
    addTearDown(s.content.close);
    addTearDown(s.user.close);
    addTearDown(
      (Get.find<HadithRepository>() as IsolateHadithRepository).close,
    );
    addTearDown(
      (Get.find<SearchRepository>() as IsolateSearchRepository).close,
    );
    expect(order, ['hadith', 'search']);
  });

  test(
    'failed search start closes the hadith worker and registers nothing',
    () async {
      IsolateHadithRepository? hadith;
      final r = await bootstrap(
        installer: installer(),
        dataDir: tmp,
        startHadith: (f) async =>
            hadith = await IsolateHadithRepository.start(f),
        startSearch: (_) async => throw const ContentUnavailable('boom'),
      );
      expect(r, isA<BootstrapFailure>());
      expect(hadith, isNotNull);
      await hadith?.exited.timeout(const Duration(seconds: 5));
      expect(Get.isRegistered<ContentDatabase>(), isFalse);
      expect(Get.isRegistered<HadithRepository>(), isFalse);
      expect(Get.isRegistered<SearchRepository>(), isFalse);
    },
  );

  test('failed bootstrap closes both workers and registers nothing', () async {
    Directory('${tmp.path}/user.db').createSync();
    IsolateHadithRepository? started;
    IsolateSearchRepository? search;
    final r = await bootstrap(
      installer: installer(),
      dataDir: tmp,
      startHadith: (f) async =>
          started = await IsolateHadithRepository.start(f),
      startSearch: (f) async => search = await IsolateSearchRepository.start(f),
    );
    expect(r, isA<BootstrapFailure>());
    expect(started, isNotNull);
    expect(search, isNotNull);
    await started?.exited.timeout(const Duration(seconds: 5));
    await search?.exited.timeout(const Duration(seconds: 5));
    expect(Get.isRegistered<HadithRepository>(), isFalse);
    expect(Get.isRegistered<SearchRepository>(), isFalse);
  });

  test(
    'failed bootstrap closes the range worker and registers nothing',
    () async {
      Directory('${tmp.path}/user.db').createSync();
      IsolateQuranRangeRepository? range;
      final r = await bootstrap(
        installer: installer(),
        dataDir: tmp,
        startRange: (f) async =>
            range = await IsolateQuranRangeRepository.start(f),
      );
      expect(r, isA<BootstrapFailure>());
      expect(range, isNotNull);
      await range?.exited.timeout(const Duration(seconds: 5));
      expect(Get.isRegistered<QuranRangeRepository>(), isFalse);
    },
  );

  test(
    'failed range start closes earlier workers, registers nothing',
    () async {
      IsolateSearchRepository? search;
      final r = await bootstrap(
        installer: installer(),
        dataDir: tmp,
        startSearch: (f) async =>
            search = await IsolateSearchRepository.start(f),
        startRange: (_) async => throw const ContentUnavailable('boom'),
      );
      expect(r, isA<BootstrapFailure>());
      await search?.exited.timeout(const Duration(seconds: 5));
      expect(Get.isRegistered<QuranRangeRepository>(), isFalse);
      expect(Get.isRegistered<SearchRepository>(), isFalse);
    },
  );

  test('bootstrap returns failure when installer throws', () async {
    final r = await bootstrap(
      installer: ContentDbInstaller(
        copyAsset: (_, _) async => throw StateError('boom'),
        loadVersion: (_) async => 'x:y',
        targetDir: Directory('${tmp.path}/data'),
      ),
      dataDir: tmp,
    );
    expect(r, isA<BootstrapFailure>());
    expect(Get.isRegistered<ContentDatabase>(), isFalse);
  });

  test('bootstrap returns failure when user.db cannot open', () async {
    Directory('${tmp.path}/user.db').createSync();
    final r = await bootstrap(installer: installer(), dataDir: tmp);
    expect(r, isA<BootstrapFailure>());
    expect(Get.isRegistered<ContentDatabase>(), isFalse);
  });

  testWidgets('failure shows error screen with retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      NuraApp(
        result: BootstrapFailure(Exception('x')),
        onRetry: () => retried = true,
      ),
    );
    expect(find.text('Nura tidak bisa dibuka'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    expect(retried, isTrue);
  });

  testWidgets('first launch goes to onboarding, Mulai goes to Beranda', (
    tester,
  ) async {
    final s =
        await tester.runAsync(() => ready(swapHadithForFake: true))
            as BootstrapSuccess;
    await tester.pumpWidget(NuraApp(result: s, onRetry: () {}));
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang di Nura'), findsOneWidget);
    for (final next in ['Lanjut', 'Lanjut']) {
      await tester.tap(find.text(next));
      await tester.pumpAndSettle();
    }
    expect(s.user.getSetting(SettingKeys.onboardingDone), isNull);
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsOneWidget); // nav label
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.textContaining('data_version'), findsNothing);
    expect(s.user.getSetting(SettingKeys.onboardingDone), 'true');
  });

  testWidgets('onboarding_done=true goes to Beranda', (tester) async {
    final s =
        await tester.runAsync(
              () => ready(onboardingDone: 'true', swapHadithForFake: true),
            )
            as BootstrapSuccess;
    await tester.pumpWidget(NuraApp(result: s, onRetry: () {}));
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsOneWidget); // nav label
    expect(find.byType(HomeView), findsOneWidget);
    for (final registered in [
      Get.isRegistered<HijriDateService>(),
      Get.isRegistered<QuranRepository>(),
      Get.isRegistered<UserRepository>(),
      Get.isRegistered<PrayerStore>(),
    ]) {
      expect(registered, isTrue);
    }
    // Resolved by HomeController: the Hijri date comes from the service.
    expect(Get.find<HomeController>().hero.value.hijriDate, isNotEmpty);
  });

  for (final (setting, expected) in [
    ('dark', ThemeMode.dark),
    ('light', ThemeMode.light),
    (null, ThemeMode.system),
  ]) {
    testWidgets('theme_mode=$setting gives $expected', (tester) async {
      final s =
          await tester.runAsync(
                () => ready(onboardingDone: 'true', swapHadithForFake: true),
              )
              as BootstrapSuccess;
      if (setting != null) s.user.setSetting(SettingKeys.themeMode, setting);
      await tester.pumpWidget(NuraApp(result: s, onRetry: () {}));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GetMaterialApp>(find.byType(GetMaterialApp)).themeMode,
        expected,
      );
    });
  }

  testWidgets('theme switch keeps pushed route and turns dark', (tester) async {
    final s =
        await tester.runAsync(
              () => ready(onboardingDone: 'true', swapHadithForFake: true),
            )
            as BootstrapSuccess;
    await tester.pumpWidget(NuraApp(result: s, onRetry: () {}));
    await tester.pumpAndSettle();
    unawaited(Get.to<void>(() => const Scaffold(body: Text('PUSHED'))));
    await tester.pumpAndSettle();
    Get.find<ThemeController>().setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(find.text('PUSHED'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('PUSHED'))).brightness,
      Brightness.dark,
    );
  });
}
