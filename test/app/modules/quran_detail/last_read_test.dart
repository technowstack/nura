import '../../../support/ayah_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/last_read.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/quran_detail/controllers/quran_detail_controller.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/modules/quran_detail/views/quran_detail_view.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';

import '../../../support/fake_repositories.dart';

Surah _s(int n) => Surah(
  number: n,
  nameArab: 'A$n',
  nameLatin: 'L$n',
  nameId: 'T$n',
  ayahCount: n == 1 ? 40 : 3,
  revelation: 'makkiyah',
);

Ayah _a(int s, int n) => Ayah(
  surahNumber: s,
  ayahNumber: n,
  arab: 'arab$s:$n',
  translation: 'trans$s:$n',
  tafsir: 't',
);

void main() {
  late FakeUserRepository user;

  setUp(() {
    Get.reset();
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: [_s(1), _s(2)],
        ayahs: [
          for (var i = 1; i <= 40; i++) _a(1, i),
          for (var i = 1; i <= 3; i++) _a(2, i),
        ],
      ),
    );
    user = FakeUserRepository();
    Get.put<UserRepository>(user);
  });
  tearDown(Get.reset);

  Future<void> pump(WidgetTester t, SurahArgs args, {double scale = 1}) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Get.put(QuranDetailController(args));
    await t.pumpWidget(
      GetMaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const QuranDetailView(),
      ),
    );
    await t.pumpAndSettle();
  }

  // tester.drag pumps no frame mid-gesture; a real drag lays out while held.
  Future<void> dragUp(WidgetTester t) async {
    final g = await t.startGesture(const Offset(180, 500));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, -150));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
  }

  LastRead lr(int s, int a) =>
      LastRead(ref: AyahRef(s, a), updatedAt: DateTime(2000));

  testWidgets('label sits on last-read ayah, jumped into view', (t) async {
    user.lastRead = lr(1, 30);
    await pump(t, const SurahArgs(1));
    final label = find.ancestor(
      of: find.text('Terakhir dibaca'),
      matching: find.byWidgetPredicate(
        (w) => w is AyahCard && w.ayah.ayahNumber == 30,
      ),
    );
    expect(find.text('Terakhir dibaca'), findsOneWidget);
    expect(label, findsOneWidget);
    expect(
      Get.find<QuranDetailController>().listController.visibleRange?.$1,
      30,
    );
  });

  testWidgets('SurahArgs ayah 30 is jumped to', (t) async {
    await pump(t, const SurahArgs(1, 30));
    expect(ayahFinder('arab1:30', 30), findsOneWidget);
    expect(ayahFinder('arab1:2', 2), findsNothing);
    expect(t.getTopLeft(ayahFinder('arab1:30', 30)).dy, lessThan(300));
  });

  testWidgets('opening and scrolling never write last read', (t) async {
    user.lastRead = lr(2, 5);
    await pump(t, const SurahArgs(1));
    await dragUp(t);
    await t.pump(const Duration(seconds: 5));
    Get.delete<QuranDetailController>();
    expect(user.lastReadWrites, isEmpty);
  });

  testWidgets('the button marks that ayah and moves the label', (t) async {
    await pump(t, const SurahArgs(1));
    await t.tap(find.byTooltip('Tandai terakhir dibaca').first);
    await t.pumpAndSettle();
    expect(user.lastReadWrites, [const AyahRef(1, 1)]);
    expect(find.text('Terakhir dibaca'), findsOneWidget);
    expect(Get.find<QuranDetailController>().lastReadAyah.value, 1);
  });

  testWidgets('a failed save marks nothing', (t) async {
    await pump(t, const SurahArgs(1));
    user.failure = StateError('disk');
    Get.find<QuranDetailController>().markLastRead(1);
    await t.pumpAndSettle(const Duration(seconds: 5));
    expect(Get.find<QuranDetailController>().lastReadAyah.value, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('last read in another surah marks nothing', (t) async {
    user.lastRead = lr(2, 2);
    await pump(t, const SurahArgs(1));
    expect(find.text('Terakhir dibaca'), findsNothing);
  });

  testWidgets('first launch does not throw', (t) async {
    await pump(t, const SurahArgs(1));
    expect(find.text('Terakhir dibaca'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Latin 130% at 360x640 with last read', (t) async {
    user.lastRead = lr(1, 5);
    await pump(t, const SurahArgs(1), scale: 1.3);
    expect(t.takeException(), isNull);
    expect(find.text('Terakhir dibaca'), findsOneWidget);
  });
}
