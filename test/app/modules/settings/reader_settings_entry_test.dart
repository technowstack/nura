import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/juz.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/quran_range_repository.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/modules/juz_reader/controllers/juz_reader_controller.dart';
import 'package:nura/app/modules/juz_reader/juz_args.dart';
import 'package:nura/app/modules/juz_reader/views/juz_reader_view.dart';
import 'package:nura/app/modules/quran_detail/controllers/quran_detail_controller.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/modules/quran_detail/views/quran_detail_view.dart';
import 'package:nura/app/modules/settings/bindings/settings_binding.dart';
import 'package:nura/app/modules/settings/controllers/settings_controller.dart';
import 'package:nura/app/modules/settings/views/settings_view.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/ayah_text.dart';
import '../../../support/fake_repositories.dart';
import '../../../support/settings_harness.dart';

const _surah = Surah(
  number: 1,
  nameArab: 'a',
  nameLatin: 'Latin1',
  nameId: 'x',
  ayahCount: 2,
  revelation: 'makkiyah',
);

const _ayahs = [
  Ayah(
    surahNumber: 1,
    ayahNumber: 1,
    arab: 'arab1',
    translation: 'trans1',
    tafsir: 't',
  ),
  Ayah(
    surahNumber: 1,
    ayahNumber: 2,
    arab: 'arab2',
    translation: 'trans2',
    tafsir: 't',
  ),
];

/// Readers open Settings (the real screen) and pick up the changed prefs.
void main() {
  setUp(() {
    SettingsHarness.create();
    Get.delete<QuranRepository>(force: true);
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: const [_surah],
        ayahs: _ayahs,
        juz: const [
          Juz(number: 1, startSurah: 1, startAyah: 1, endSurah: 1, endAyah: 2),
        ],
      ),
    );
    Get.put<QuranRangeRepository>(FakeQuranRangeRepository(_ayahs));
  });

  Future<void> pump(WidgetTester t, Widget home) async {
    t.view.physicalSize = const Size(360, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      GetMaterialApp(
        home: home,
        getPages: [
          GetPage(
            name: Routes.settings,
            page: SettingsView.new,
            binding: SettingsBinding(),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
  }

  double size(WidgetTester t, String text) =>
      t.widget<Text>(find.text(text)).style!.fontSize!;

  Future<void> openSettings(WidgetTester t) async {
    final b = find.byTooltip('Pengaturan tampilan');
    expect(t.getSize(b).width, greaterThanOrEqualTo(48));
    expect(t.getSize(b).height, greaterThanOrEqualTo(48));
    await t.tap(b);
    await t.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
  }

  Future<void> change(WidgetTester t) async {
    final s = Get.find<SettingsController>();
    s.setArabicFontSize(36);
    s.setTranslationFontSize(20);
    await t.pump();
  }

  Future<void> back(WidgetTester t) async {
    Get.back<void>();
    await t.pumpAndSettle();
  }

  testWidgets('surah reader: gear opens Settings, changes apply on return', (
    t,
  ) async {
    Get.put(
      QuranDetailController(
        const SurahArgs(1),
        lastReadDebounce: Duration.zero,
      ),
    );
    await pump(t, const QuranDetailView());
    expect(size(t, 'trans2'), 15);
    expect(t.widget<Text>(ayahFinder('arab2', 2)).style!.fontSize, 28);
    await openSettings(t);
    await change(t);
    await back(t);
    expect(find.byType(SettingsView), findsNothing);
    expect(size(t, 'trans2'), 20);
    expect(t.widget<Text>(ayahFinder('arab2', 2)).style!.fontSize, 36);
    // The 24/15 token line-height ratio is kept.
    expect(
      t.widget<Text>(find.text('trans2')).style!.height,
      closeTo(24 / 15, 0.001),
    );
    await openSettings(t);
    Get.find<SettingsController>().setShowTranslation(false);
    await back(t);
    expect(find.text('trans2'), findsNothing);
  });

  testWidgets('juz reader: gear opens Settings, changes apply on return', (
    t,
  ) async {
    Get.put(
      JuzReaderController(const JuzArgs(1), lastReadDebounce: Duration.zero),
    );
    await pump(t, const JuzReaderView());
    expect(size(t, 'trans2'), 15);
    await openSettings(t);
    await change(t);
    await back(t);
    expect(size(t, 'trans2'), 20);
    expect(t.widget<Text>(ayahFinder('arab2', 2)).style!.fontSize, 36);
    await openSettings(t);
    Get.find<SettingsController>().setShowTranslation(false);
    await back(t);
    expect(find.text('trans2'), findsNothing);
  });
}
