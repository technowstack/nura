import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/theme/theme_controller.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/juz.dart';
import 'package:nura/app/data/models/last_read.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/quran_range_repository.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/juz_reader/bindings/juz_reader_binding.dart';
import 'package:nura/app/modules/juz_reader/controllers/juz_reader_controller.dart';
import 'package:nura/app/modules/juz_reader/juz_args.dart';
import 'package:nura/app/modules/juz_reader/juz_item.dart';
import 'package:nura/app/modules/juz_reader/views/juz_reader_view.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';
import 'package:nura/app/modules/quran_detail/widgets/surah_header_card.dart';
import 'package:nura/app/modules/quran_list/bindings/quran_list_binding.dart';
import 'package:nura/app/modules/quran_list/views/quran_list_view.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';

const _counts = {1: 3, 2: 3, 3: 40};

Surah _s(int n) => Surah(
  number: n,
  nameArab: 'A$n',
  nameLatin: 'L$n',
  nameId: 'T$n',
  ayahCount: _counts[n] ?? 1,
  revelation: 'makkiyah',
);

Ayah _a(int s, int n) => Ayah(
  surahNumber: s,
  ayahNumber: n,
  arab: 'arab$s:$n',
  translation: 'trans$s:$n',
  tafsir: 'tafsir$s:$n',
);

/// Juz 1 here spans 1:2 .. 3:40: three surahs, mid-surah start.
final _all = [
  for (final e in _counts.entries)
    for (var i = 1; i <= e.value; i++) _a(e.key, i),
];

