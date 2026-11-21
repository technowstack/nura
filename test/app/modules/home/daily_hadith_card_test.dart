import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/modules/home/widgets/daily_card.dart';

DailyContent _c(String ref) => DailyContent(
  kind: DailyKind.hadith,
  arab: 'إنما الأعمال بالنيات',
  translation: 'Sesungguhnya amal itu tergantung niatnya.',
  reference: ref,
  deepLink: 'x',
);

Future<void> _pump(
  WidgetTester t,
  String ref,
  VoidCallback onOpen, {
  double scale = 1,
}) async {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: DailyHadithCard(content: _c(ref), onOpen: onOpen),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const ref = 'HR. Muslim No. 4360';
  final link = find.widgetWithText(TextButton, 'Baca selengkapnya');

  testWidgets('reference and link share one row, link triggers onOpen', (
    t,
  ) async {
    var n = 0;
    await _pump(t, ref, () => n++);
    final r = find.widgetWithText(TextButton, ref);
    expect(r, findsOneWidget);
    expect(link, findsOneWidget);
    expect(t.getCenter(r).dy, t.getCenter(link).dy);
    expect(t.getCenter(r).dx, lessThan(t.getCenter(link).dx));
    await t.tap(link);
    await t.tap(r);
    expect(n, 2);
  });

  testWidgets('long reference ellipsizes without overflow', (t) async {
    await _pump(t, 'HR. ${'Sunan Ibnu Majah ' * 6}No. 4360', () {});
    expect(t.takeException(), isNull);
    final txt = t.widget<Text>(
      find.descendant(
        of: find.byType(TextButton).first,
        matching: find.byType(Text),
      ),
    );
    expect(txt.overflow, TextOverflow.ellipsis);
    expect(t.getCenter(find.byType(TextButton).first).dy, t.getCenter(link).dy);
  });

  testWidgets('130% text scale at 360x640 does not overflow', (t) async {
    await _pump(t, ref, () {}, scale: 1.3);
    expect(t.takeException(), isNull);
  });
}
