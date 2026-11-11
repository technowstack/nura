import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/quran_detail/bindings/quran_detail_binding.dart';
import 'package:nura/app/modules/quran_detail/widgets/surah_header_card.dart';
import 'package:nura/app/modules/quran_detail/controllers/quran_detail_controller.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/modules/quran_detail/views/quran_detail_view.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';
import 'package:nura/app/modules/quran_detail/widgets/bismillah_header.dart';

import '../../../support/fake_repositories.dart';

Surah _s(int n, {int ayat = 3}) => Surah(
  number: n,
  nameArab: 'ArabSurah$n',
  nameLatin: 'Latin$n',
  nameId: 'Arti$n',
  ayahCount: ayat,
  revelation: 'makkiyah',
);

Ayah _a(int s, int n, {String? arab, String? tr}) => Ayah(
  surahNumber: s,
  ayahNumber: n,
  arab: arab ?? 'arab$s:$n',
  translation: tr ?? 'trans$s:$n',
  tafsir: 't',
);

const _basmalah = 'BASMALAH-FROM-REPO';

void main() {
  _robustnessTests();
  late FakeQuranRepository quran;
  late FakeUserRepository user;

  setUp(() {
    Get.reset();
    quran = FakeQuranRepository(
      surahs: [_s(1), _s(2), _s(9)],
      ayahs: [
        _a(1, 1, arab: _basmalah),
        _a(1, 2),
        _a(1, 3),
        _a(2, 1),
        _a(2, 2),
        _a(2, 3),
        _a(9, 1),
        _a(9, 2),
        _a(9, 3),
      ],
    );
    user = FakeUserRepository();
    Get.put<QuranRepository>(quran);
    Get.put<UserRepository>(user);
  });
  tearDown(Get.reset);

  Future<void> pumpPage(
    WidgetTester tester,
    int surah, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Get.put(QuranDetailController(SurahArgs(surah)));
    await tester.pumpWidget(
      GetMaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const QuranDetailView(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('surah 1 and 9 have no bismillah header', (tester) async {
    await pumpPage(tester, 1);
    expect(find.byType(BismillahHeader), findsNothing);
    Get.reset();
    Get.put<QuranRepository>(quran);
    Get.put<UserRepository>(user);
    await pumpPage(tester, 9);
    expect(find.byType(BismillahHeader), findsNothing);
  });

  testWidgets('surah 2 has one bismillah header with repo text', (t) async {
    await pumpPage(t, 2);
    expect(find.byType(BismillahHeader), findsOneWidget);
    expect(find.text(_basmalah), findsOneWidget);
    expect(find.text('Latin2 · 3 ayat'), findsOneWidget);
  });

  testWidgets('ayat follow repository order', (tester) async {
    await pumpPage(tester, 2);
    final ys = [
      for (final n in [1, 2, 3]) tester.getTopLeft(find.text('arab2:$n')).dy,
    ];
    expect(ys, [...ys]..sort());
  });

  Widget host(Widget child, {double scale = 1}) => MaterialApp(
    theme: AppTheme.light,
    builder: (c, w) => MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
      child: w ?? const SizedBox.shrink(),
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  const prefs = ReadingPrefs(arabicFontSize: 28, showTranslation: true);

  testWidgets('AyahCard renders text verbatim, translation toggle', (t) async {
    const arab = 'ab ‌ cd  ';
    const tr = 'terjemah  ‌ ';
    final ayah = _a(2, 5, arab: arab, tr: tr);
    Widget card(ReadingPrefs p) => host(
      AyahCard(
        ayah: ayah,
        bookmarked: false,
        lastRead: false,
        prefs: p,
        onBookmark: () {},
        onCopy: () {},
        onTafsir: () {},
      ),
    );
    await t.pumpWidget(card(prefs));
    expect(find.text(arab), findsOneWidget);
    expect(find.text(tr), findsOneWidget);
    await t.pumpWidget(
      card(const ReadingPrefs(arabicFontSize: 28, showTranslation: false)),
    );
    expect(find.text(arab), findsOneWidget);
    expect(find.text(tr), findsNothing);
  });

  testWidgets('bookmark tap toggles and icon/semantics change', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPage(tester, 2);
    expect(find.bySemanticsLabel('Tambah bookmark'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Tambah bookmark').first);
    await tester.pumpAndSettle();
    expect(user.ayahBookmarks[2], {1});
    expect(find.bySemanticsLabel('Hapus bookmark'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    handle.dispose();
  });

  testWidgets('bookmark twice returns to unbookmarked', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPage(tester, 2);
    await tester.tap(find.bySemanticsLabel('Tambah bookmark').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Hapus bookmark'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Hapus bookmark'), findsNothing);
    expect(find.byIcon(Icons.bookmark), findsNothing);
    expect(find.byIcon(Icons.bookmark_border), findsWidgets);
    expect(user.ayahBookmarks[2], isEmpty);
    handle.dispose();
  });

  testWidgets('very long ayah at 40pt and 130% scale does not overflow', (
    tester,
  ) async {
    quran.ayahs = [
      _a(1, 1, arab: _basmalah),
      _a(2, 1, arab: 'ن' * 1218, tr: 'kata ' * 334),
    ];
    quran.surahs = [_s(1), _s(2, ayat: 1)];
    user.prefs = const ReadingPrefs(arabicFontSize: 40, showTranslation: true);
    await pumpPage(tester, 2, scale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copyAyah puts formatted text on clipboard + snackbar', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPage(tester, 2);
    final c = Get.find<QuranDetailController>();
    await c.copyAyah(_a(2, 2, arab: 'A ', tr: ' T'));
    await tester.pump();
    expect(copied, 'A \n\n T\n\nQS. Latin2: 2');
    expect(find.text('Ayat disalin'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('ContentUnavailable shows ErrorState, retry reloads', (
    tester,
  ) async {
    quran.failure = const ContentUnavailable('x');
    await pumpPage(tester, 2);
    expect(find.byType(ErrorState), findsOneWidget);
    quran.failure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('arab2:1'), findsOneWidget);
  });
}

void _robustnessTests() {
  testWidgets('bookmark write failure keeps set and shows snackbar', (
    tester,
  ) async {
    Get.reset();
    final u = FakeUserRepository();
    Get.put<QuranRepository>(
      FakeQuranRepository(surahs: [_s(1)], ayahs: [_a(1, 1)]),
    );
    Get.put<UserRepository>(u);
    Get.put(QuranDetailController(const SurahArgs(1)));
    await tester.pumpWidget(const GetMaterialApp(home: QuranDetailView()));
    await tester.pumpAndSettle();
    u.failure = StateError('db');
    await tester.tap(find.byIcon(Icons.bookmark_border).first);
    await tester.pump();
    expect(Get.find<QuranDetailController>().bookmarked, isEmpty);
    expect(find.text('Gagal menyimpan bookmark'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('clipboard failure shows snackbar', (tester) async {
    Get.reset();
    Get.put<QuranRepository>(
      FakeQuranRepository(surahs: [_s(1)], ayahs: [_a(1, 1)]),
    );
    Get.put<UserRepository>(FakeUserRepository());
    Get.put(QuranDetailController(const SurahArgs(1)));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'x');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: QuranDetailView()));
    await tester.pumpAndSettle();
    await Get.find<QuranDetailController>().copyAyah(_a(1, 1));
    await tester.pump();
    expect(find.text('Gagal menyalin ayat'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('missing route arguments show error, not Al-Fatihah', (
    tester,
  ) async {
    Get.reset();
    Get.put<QuranRepository>(
      FakeQuranRepository(surahs: [_s(1)], ayahs: [_a(1, 1)]),
    );
    Get.put<UserRepository>(FakeUserRepository());
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/s',
        getPages: [
          GetPage(
            name: '/s',
            page: QuranDetailView.new,
            binding: QuranDetailBinding(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('arab1:1'), findsNothing);
    expect(find.byType(SurahHeaderCard), findsNothing);
    expect(find.byType(AyahCard), findsNothing);
  });

  testWidgets('user repo failing after content load shows error', (
    tester,
  ) async {
    Get.reset();
    Get.put<QuranRepository>(
      FakeQuranRepository(surahs: [_s(1)], ayahs: [_a(1, 1)]),
    );
    Get.put<UserRepository>(FakeUserRepository()..failure = StateError('x'));
    Get.put(QuranDetailController(const SurahArgs(1)));
    await tester.pumpWidget(const GetMaterialApp(home: QuranDetailView()));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsOneWidget);
  });
}
