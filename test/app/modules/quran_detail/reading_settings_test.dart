import '../../../support/ayah_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/theme_controller.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/modules/quran_detail/views/quran_detail_view.dart';
import 'package:nura/app/modules/quran_detail/controllers/quran_detail_controller.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';

import '../../../support/fake_repositories.dart';

const _basmalah = 'BASMALAH-FROM-REPO';

Ayah _a(int n, String arab) => Ayah(
  surahNumber: 1,
  ayahNumber: n,
  arab: arab,
  translation: 'trans$n',
  tafsir: 't',
);

void main() {
  late FakeUserRepository user;
  late ThemeController theme;

  setUp(() {
    Get.reset();
    user = FakeUserRepository();
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: [
          const Surah(
            number: 1,
            nameArab: 'a',
            nameLatin: 'Latin1',
            nameId: 'x',
            ayahCount: 2,
            revelation: 'makkiyah',
          ),
        ],
        ayahs: [_a(1, _basmalah), _a(2, 'arab2')],
      ),
    );
    Get.put<UserRepository>(user);
    theme = Get.put(ThemeController());
    Get.put(
      QuranDetailController(
        const SurahArgs(1),
        lastReadDebounce: Duration.zero,
      ),
    );
  });
  tearDown(Get.reset);

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    double height = 1200,
  }) async {
    tester.view.physicalSize = Size(360, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Obx(
        () => GetMaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode.value,
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const QuranDetailView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pengaturan tampilan'));
    await tester.pumpAndSettle();
  }

  double arabSize(WidgetTester t) =>
      t.widget<Text>(ayahFinder('arab2', 2)).style!.fontSize!;

  testWidgets('slider changes AyahCard font size and persists', (t) async {
    await pump(t);
    final slider = t.widget<Slider>(find.byType(Slider));
    expect(slider.min, 20);
    expect(slider.max, 40);
    expect(slider.divisions, 10);
    slider.onChanged!(36);
    await t.pumpAndSettle();
    expect(user.prefs.arabicFontSize, 36);
    expect(arabSize(t), 36);
  });

  testWidgets('settings button >= 48x48 and scrim alpha 0.32', (t) async {
    await pump(t);
    final b = t.getSize(find.byTooltip('Pengaturan tampilan'));
    expect(b.width, greaterThanOrEqualTo(48));
    expect(b.height, greaterThanOrEqualTo(48));
    final barrier = t.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color?.a, closeTo(0.32, 0.005));
  });

  testWidgets('preview uses basmalah from content', (t) async {
    await pump(t);
    expect(find.text(_basmalah), findsWidgets);
    expect(find.text('Pengaturan tampilan'), findsOneWidget);
  });

  testWidgets('switch hides and shows translation', (t) async {
    await pump(t);
    expect(find.text('trans2'), findsOneWidget);
    await t.tap(find.text('Tampilkan terjemahan'));
    await t.pumpAndSettle();
    expect(find.text('trans2'), findsNothing);
    expect(user.prefs.showTranslation, isFalse);
    await t.tap(find.text('Tampilkan terjemahan'));
    await t.pumpAndSettle();
    expect(find.text('trans2'), findsOneWidget);
  });

  testWidgets('choosing Gelap switches app theme and persists', (t) async {
    await pump(t);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await t.tap(find.text('Gelap'));
    await t.pumpAndSettle();
    expect(
      t.widget<GetMaterialApp>(find.byType(GetMaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(user.themeMode, ThemeMode.dark);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(Get.put(ThemeController(), tag: 'fresh').mode.value, ThemeMode.dark);
  });

  testWidgets('failed save leaves prefs unchanged', (t) async {
    await pump(t);
    user.failure = StateError('disk');
    t.widget<Slider>(find.byType(Slider)).onChanged!(36);
    await t.pump();
    expect(arabSize(t), 28);
    expect(Get.find<QuranDetailController>().prefs.value.arabicFontSize, 28);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('Latin 130% at 360x640 fits within 90%', (t) async {
    await pump(t, scale: 1.3, height: 640);
    expect(t.takeException(), isNull);
    final sheet = t.getSize(find.byType(BottomSheet));
    expect(sheet.height, lessThanOrEqualTo(576));
    expect(find.byType(AyahCard), findsWidgets);
  });
}
