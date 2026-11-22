import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/widgets/empty_state.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/modules/hadith_books/widgets/hadith_book_tile.dart';
import 'package:nura/app/data/models/hadith_book.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/modules/hadith_books/bindings/hadith_books_binding.dart';
import 'package:nura/app/modules/hadith_books/views/hadith_books_view.dart';
import 'package:nura/app/modules/hadith_list/hadith_list_args.dart';
import 'package:nura/app/modules/search/search_args.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';

const _names = [
  'Shahih Bukhari',
  'Shahih Muslim',
  'Sunan Abu Daud',
  'Sunan Tirmidzi',
  'Sunan Nasai',
  'Sunan Ibnu Majah',
  'Musnad Ahmad',
  'Muwatha Malik',
  'Sunan Darimi',
];

List<HadithBook> _books() => [
  for (var i = 0; i < _names.length; i++)
    HadithBook(
      slug: 'slug$i',
      name: _names[i],
      hadithCount: i == 0 ? 6638 : 100 + i,
      sortOrder: i + 1,
    ),
];

void main() {
  late FakeHadithRepository repo;
  Object? routeArgs;

  setUp(() {
    Get.reset();
    routeArgs = null;
    repo = FakeHadithRepository(books: _books());
    Get.put<HadithRepository>(repo);
    HadithBooksBinding().dependencies();
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
        home: const Scaffold(body: HadithBooksView()),
        getPages: [
          GetPage(
            name: Routes.hadithList,
            page: () {
              routeArgs = Get.arguments;
              return const Scaffold(body: Text('stub list'));
            },
          ),
          GetPage(
            name: Routes.search,
            page: () {
              routeArgs = Get.arguments;
              return const Scaffold(body: Text('stub search'));
            },
          ),
        ],
      ),
    );
  }

  testWidgets('shows loading, then nine books with counts', (tester) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Shahih Bukhari'), findsOneWidget);
    expect(find.text('6.638 hadis'), findsOneWidget);
    expect(find.text('Shahih Muslim'), findsOneWidget);
  });

  testWidgets('orders books by sortOrder', (tester) async {
    repo.books = _books().reversed.toList();
    await pump(tester);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Shahih Bukhari')).dy,
      lessThan(tester.getTopLeft(find.text('Shahih Muslim')).dy),
    );
  });

  testWidgets('ContentUnavailable shows ErrorState and retry reloads', (
    tester,
  ) async {
    repo.failure = const ContentUnavailable('x');
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Shahih Bukhari'), findsOneWidget);
  });

  testWidgets('unexpected exception shows ErrorState and retry recovers', (
    tester,
  ) async {
    repo.failure = StateError('x');
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ErrorState), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Shahih Bukhari'), findsOneWidget);
  });

  testWidgets('empty list shows EmptyState', (tester) async {
    repo.books = const [];
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('tapping a book opens the list route with args', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shahih Muslim'));
    await tester.pumpAndSettle();
    expect(find.text('stub list'), findsOneWidget);
    final args = routeArgs! as HadithListArgs; // set by the stub route above
    expect(args.slug, 'slug1');
    expect(args.bookName, 'Shahih Muslim');
  });

  testWidgets('Latin 130% at 360x640 does not throw', (tester) async {
    await pump(tester, scale: 1.3);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Shahih Bukhari'), findsOneWidget);
  });

  testWidgets('book tile is at least 48 dp tall', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    final tiles = find.byType(HadithBookTile);
    expect(tiles, findsWidgets);
    for (final e in tiles.evaluate()) {
      expect(
        tester.getSize(find.byElementPredicate((x) => x == e)).height,
        greaterThanOrEqualTo(48),
      );
    }
  });

  testWidgets('book tile at 130% does not overflow', (tester) async {
    await pump(tester, scale: 1.3);
    await tester.pumpAndSettle();
    expect(find.byType(HadithBookTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search icon opens search with hadith scope', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cari'));
    await tester.pumpAndSettle();
    expect(find.text('stub search'), findsOneWidget);
    expect((routeArgs as SearchArgs).scope, SearchScope.hadith);
  });
}
