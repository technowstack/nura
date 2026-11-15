import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/core/widgets/empty_state.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/hadith_detail/hadith_detail_args.dart';
import 'package:nura/app/modules/hadith_list/bindings/hadith_list_binding.dart';
import 'package:nura/app/modules/hadith_list/controllers/hadith_list_controller.dart';
import 'package:nura/app/modules/hadith_list/hadith_list_args.dart';
import 'package:nura/app/modules/hadith_list/views/hadith_list_view.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';

const _slug = 'bukhari';

List<HadithSummary> _rows(int n, {String Function(int)? preview}) => [
  for (var i = 1; i <= n; i++)
    HadithSummary(
      ref: HadithRef(_slug, i),
      preview: preview?.call(i) ?? 'Isi hadis $i',
      length: 10,
    ),
];

void main() {
  late FakeHadithRepository repo;
  late FakeUserRepository user;
  Object? detailArgs;

  setUp(() {
    Get.reset();
    detailArgs = null;
    repo = FakeHadithRepository(summaries: {_slug: _rows(65)});
    user = FakeUserRepository();
    Get.put<HadithRepository>(repo);
    Get.put<UserRepository>(user);
  });
  tearDown(Get.reset);

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    bool args = true,
    VoidCallback? onDetail,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: Text('home')),
        getPages: [
          GetPage(
            name: Routes.hadithList,
            page: HadithListView.new,
            binding: HadithListBinding(),
          ),
          GetPage(
            name: Routes.hadithDetail,
            page: () {
              detailArgs = Get.arguments;
              onDetail?.call();
              return const Scaffold(body: Text('stub detail'));
            },
          ),
        ],
      ),
    );
    Get.toNamed(
      Routes.hadithList,
      arguments: args ? const HadithListArgs(_slug, 'Shahih Bukhari') : null,
    );
    await tester.pumpAndSettle();
  }

  HadithListController ctl() => Get.find<HadithListController>();
  List<HadithListItem> list() =>
      (ctl().items.value as UiData<List<HadithListItem>>).value;
  int count() => list().length;

  Future<void> toEnd(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, -20000), 8000);
    await tester.pumpAndSettle();
  }

  testWidgets('first page 30 items, title is book name', (tester) async {
    await pump(tester);
    expect(find.text('Shahih Bukhari'), findsOneWidget);
    expect(find.text('No. 1'), findsOneWidget);
    expect(count(), 30);
  });

  testWidgets('scrolling to the end loads page 2 without duplicates', (
    tester,
  ) async {
    await pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(repo.listPageCalls, 2);
    expect(count(), 60);
    final nums = [for (final i in list()) i.ref.number];
    expect(nums.toSet().length, nums.length);
  });

  testWidgets('65 rows: 30, 60, 65 and hasMore false', (tester) async {
    await pump(tester);
    expect(count(), 30);
    await ctl().loadMore();
    expect(count(), 60);
    expect(ctl().hasMore.value, isTrue);
    await ctl().loadMore();
    expect(count(), 65);
    expect(ctl().hasMore.value, isFalse);
  });

  testWidgets('exactly 60 rows ends without a third empty page', (
    tester,
  ) async {
    repo.summaries = {_slug: _rows(60)};
    await pump(tester);
    await ctl().loadMore();
    expect(count(), 60);
    expect(ctl().hasMore.value, isFalse);
    final calls = repo.listPageCalls;
    await ctl().loadMore();
    expect(repo.listPageCalls, calls);
  });

  testWidgets('repeated loadMore triggers load a single page', (tester) async {
    await pump(tester);
    final before = repo.listPageCalls;
    final f = [ctl().loadMore(), ctl().loadMore(), ctl().loadMore()];
    await Future.wait(f);
    expect(repo.listPageCalls, before + 1);
    expect(count(), 60);
  });

  testWidgets('page 2 failure keeps items, retry row loads page 2', (
    tester,
  ) async {
    repo.failPageCalls = {2};
    await pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(count(), 30);
    expect(ctl().loadMoreFailed.value, isTrue);
    final retry = find.text('Gagal memuat, ketuk untuk mencoba lagi');
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(repo.listPageCalls, 3);
    expect(count(), 60);
    expect(ctl().loadMoreFailed.value, isFalse);
  });

  testWidgets('keyset paging uses the last number, not the count', (
    tester,
  ) async {
    repo.summaries = {
      _slug: [
        for (var i = 1; i <= 65; i++)
          HadithSummary(
            ref: HadithRef(_slug, i * 7),
            preview: 'p$i',
            length: 1,
          ),
      ],
    };
    await pump(tester);
    await ctl().loadMore();
    expect(repo.afterNumbers, [0, 210]);
    expect(list()[30].numberLabel, 'No. 217');
    final nums = [for (final i in list()) i.ref.number];
    expect(nums, [for (var i = 1; i <= 60; i++) i * 7]);
  });

  testWidgets('load() during an in-flight loadMore drops the stale page', (
    tester,
  ) async {
    await pump(tester);
    final gate = Completer<void>();
    repo.pageGate = gate;
    final stale = ctl().loadMore();
    await tester.pump();
    expect(ctl().loadingMore.value, isTrue);
    ctl().load();
    await tester.pumpAndSettle();
    gate.complete();
    await stale;
    await tester.pumpAndSettle();
    expect(
      [for (final i in list()) i.ref.number],
      [for (var i = 1; i <= 30; i++) i],
    );
    expect(ctl().loadingMore.value, isFalse);
    expect(ctl().loadMoreFailed.value, isFalse);
    expect(ctl().hasMore.value, isTrue);
    await ctl().loadMore(); // not stuck busy
    expect(count(), 60);
  });

  testWidgets('empty book shows EmptyState', (tester) async {
    repo.summaries = {_slug: const []};
    await pump(tester);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  for (final e in <Object>[const ContentUnavailable('x'), StateError('boom')]) {
    testWidgets('first page ${e.runtimeType} shows ErrorState with retry', (
      tester,
    ) async {
      repo.failure = e;
      await pump(tester);
      expect(find.byType(ErrorState), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('No. 1'), findsOneWidget);
    });
  }

  testWidgets('numbering gaps and exact preview are shown as-is', (
    tester,
  ) async {
    repo.summaries = {
      _slug: [
        for (final n in [1, 2, 50])
          HadithSummary(
            ref: HadithRef(_slug, n),
            preview: '  spasi $n  ',
            length: 5,
          ),
      ],
    };
    await pump(tester);
    expect(find.text('No. 50'), findsOneWidget);
    expect(find.text('No. 3'), findsNothing);
    expect(find.text('  spasi 50  '), findsOneWidget);
  });

  testWidgets('markers follow bookmarks and refresh after detail', (
    tester,
  ) async {
    final sem = tester.ensureSemantics();
    user.toggleHadithBookmark(const HadithRef(_slug, 2));
    await pump(tester);
    expect(find.bySemanticsLabel(RegExp('Ditandai')), findsOneWidget);
    await tester.tap(find.text('No. 1'));
    await tester.pumpAndSettle();
    user.toggleHadithBookmark(const HadithRef(_slug, 3));
    Get.back();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Ditandai')), findsNWidgets(2));
    sem.dispose();
  });

  testWidgets('user repository failure does not break the list', (
    tester,
  ) async {
    final sem = tester.ensureSemantics();
    user.failure = StateError('db');
    await pump(tester);
    expect(find.text('No. 1'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Ditandai')), findsNothing);
    sem.dispose();
  });

  testWidgets('missing route arguments show an error, not another book', (
    tester,
  ) async {
    await pump(tester, args: false);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(repo.listPageCalls, 0);
  });

  testWidgets('tapping an item opens detail with its args', (tester) async {
    await pump(tester);
    await tester.tap(find.text('No. 2'));
    await tester.pumpAndSettle();
    expect(detailArgs, isA<HadithDetailArgs>());
    final a = detailArgs as HadithDetailArgs;
    expect(a.slug, _slug);
    expect(a.number, 2);
  });

  testWidgets('Latin 130% with long previews at 360x640', (tester) async {
    repo.summaries = {_slug: _rows(65, preview: (i) => 'kata panjang ' * 40)};
    await pump(tester, scale: 1.3);
    await toEnd(tester);
    expect(tester.takeException(), isNull);
  });
}
