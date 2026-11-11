import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/app_bootstrap.dart';
import 'package:nura/app/core/theme/theme_mode_setting.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/app/data/sources/content_db_installer.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/nura_app.dart';

import '../support/fixture_db.dart';

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

  Future<BootstrapSuccess> ready({String? onboardingDone}) async {
    final r = await bootstrap(installer: installer(), dataDir: tmp);
    expect(r, isA<BootstrapSuccess>());
    final s = r as BootstrapSuccess;
    addTearDown(s.content.close);
    addTearDown(s.user.close);
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
  });

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
    final s = await tester.runAsync(ready) as BootstrapSuccess;
    await tester.pumpWidget(NuraApp(result: s, onRetry: () {}));
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang di Nura'), findsOneWidget);
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsNWidgets(2)); // nav label + HomeView
    expect(find.textContaining('data_version '), findsOneWidget);
    expect(s.user.getSetting(SettingKeys.onboardingDone), 'true');
  });

  testWidgets('onboarding_done=true goes to Beranda', (tester) async {
    final s =
        await tester.runAsync(() => ready(onboardingDone: 'true'))
            as BootstrapSuccess;
    await tester.pumpWidget(NuraApp(result: s, onRetry: () {}));
    await tester.pumpAndSettle();
    expect(find.text('Beranda'), findsNWidgets(2)); // nav label + HomeView
  });

  for (final (setting, expected) in [
    ('dark', ThemeMode.dark),
    ('light', ThemeMode.light),
    (null, ThemeMode.system),
  ]) {
    testWidgets('theme_mode=$setting gives $expected', (tester) async {
      final s =
          await tester.runAsync(() => ready(onboardingDone: 'true'))
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
}
