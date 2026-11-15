import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/models/prayer_regions.dart';
import 'package:nura/app/modules/prayer/widgets/region_picker_view.dart';
import 'package:get/get.dart';

final _regions = PrayerRegions({
  'DKI Jakarta': ['Kota Jakarta', 'Kab. Kepulauan Seribu'],
  'Papua': ['Kota Jayapura'],
});

Future<void> open(WidgetTester tester, {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GetMaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            picked = await Navigator.of(context).push<PrayerRegion>(
              MaterialPageRoute(
                builder: (_) => RegionPickerView(regions: _regions),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

PrayerRegion? picked;

void main() {
  setUp(() => picked = null);
  tearDown(Get.reset);

  testWidgets('provinces then kab/kota then select', (tester) async {
    await open(tester);
    expect(find.text('DKI Jakarta'), findsOneWidget);
    expect(find.text('Papua'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(ListTile, 'Papua')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('DKI Jakarta'));
    await tester.pumpAndSettle();
    expect(find.text('Kota Jakarta'), findsOneWidget);
    expect(find.text('Kota Jayapura'), findsNothing);
    await tester.tap(find.text('Kota Jakarta'));
    await tester.pumpAndSettle();
    expect(picked?.kabkota, 'Kota Jakarta');
    expect(picked?.zone, PrayerZone.wib);
  });

  testWidgets('back from a province returns to the province list', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Papua'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('DKI Jakarta'), findsOneWidget);
    expect(find.text('Kota Jayapura'), findsNothing);
  });

  testWidgets('search is case-insensitive and narrows', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'JAYA');
    await tester.pumpAndSettle();
    expect(find.text('Kota Jayapura'), findsOneWidget);
    expect(find.text('Kota Jakarta'), findsNothing);
    await tester.tap(find.text('Kota Jayapura'));
    await tester.pumpAndSettle();
    expect(picked?.zone, PrayerZone.wit);
  });

  testWidgets('no match shows the empty state', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Wilayah tidak ditemukan'), findsOneWidget);
  });

  testWidgets('130% text at 360x640 does not overflow', (tester) async {
    await open(tester, scale: 1.3);
    await tester.tap(find.text('DKI Jakarta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
