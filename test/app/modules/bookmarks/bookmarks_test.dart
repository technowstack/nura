import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/widgets/empty_state.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/bookmark.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/modules/quran_list/bindings/quran_list_binding.dart';
import 'package:nura/app/modules/quran_list/views/quran_list_view.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';

Surah _s(int n) => Surah(
  number: n,
  nameArab: 'ArabSurah$n',
  nameLatin: 'Latin$n',
  nameId: 'Arti$n',
  ayahCount: 10,
  revelation: 'makkiyah',
);

Ayah _a(int s, int n) => Ayah(
  surahNumber: s,
  ayahNumber: n,
  arab: 'arab',
  translation: 'Terjemah $s:$n',
  tafsir: '',
);

int _sec = 0;

Bookmark _b(int s, int n) =>
    Bookmark(ref: AyahRef(s, n), createdAt: DateTime(2000, 1, 1, 0, 0, ++_sec));

void main() {
  late FakeQuranRepository quran;
  late FakeUserRepository user;
  Object? routeArgs;

  setUp(() {
    Get.reset();
    routeArgs = null;
    quran = FakeQuranRepository(
      surahs: [_s(1), _s(2), _s(3)],
      ayahs: [_a(1, 1), _a(2, 5), _a(3, 7)],
    );
    user = FakeUserRepository();
    Get.put<QuranRepository>(quran);
    Get.put<UserRepository>(user);
    QuranListBinding().dependencies();
  });
  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: QuranListView()),
        getPages: [
          GetPage(
            name: Routes.surah,
            page: () {
              routeArgs = Get.arguments;
              return const Scaffold(body: Text('stub surah'));
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmark'));
    await tester.pumpAndSettle();
  }

  testWidgets('three bookmarks show newest first', (tester) async {
    user.bookmarks.addAll([_b(3, 7), _b(1, 1), _b(2, 5)]);
    await pump(tester);
    expect(find.text('Latin3 · ayat 7'), findsOneWidget);
    expect(find.text('Terjemah 1:1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Latin3 · ayat 7')).dy,
      lessThan(tester.getTopLeft(find.text('Latin1 · ayat 1')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Latin1 · ayat 1')).dy,
      lessThan(tester.getTopLeft(find.text('Latin2 · ayat 5')).dy),
    );
  });

  testWidgets('empty shows Belum ada bookmark', (tester) async {
    await pump(tester);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Belum ada bookmark'), findsOneWidget);
  });

  testWidgets('missing ayah is skipped, others stay', (tester) async {
    user.bookmarks.addAll([_b(1, 1), _b(2, 99), _b(3, 7)]);
    await pump(tester);
    expect(find.text('Latin1 · ayat 1'), findsOneWidget);
    expect(find.text('Latin3 · ayat 7'), findsOneWidget);
    expect(find.textContaining('ayat 99'), findsNothing);
  });

  testWidgets('all skipped shows error state', (tester) async {
    user.bookmarks.add(_b(2, 99));
    await pump(tester);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Konten tidak dapat dibaca.'), findsOneWidget);
  });

  testWidgets('non-ContentUnavailable list failure shows ErrorState + retry', (
    tester,
  ) async {
    user.bookmarks.add(_b(1, 1));
    user.failure = StateError('x');
    await pump(tester);
    expect(find.byType(ErrorState), findsOneWidget);
    user.failure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Latin1 · ayat 1'), findsOneWidget);
  });

  testWidgets('tap opens route with SurahArgs', (tester) async {
    user.bookmarks.add(_b(2, 5));
    await pump(tester);
    await tester.tap(find.text('Latin2 · ayat 5'));
    await tester.pumpAndSettle();
    final args = routeArgs as SurahArgs;
    expect(args.surah, 2);
    expect(args.ayah, 5);
  });

  testWidgets('returning after toggleBookmark refreshes the list', (
    tester,
  ) async {
    user.toggleBookmark(const AyahRef(2, 5));
    await pump(tester);
    await tester.tap(find.text('Latin2 · ayat 5'));
    await tester.pumpAndSettle();
    user.toggleBookmark(const AyahRef(2, 5));
    user.toggleBookmark(const AyahRef(1, 1));
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.text('Latin2 · ayat 5'), findsNothing);
    expect(find.text('Latin1 · ayat 1'), findsOneWidget);
  });

  testWidgets('read failure shows ErrorState with retry', (tester) async {
    user.bookmarks.add(_b(1, 1));
    user.failure = const ContentUnavailable('x');
    await pump(tester);
    expect(find.byType(ErrorState), findsOneWidget);
    user.failure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Latin1 · ayat 1'), findsOneWidget);
  });

  testWidgets('Latin 130% at 360x640 with three bookmarks', (tester) async {
    quran.ayahs = [
      for (final r in [(1, 1), (2, 5), (3, 7)])
        Ayah(
          surahNumber: r.$1,
          ayahNumber: r.$2,
          arab: 'arab',
          translation: List.filled(30, 'terjemahan panjang').join(' '),
          tafsir: '',
        ),
    ];
    user.bookmarks.addAll([_b(3, 7), _b(1, 1), _b(2, 5)]);
    await pump(tester, scale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('· ayat'), findsNWidgets(3));
  });
}
