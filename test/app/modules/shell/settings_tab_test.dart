import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';
import 'package:nura/app/modules/settings/bindings/settings_binding.dart';
import 'package:nura/app/modules/settings/controllers/settings_controller.dart';
import 'package:nura/app/modules/settings/views/settings_route_page.dart';
import 'package:nura/app/modules/settings/views/settings_view.dart';
import 'package:nura/app/modules/shell/views/shell_view.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';
import '../../../support/settings_harness.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await l.load();
}

Widget _app({ThemeData? theme}) => GetMaterialApp(
  theme: theme,
  initialRoute: Routes.home,
  getPages: [
    GetPage(
      name: Routes.home,
      page: () => const ShellView(),
    ),
    GetPage(
      name: Routes.settings,
      page: SettingsRoutePage.new,
      binding: SettingsBinding(),
    ),
  ],
);

Finder _nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  late SettingsHarness h;
  setUp(() {
    h = SettingsHarness.create();
    Get.put<HadithRepository>(FakeHadithRepository());
  });

  Future<void> goToSettings(WidgetTester t) async {
    await t.tap(_nav('Setelan'));
    await t.pumpAndSettle();
  }

  Future<void> end(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    Get.delete<HomeController>(force: true);
  }

  testWidgets('fifth tab shows Settings as a tab: no back arrow, title row', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    final labels = [
      for (final d in t.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      ))
        d.label,
    ];
    expect(labels, ['Beranda', "Al-Qur'an", 'Hadis', 'Sholat', 'Setelan']);
    await goToSettings(t);
    final view = find.byType(SettingsView);
    expect(view, findsOneWidget);
    expect(t.widget<SettingsView>(view).asTab, isTrue);
    expect(
      find.descendant(of: view, matching: find.byType(AppBar)),
      findsNothing,
    );
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Tampilan'), findsOneWidget);
    await end(t);
  });

  testWidgets('tab label fits on one line at 360x640, 130% text, real fonts', (
    t,
  ) async {
    await t.runAsync(() async {
      await _font('Plus Jakarta Sans', [
        for (final w in ['Regular', 'Medium', 'SemiBold'])
          'assets/fonts/PlusJakartaSans/PlusJakartaSans-$w.ttf',
      ]);
    });
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _app(theme: AppTheme.light),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    // Measured: 'Pengaturan' wraps mid-word (2 lines) in the 72 dp cell, so
    // the label is 'Setelan'. "Al-Qur'an" (existing label) wraps at its hyphen.
    for (final l in ['Beranda', 'Hadis', 'Sholat', 'Setelan']) {
      expect(
        t.renderObject<RenderParagraph>(_nav(l)).didExceedMaxLines,
        isFalse,
        reason: '$l truncated',
      );
      expect(t.getSize(_nav(l)).height, t.getSize(_nav('Hadis')).height);
      expect(t.getSize(_nav(l)).width, lessThanOrEqualTo(72), reason: l);
    }
    expect(
      t.renderObject<RenderParagraph>(_nav("Al-Qur'an")).didExceedMaxLines,
      isFalse,
    );
    await goToSettings(t);
    expect(t.takeException(), isNull);
    await end(t);
  });

  testWidgets('one SettingsController, kept when a route above is closed', (
    t,
  ) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await goToSettings(t);
    final tabController = Get.find<SettingsController>();
    unawaited(Get.toNamed<void>(Routes.settings));
    await t.pumpAndSettle();
    expect(find.byType(SettingsRoutePage), findsOneWidget);
    expect(identical(Get.find<SettingsController>(), tabController), isTrue);
    Get.back<void>();
    await t.pumpAndSettle();
    expect(find.byType(SettingsRoutePage), findsNothing);
    expect(identical(Get.find<SettingsController>(), tabController), isTrue);
    expect(tabController.isClosed, isFalse);
    expect(find.text('Tampilan'), findsOneWidget);
    await end(t);
  });

  testWidgets('a change in the tab shows on Beranda; a store change made '
      'elsewhere shows on the next visit', (t) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    expect(find.textContaining('(default)'), findsOneWidget);
    await goToSettings(t);
    Get.find<SettingsController>().setHadithSource(HadithSource.allBooks);
    await pumpSettled(t);
    await t.tap(_nav('Beranda'));
    await t.pumpAndSettle();
    expect(find.textContaining('(all)'), findsOneWidget);
    // Changed behind the controller's back while away.
    h.daily.setHadithSource(HadithSource.defaultBm);
    expect(
      Get.find<SettingsController>().hadithSource.value,
      HadithSource.allBooks,
    );
    await goToSettings(t);
    await pumpSettled(t);
    expect(
      Get.find<SettingsController>().hadithSource.value,
      HadithSource.defaultBm,
    );
    // Same on the route.
    h.daily.setHadithSource(HadithSource.allBooks);
    unawaited(Get.toNamed<void>(Routes.settings));
    await pumpSettled(t);
    expect(
      Get.find<SettingsController>().hadithSource.value,
      HadithSource.allBooks,
    );
    Get.back<void>();
    await t.pumpAndSettle();
    await end(t);
  });

  testWidgets('tab at 130% text, 360x640, has no overflow', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: _app(),
      ),
    );
    await t.pumpAndSettle();
    await goToSettings(t);
    await pumpSettled(t);
    expect(t.takeException(), isNull);
    await end(t);
  });
}
