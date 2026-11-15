import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/core/widgets/empty_state.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/bookmark.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/bookmarks/controllers/bookmark_item.dart';
import 'package:nura/app/modules/bookmarks/controllers/bookmarks_controller.dart';
import 'package:nura/app/modules/hadith_detail/hadith_detail_args.dart';
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

Hadith _h(int n, {String? tr}) => Hadith(
  ref: HadithRef('bukhari', n),
  bookName: 'Shahih Bukhari',
  arab: 'arab$n',
  translation: tr ?? 'Hadis $n',
  translationLength: (tr ?? 'Hadis $n').length,
  arabTruncated: false,
  translationTruncated: false,
);

HadithBookmark _hb(int n, DateTime t) =>
    HadithBookmark(ref: HadithRef('bukhari', n), createdAt: t);

int _sec = 0;

Bookmark _b(int s, int n) =>
    Bookmark(ref: AyahRef(s, n), createdAt: DateTime(2000, 1, 1, 0, 0, ++_sec));

void main() {
  late FakeQuranRepository quran;
  late FakeUserRepository user;
  late FakeHadithRepository hadith;
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
    hadith = FakeHadithRepository(hadith: [_h(34), _h(35)]);
    Get.put<UserRepository>(user);
    Get.put<HadithRepository>(hadith);
    QuranListBinding().dependencies();
  });
  tearDown(Get.reset);

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    double height = 640,
  }) async {
    tester.view.physicalSize = Size(360, height);
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
          GetPage(
            name: Routes.hadithDetail,
            page: () {
              routeArgs = Get.arguments;
              return const Scaffold(body: Text('stub hadith'));
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
    user.bookmarks.addAll([
      Bookmark(ref: const AyahRef(3, 7), createdAt: DateTime(2000, 1, 3)),
      Bookmark(ref: const AyahRef(1, 1), createdAt: DateTime(2000, 1, 2)),
      Bookmark(ref: const AyahRef(2, 5), createdAt: DateTime(2000, 1, 1)),
    ]);
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

  final t0 = DateTime(2001, 1, 1);
  DateTime at(int s) => t0.add(Duration(seconds: s));
  Bookmark ab(int s, int n, DateTime t) =>
      Bookmark(ref: AyahRef(s, n), createdAt: t);

  double top(WidgetTester tester, String t) =>
      tester.getTopLeft(find.text(t)).dy;

  testWidgets('mixed ayah and hadith are newest first', (tester) async {
    user.bookmarks.addAll([ab(1, 1, at(1)), ab(2, 5, at(3))]);
    user.hadithBookmarks.addAll([_hb(34, at(4)), _hb(35, at(2))]);
    await pump(tester);
    final order = [
      'HR. Shahih Bukhari No. 34',
      'Latin2 · ayat 5',
      'HR. Shahih Bukhari No. 35',
      'Latin1 · ayat 1',
    ];
    for (var i = 0; i < order.length - 1; i++) {
      expect(top(tester, order[i]), lessThan(top(tester, order[i + 1])));
    }
  });

  testWidgets('same timestamp puts ayah before hadith', (tester) async {
    user.hadithBookmarks.add(_hb(34, at(1)));
    user.bookmarks.add(ab(1, 1, at(1)));
    await pump(tester);
    expect(
      top(tester, 'Latin1 · ayat 1'),
      lessThan(top(tester, 'HR. Shahih Bukhari No. 34')),
    );
  });

  testWidgets('hadith tile shows reference and two-line translation', (
    tester,
  ) async {
    final long = List.filled(40, 'kata panjang').join(' ');
    hadith.hadith = [_h(34, tr: long)];
    user.hadithBookmarks.add(_hb(34, at(1)));
    await pump(tester);
    expect(find.text('HR. Shahih Bukhari No. 34'), findsOneWidget);
    final w = tester.widget<Text>(find.text(long));
    expect(w.maxLines, 2);
    expect(w.overflow, TextOverflow.ellipsis);
  });

  testWidgets('tap hadith opens detail with HadithDetailArgs', (tester) async {
    user.hadithBookmarks.add(_hb(34, at(1)));
    await pump(tester);
    await tester.tap(find.text('HR. Shahih Bukhari No. 34'));
    await tester.pumpAndSettle();
    final args = routeArgs as HadithDetailArgs;
    expect(args.slug, 'bukhari');
    expect(args.number, 34);
  });

  testWidgets('missing hadith is skipped, others stay', (tester) async {
    user.hadithBookmarks.addAll([_hb(34, at(1)), _hb(99, at(2))]);
    await pump(tester);
    expect(find.text('HR. Shahih Bukhari No. 34'), findsOneWidget);
    expect(find.textContaining('No. 99'), findsNothing);
  });

  testWidgets('all hadith failing shows ErrorState', (tester) async {
    user.hadithBookmarks.add(_hb(99, at(1)));
    await pump(tester);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Konten tidak dapat dibaca.'), findsOneWidget);
  });

  testWidgets('removing hadith bookmark in detail updates list on return', (
    tester,
  ) async {
    user.hadithBookmarks.addAll([_hb(34, at(1)), _hb(35, at(2))]);
    await pump(tester);
    await tester.tap(find.text('HR. Shahih Bukhari No. 34'));
    await tester.pumpAndSettle();
    user.toggleHadithBookmark(const HadithRef('bukhari', 34));
    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.text('HR. Shahih Bukhari No. 34'), findsNothing);
    expect(find.text('HR. Shahih Bukhari No. 35'), findsOneWidget);
  });

  testWidgets('hadith list failure shows ErrorState and retry works', (
    tester,
  ) async {
    user.bookmarks.add(_b(1, 1));
    user.hadithBookmarks.add(_hb(34, at(1)));
    user.failure = const UserDataUnavailable('x');
    await pump(tester);
    expect(find.byType(ErrorState), findsOneWidget);
    user.failure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Latin1 · ayat 1'), findsOneWidget);
    expect(find.text('HR. Shahih Bukhari No. 34'), findsOneWidget);
  });

  testWidgets('stale slow read does not overwrite a newer read', (
    tester,
  ) async {
    await pump(tester);
    user.hadithBookmarks.add(_hb(34, at(1)));
    final gate = Completer<void>();
    hadith.hadithGates[34] = gate;
    final c = Get.find<BookmarksController>()..load();
    await tester.pump();
    await tester.pump();
    // First read is stuck on the gate; change data and start a newer read.
    user.hadithBookmarks
      ..clear()
      ..add(_hb(35, at(2)));
    hadith.hadithGates.clear();
    c.load();
    await tester.pumpAndSettle();
    expect(find.text('HR. Shahih Bukhari No. 35'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('HR. Shahih Bukhari No. 35'), findsOneWidget);
    expect(find.text('HR. Shahih Bukhari No. 34'), findsNothing);
  });

  testWidgets('16K-char hadith translation at 130% does not break', (
    tester,
  ) async {
    final big = List.filled(16384 ~/ 4, 'kata').join(' ').substring(0, 16384);
    hadith.hadith = [_h(34, tr: big)];
    user.hadithBookmarks.add(_hb(34, at(1)));
    await pump(tester, scale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('HR. Shahih Bukhari No. 34'), findsOneWidget);
    final w = tester.widget<Text>(find.text(big));
    expect(w.maxLines, 2);
    expect(w.overflow, TextOverflow.ellipsis);
  });

  testWidgets('Latin 130% with three ayah and three hadith', (tester) async {
    final long = List.filled(30, 'terjemahan panjang').join(' ');
    quran.ayahs = [
      for (final r in [(1, 1), (2, 5), (3, 7)])
        Ayah(
          surahNumber: r.$1,
          ayahNumber: r.$2,
          arab: 'arab',
          translation: long,
          tafsir: '',
        ),
    ];
    hadith.hadith = [
      for (final n in [34, 35, 36]) _h(n, tr: long),
    ];
    user.bookmarks.addAll([_b(3, 7), _b(1, 1), _b(2, 5)]);
    user.hadithBookmarks.addAll([
      for (final n in [34, 35, 36]) _hb(n, at(n)),
    ]);
    await pump(tester, scale: 1.3, height: 2400);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('· ayat'), findsNWidgets(3));
    expect(find.textContaining('HR. '), findsNWidgets(3));
  });

  testWidgets('equal timestamps keep ayah-then-hadith source order (80)', (
    tester,
  ) async {
    quran.ayahs = [for (var n = 1; n <= 40; n++) _a(1, n)];
    hadith.hadith = [for (var n = 1; n <= 40; n++) _h(n)];
    user.bookmarks.addAll([for (var n = 1; n <= 40; n++) ab(1, n, at(1))]);
    user.hadithBookmarks.addAll([for (var n = 1; n <= 40; n++) _hb(n, at(1))]);
    await pump(tester);
    final state = Get.find<BookmarksController>().items.value;
    final list = (state as UiData<List<BookmarkItem>>).value;
    expect(list, hasLength(80));
    expect(list.map((e) => e.title).toList(), [
      for (var n = 1; n <= 40; n++) 'Latin1 · ayat $n',
      for (var n = 1; n <= 40; n++) 'HR. Shahih Bukhari No. $n',
    ]);
  });

  testWidgets('superseded read stops calling getHadith', (tester) async {
    await pump(tester);
    user.hadithBookmarks.addAll([
      for (var n = 100; n < 120; n++) _hb(n, at(n)),
    ]);
    final gate = Completer<void>();
    hadith.hadithGates[100] = gate;
    final c = Get.find<BookmarksController>()..load();
    await tester.pump();
    await tester.pump();
    user.hadithBookmarks.clear();
    c.load();
    await tester.pumpAndSettle();
    final before = hadith.getHadithCalls;
    gate.complete();
    await tester.pumpAndSettle();
    expect(hadith.getHadithCalls, before);
  });
}
