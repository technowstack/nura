import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/revelation_label.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/sqlite_quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/modules/quran_list/bindings/quran_list_binding.dart';
import 'package:nura/app/modules/quran_list/views/quran_list_view.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';

void main() {
  test('revelationLabel maps known values and hides the rest', () {
    expect(revelationLabel('makkiyah'), 'Makkiyah');
    expect(revelationLabel('madaniyah'), 'Madaniyah');
    expect(revelationLabel(''), '');
    expect(revelationLabel('x'), '');
  });

  test('no [Q4] placeholder remains in lib/', () {
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('[Q4]'));
    expect(hits, isEmpty);
  });

  group('juz tab with real content.db', () {
    Object? routeArgs;

    setUp(() {
      Get.reset();
      routeArgs = null;
      Get.put<QuranRepository>(
        SqliteQuranRepository(
          ContentDatabase.open(File('assets/db/content.db')),
        ),
      );
      Get.put<UserRepository>(FakeUserRepository());
      Get.put<HadithRepository>(FakeHadithRepository());
      QuranListBinding().dependencies();
    });
    tearDown(Get.reset);

    Future<void> open(WidgetTester t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        GetMaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: QuranListView()),
          getPages: [
            GetPage(
              name: Routes.surah,
              page: () {
                routeArgs = Get.arguments;
                return const Scaffold(body: Text('surah page'));
              },
            ),
          ],
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Juz'));
      await t.pumpAndSettle();
    }

    testWidgets('shows 30 juz with correct ranges, no overflow at 130%', (
      t,
    ) async {
      await open(t);
      expect(Get.find<QuranRepository>().listJuz(), hasLength(30));
      expect(find.text('Juz 1'), findsOneWidget);
      expect(find.text('Al-Fatihah 1 – Al-Baqarah 141'), findsOneWidget);
      expect(find.text('Al-Baqarah 142 – Al-Baqarah 252'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Juz 15'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text("Al-Isra' 1 – Al-Kahf 74"), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Juz 30'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text("An-Naba' 1 – An-Nas 6"), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('tap opens the start ayah', (t) async {
      await open(t);
      await t.tap(find.text('Juz 2'));
      await t.pumpAndSettle();
      final a = routeArgs as SurahArgs;
      expect((a.surah, a.ayah), (2, 142));
    });
  });
}
