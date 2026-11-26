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

/// Beranda picks up what changed in Settings when it is closed.
void main() {
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
        home: const HomeView(),
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