void main() {
  late FakeUserRepository user;
  late FakeQuranRangeRepository range;

  setUp(() {
    Get.reset();
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: [_s(1), _s(2), _s(3)],
        ayahs: _all,
        juz: const [
          Juz(number: 1, startSurah: 1, startAyah: 2, endSurah: 3, endAyah: 40),
        ],
      ),
    );
    range = FakeQuranRangeRepository(_all);
    Get.put<QuranRangeRepository>(range);
    user = FakeUserRepository();
    Get.put<UserRepository>(user);
    Get.put(ThemeController());
  });
  tearDown(Get.reset);

  JuzReaderController ctl({Duration debounce = Duration.zero}) => Get.put(
    JuzReaderController(const JuzArgs(1), lastReadDebounce: debounce),
  );

  Future<void> pump(
    WidgetTester t, {
    double scale = 1,
    Duration debounce = Duration.zero,
    Widget? home,
  }) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    ctl(debounce: debounce);
    await t.pumpWidget(
      GetMaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: home ?? const JuzReaderView(),
      ),
    );
    await t.pumpAndSettle();
    await t.pump(Duration.zero);
  }

  Finder card(int s, int n) => find.byWidgetPredicate(
    (w) => w is AyahCard && w.ayah.surahNumber == s && w.ayah.ayahNumber == n,
  );

  Future<void> reveal(WidgetTester t, Finder f) =>
      t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

  Future<void> tapIn(WidgetTester t, int s, int n, String label) async {
    final btn = find.descendant(
      of: card(s, n),
      matching: find.bySemanticsLabel(label),
    );
    await t.ensureVisible(btn);
    await t.pump();
    await t.tap(btn);
  }

  List<JuzItem> items() =>
      (Get.find<JuzReaderController>().state.value as UiData<List<JuzItem>>)
          .value;

  testWidgets('title, range subtitle, header without Basmalah at top', (
    t,
  ) async {
    await pump(t);
    expect(find.text('Juz 1'), findsOneWidget);
    expect(find.text('L1 2 – L3 40'), findsOneWidget);
    final first = items();
    expect(first[0], isA<SurahHeaderItem>());
    expect((first[0] as SurahHeaderItem).withBasmalah, isFalse);
    expect(find.byType(SurahHeaderCard), findsWidgets);
    expect(card(1, 2), findsOneWidget);
    expect(card(1, 1), findsNothing);
  });

  testWidgets('headers and Basmalah flags across surahs', (t) async {
    await pump(t);
    final h = items().whereType<SurahHeaderItem>().toList();
    expect(h.map((e) => e.surah.number), [1, 2, 3]);
    // Surah 1 never, 2 and 3 start at ayah 1 inside the juz.
    expect(h.map((e) => e.withBasmalah), [false, true, true]);
    expect(items().whereType<AyahItem>(), hasLength(2 + 3 + 40));
  });

  testWidgets('no audio controls are shown', (t) async {
    await pump(t);
    expect(find.bySemanticsLabel('Putar ayat'), findsNothing);
    expect(find.byTooltip('Menu ayat'), findsNothing);
    expect(find.text('Putar surah'), findsNothing);
  });

  testWidgets('bookmark is keyed by (surah, ayah)', (t) async {
    user.ayahBookmarks[3] = {2};
    await pump(t);
    final c = Get.find<JuzReaderController>();
    expect(c.bookmarked, {const AyahRef(3, 2)});
    c.toggleBookmark(_a(2, 2));
    expect(c.bookmarked, {const AyahRef(3, 2), const AyahRef(2, 2)});
    expect(user.ayahBookmarks[2], {2});
    expect(user.ayahBookmarks[3], {2});
    c.toggleBookmark(_a(3, 2));
    expect(c.bookmarked, {const AyahRef(2, 2)});
    expect(user.ayahBookmarks[3], isEmpty);
  });

  testWidgets('bookmark button flips only that ayah card', (t) async {
    await pump(t);
    await reveal(t, card(2, 2));
    await tapIn(t, 2, 2, 'Tambah bookmark');
    await t.pump();
    expect(user.ayahBookmarks[2], {2});
    expect(
      find.descendant(
        of: card(2, 2),
        matching: find.bySemanticsLabel('Hapus bookmark'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tafsir opens for an ayah of the second surah', (t) async {
    await pump(t);
    await reveal(t, card(2, 2));
    await tapIn(t, 2, 2, 'Lihat tafsir');
    await t.pumpAndSettle();
    expect(find.text('Tafsir Kemenag'), findsOneWidget);
    expect(find.text('L2 · ayat 2'), findsOneWidget);
    expect(find.text('tafsir2:2'), findsOneWidget);
    // Pages only through the ayat of that surah.
    await t.tap(find.text('Berikutnya'));
    await t.pump();
    await t.tap(find.text('Berikutnya'));
    await t.pump();
    expect(find.text('L2 · ayat 3'), findsOneWidget);
    expect(
      t
          .widget<TextButton>(find.widgetWithText(TextButton, 'Berikutnya'))
          .enabled,
      isFalse,
    );
  });

  testWidgets('copy puts the original text of that ayah', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(t);
    await reveal(t, card(2, 2));
    await tapIn(t, 2, 2, 'Salin ayat');
    await t.pump();
    expect(copied, 'arab2:2\n\ntrans2:2\n\nQS. L2: 2');
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  group('last read', () {
    Future<void> dragUp(WidgetTester t, {int times = 8}) async {
      final g = await t.startGesture(const Offset(180, 500));
      for (var i = 0; i < times; i++) {
        await g.moveBy(const Offset(0, -150));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await t.pumpAndSettle();
    }

    testWidgets('ayahRefAt maps item index to the real (surah, ayah)', (
      t,
    ) async {
      await pump(t);
      final c = Get.find<JuzReaderController>();
      // 0 H1, 1 1:2, 2 1:3, 3 H2, 4 2:1, 5 2:2, 6 2:3, 7 H3, 8 3:1
      expect(c.ayahRefAt(0), const AyahRef(1, 2));
      expect(c.ayahRefAt(3), const AyahRef(2, 1));
      expect(c.ayahRefAt(5), const AyahRef(2, 2));
      expect(c.ayahRefAt(7), const AyahRef(3, 1));
      expect(c.ayahRefAt(8), const AyahRef(3, 1));
    });

    testWidgets('opening does not overwrite last read', (t) async {
      user.lastRead = LastRead(
        ref: const AyahRef(2, 2),
        updatedAt: DateTime(2000),
      );
      await pump(t, debounce: const Duration(seconds: 3));
      await t.pump(const Duration(seconds: 5));
      Get.delete<JuzReaderController>();
      expect(user.lastReadWrites, isEmpty);
    });

    testWidgets('a real drag saves the visible ayah of its own surah', (
      t,
    ) async {
      await pump(t, debounce: const Duration(seconds: 3));
      await dragUp(t);
      await t.pump(const Duration(seconds: 3));
      expect(user.lastReadWrites, hasLength(1));
      final ref = user.lastReadWrites.single;
      // 640px of mixed content moves past surah 1; 1:2 would be wrong.
      expect(ref.surah, greaterThan(1));
      expect(
        _all.any((a) => a.surahNumber == ref.surah && a.ayahNumber == ref.ayah),
        isTrue,
      );
      final c = Get.find<JuzReaderController>();
      expect(c.ayahRefAt(c.listController.visibleRange!.$1), ref);
    });

    testWidgets('stored last read inside the juz is jumped to and marked', (
      t,
    ) async {
      user.lastRead = LastRead(
        ref: const AyahRef(3, 20),
        updatedAt: DateTime(2000),
      );
      await pump(t);
      expect(find.text('Terakhir dibaca'), findsOneWidget);
      expect(
        find.descendant(
          of: card(3, 20),
          matching: find.text('Terakhir dibaca'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reload without a stored last read clears the highlight', (
      t,
    ) async {
      user.lastRead = LastRead(
        ref: const AyahRef(3, 20),
        updatedAt: DateTime(2000),
      );
      await pump(t);
      final c = Get.find<JuzReaderController>();
      expect(c.lastRead.value, const AyahRef(3, 20));
      user.lastRead = null;
      await c.load();
      await t.pumpAndSettle();
      expect(c.lastRead.value, isNull);
      expect(find.text('Terakhir dibaca'), findsNothing);
    });

    testWidgets('closing the controller flushes a pending last read', (
      t,
    ) async {
      await pump(t, debounce: const Duration(seconds: 3));
      await dragUp(t);
      expect(user.lastReadWrites, isEmpty);
      Get.delete<JuzReaderController>();
      expect(user.lastReadWrites, hasLength(1));
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('popping the route disposes the controller and saves', (
      t,
    ) async {
      Get.reset();
      Get.put<QuranRepository>(
        FakeQuranRepository(
          surahs: [_s(1), _s(2), _s(3)],
          ayahs: _all,
          juz: const [
            Juz(
              number: 1,
              startSurah: 1,
              startAyah: 2,
              endSurah: 3,
              endAyah: 40,
            ),
          ],
        ),
      );
      Get.put<QuranRangeRepository>(FakeQuranRangeRepository(_all));
      Get.put<UserRepository>(user);
      Get.put(ThemeController());
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        GetMaterialApp(
          home: const Scaffold(body: Text('home')),
          getPages: [
            GetPage(
              name: Routes.juz,
              page: JuzReaderView.new,
              binding: JuzReaderBinding(),
            ),
          ],
        ),
      );
      unawaited(Get.toNamed<void>(Routes.juz, arguments: const JuzArgs(1)));
      await t.pumpAndSettle();
      expect(Get.isRegistered<JuzReaderController>(), isTrue);
      await dragUp(t);
      expect(user.lastReadWrites, isEmpty);
      Get.back<void>();
      await t.pumpAndSettle();
      expect(Get.isRegistered<JuzReaderController>(), isFalse);
      expect(user.lastReadWrites, hasLength(1));
    });

    testWidgets('same ayah number in another surah is not marked', (t) async {
      user.lastRead = LastRead(
        ref: const AyahRef(9, 2),
        updatedAt: DateTime(2000),
      );
      await pump(t);
      expect(find.text('Terakhir dibaca'), findsNothing);
    });
  });

  testWidgets('scroll position survives the tafsir sheet and another screen', (
    t,
  ) async {
    await pump(t);
    await reveal(t, card(3, 5));
    final tafsirBtn = find.descendant(
      of: card(3, 5),
      matching: find.bySemanticsLabel('Lihat tafsir'),
    );
    await t.ensureVisible(tafsirBtn);
    await t.pumpAndSettle();
    final c = Get.find<JuzReaderController>();
    final before = c.scrollController.offset;
    expect(before, greaterThan(0));
    await tapIn(t, 3, 5, 'Lihat tafsir');
    await t.pumpAndSettle();
    await t.tapAt(const Offset(180, 20)); // scrim
    await t.pumpAndSettle();
    expect(c.scrollController.offset, before);
    unawaited(Get.to<void>(() => const Scaffold(body: Text('other'))));
    await t.pumpAndSettle();
    Get.back<void>();
    await t.pumpAndSettle();
    expect(c.scrollController.offset, before);
  });

  testWidgets('worker failure shows error, retry reloads', (t) async {
    range.failure = const ContentUnavailable('worker');
    await pump(t);
    expect(find.byType(ErrorState), findsOneWidget);
    range.failure = null;
    await t.tap(find.text('Coba lagi'));
    await t.pumpAndSettle();
    expect(find.byType(ErrorState), findsNothing);
    expect(card(1, 2), findsOneWidget);
  });

  testWidgets('unknown juz shows error, empty range shows empty state', (
    t,
  ) async {
    Get.put(JuzReaderController(const JuzArgs(99)));
    await t.pumpWidget(const GetMaterialApp(home: JuzReaderView()));
    await t.pumpAndSettle();
    expect(find.byType(ErrorState), findsOneWidget);
    Get.reset();
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: [_s(1)],
        ayahs: [_a(1, 1)], // Basmalah source
        juz: const [
          Juz(number: 1, startSurah: 1, startAyah: 1, endSurah: 1, endAyah: 3),
        ],
      ),
    );
    Get.put<QuranRangeRepository>(FakeQuranRangeRepository(const []));
    Get.put<UserRepository>(FakeUserRepository());
    Get.put(ThemeController());
    Get.put(JuzReaderController(const JuzArgs(1)));
    await t.pumpWidget(const GetMaterialApp(home: JuzReaderView()));
    await t.pumpAndSettle();
    expect(find.text('Ayat belum tersedia'), findsOneWidget);
  });

  testWidgets('130% text, Arabic 36, 360x640: no overflow', (t) async {
    user.prefs = const ReadingPrefs(arabicFontSize: 36, showTranslation: true);
    user.lastRead = LastRead(
      ref: const AyahRef(2, 2),
      updatedAt: DateTime(2000),
    );
    await pump(t, scale: 1.3);
    expect(t.takeException(), isNull);
    await reveal(t, card(3, 3));
    expect(t.takeException(), isNull);
  });

  testWidgets('route opens through binding with JuzArgs', (t) async {
    Get.reset();
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: [_s(1), _s(2), _s(3)],
        ayahs: _all,
        juz: const [
          Juz(number: 1, startSurah: 1, startAyah: 2, endSurah: 3, endAyah: 40),
        ],
      ),
    );
    Get.put<QuranRangeRepository>(FakeQuranRangeRepository(_all));
    Get.put<UserRepository>(user);
    Get.put(ThemeController());
    await t.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: Text('home')),
        getPages: [
          GetPage(
            name: Routes.juz,
            page: JuzReaderView.new,
            binding: JuzReaderBinding(),
          ),
        ],
      ),
    );
    unawaited(Get.toNamed<void>(Routes.juz, arguments: const JuzArgs(1)));
    await t.pumpAndSettle();
    expect(find.text('Juz 1'), findsOneWidget);
    expect(card(1, 2), findsOneWidget);
  });

  testWidgets('tapping a juz in the Juz tab opens the reader', (t) async {
    Get.put<HadithRepository>(FakeHadithRepository());
    QuranListBinding().dependencies();
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: QuranListView()),
        getPages: [
          GetPage(
            name: Routes.juz,
            page: JuzReaderView.new,
            binding: JuzReaderBinding(),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Juz'));
    await t.pumpAndSettle();
    await t.tap(find.text('Juz 1'));
    await t.pumpAndSettle();
    expect(find.byType(JuzReaderView), findsOneWidget);
    expect(card(1, 2), findsOneWidget);
    expect(find.text('L1 2 – L3 40'), findsOneWidget);
  });
}
