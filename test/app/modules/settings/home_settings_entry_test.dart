import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';
import 'package:nura/app/modules/home/home_view.dart';
import 'package:nura/app/modules/settings/bindings/settings_binding.dart';
import 'package:nura/app/modules/settings/controllers/settings_controller.dart';
import 'package:nura/app/modules/settings/views/settings_view.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/settings_harness.dart';

/// The Beranda hero icon opens the real Settings screen; Beranda picks up
/// what changed there when it comes back.
void main() {
  testWidgets('hero icon opens Settings and Beranda refreshes on return', (
    t,
  ) async {
    final h = SettingsHarness.create();
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Get.put(HomeController(now: () => DateTime(2026, 11, 15, 10)));
    await t.pumpWidget(
      GetMaterialApp(
        home: const HomeView(dataVersion: 'v1'),
        getPages: [
          GetPage(
            name: Routes.settings,
            page: SettingsView.new,
            binding: SettingsBinding(),
          ),
        ],
      ),
    );
    await t.pump();
    expect(find.byTooltip('Pengaturan harian'), findsNothing);
    expect(
      t.getSize(find.byTooltip('Pengaturan')).width,
      greaterThanOrEqualTo(48),
    );
    expect(find.text('Hadis hari 15 (default)'), findsOneWidget);
    await t.tap(find.byTooltip('Pengaturan'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    Get.find<SettingsController>().setHadithSource(HadithSource.allBooks);
    await pumpSettled(t);
    Get.back<void>();
    await t.pumpAndSettle();
    expect(find.byType(SettingsView), findsNothing);
    expect(find.text('Hadis hari 15 (all)'), findsOneWidget);
    expect(h.daily.hadithSource, HadithSource.allBooks);
    await t.pumpWidget(const SizedBox.shrink());
    Get.delete<HomeController>(force: true);
  });

  testWidgets('Beranda updates when Settings was opened from elsewhere', (
    t,
  ) async {
    final h = SettingsHarness.create();
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Get.put(HomeController(now: () => DateTime(2026, 11, 15, 10)));
    await t.pumpWidget(
      GetMaterialApp(
        home: const HomeView(dataVersion: 'v1'),
        getPages: [
          GetPage(
            name: Routes.settings,
            page: SettingsView.new,
            binding: SettingsBinding(),
          ),
        ],
      ),
    );
    await t.pump();
    final before = h.hijri.format(DateTime(2026, 11, 15));
    expect(find.text(before), findsOneWidget);
    // Settings opened by a reader, not by Beranda.
    unawaited(Get.toNamed<void>(Routes.settings));
    await t.pumpAndSettle();
    final c = Get.find<SettingsController>();
    c.setHadithSource(HadithSource.allBooks);
    c.setHijriAdjust(1);
    await pumpSettled(t);
    Get.back<void>();
    await t.pumpAndSettle();
    expect(find.text('Hadis hari 15 (all)'), findsOneWidget);
    expect(find.text(h.hijri.format(DateTime(2026, 11, 15))), findsOneWidget);
    expect(find.text(before), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    Get.delete<HomeController>(force: true);
  });
}
