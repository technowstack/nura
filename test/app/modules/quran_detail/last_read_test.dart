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

import '../../../support/fake_repositories.dart';

Surah _s(int n) => Surah(
  number: n,
  nameArab: 'A$n',
  nameLatin: 'L$n',
  nameId: 'T$n',
  ayahCount: 10,
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
          for (var i = 1; i <= 10; i++) _a(1, i),
          for (var i = 1; i <= 3; i++) _a(2, i),
        ],
      ),
    );
    user = FakeUserRepository();
    Get.put<UserRepository>(user);
  });
  tearDown(Get.reset);

  QuranDetailController ctl() =>
      Get.put(QuranDetailController(const SurahArgs(1)));

  test('flush without report writes nothing', () {
    ctl().flushLastRead();
    expect(user.lastReadWrites, isEmpty);
  });

  testWidgets('debounce writes once after 3s', (t) async {
    final c = ctl()..onVisibleAyahChanged(5);
    await t.pump(const Duration(seconds: 2));
    expect(user.lastReadWrites, isEmpty);
    await t.pump(const Duration(seconds: 1));
    expect(user.lastReadWrites, [const AyahRef(1, 5)]);
    c.flushLastRead();
    await t.pump(const Duration(seconds: 5));
    expect(user.lastReadWrites, [const AyahRef(1, 5)]);
  });

  testWidgets('only latest report in window is written', (t) async {
    ctl()
      ..onVisibleAyahChanged(6)
      ..onVisibleAyahChanged(7);
    await t.pump(const Duration(seconds: 3));
    expect(user.lastReadWrites, [const AyahRef(1, 7)]);
  });

  testWidgets('flush writes immediately and cancels timer', (t) async {
    ctl()
      ..onVisibleAyahChanged(8)
      ..flushLastRead();
    expect(user.lastReadWrites, [const AyahRef(1, 8)]);
    await t.pump(const Duration(seconds: 5));
    expect(user.lastReadWrites, [const AyahRef(1, 8)]);
  });

  Future<void> pump(WidgetTester t, SurahArgs args, {double scale = 1}) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Get.put(QuranDetailController(args, lastReadDebounce: Duration.zero));
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
    await t.pump(Duration.zero); // drain zero-length debounce timer
  }

  LastRead lr(int s, int a) =>
      LastRead(ref: AyahRef(s, a), updatedAt: DateTime(2000));

  testWidgets('label on last-read ayah only', (t) async {
    user.lastRead = lr(1, 5);
    await pump(t, const SurahArgs(1));
    expect(find.text('Terakhir dibaca'), findsOneWidget);
    expect(find.text('arab1:5'), findsOneWidget);
  });

  testWidgets('SurahArgs ayah 3 is visible', (t) async {
    await pump(t, const SurahArgs(1, 3));
    expect(find.text('arab1:3'), findsOneWidget);
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
