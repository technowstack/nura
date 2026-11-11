import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';
import 'package:nura/app/modules/quran_detail/widgets/tafsir_sheet.dart';

Ayah _a(int n, String tafsir) => Ayah(
  surahNumber: 2,
  ayahNumber: n,
  arab: 'arab$n',
  translation: 'trans$n',
  tafsir: tafsir,
);

final _longTafsir = [
  for (var i = 0; i < 1200; i++) 'baris $i xxxxxxxx',
].join('\n').padRight(19245, 'z').substring(0, 19245);

Future<void> _pump(WidgetTester tester, Widget home, {double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    ),
  );
}

Future<void> _open(
  WidgetTester tester,
  List<Ayah> ayahs,
  int index, {
  double scale = 1,
}) async {
  await _pump(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => showTafsirSheet(
          context,
          ayahs: ayahs,
          initialIndex: index,
          surahName: 'Latin2',
        ),
        child: const Text('open'),
      ),
    ),
    scale: scale,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _btn(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextButton));

void main() {
  final ayahs = [_a(1, 'tafsir satu'), _a(2, ''), _a(3, 'a\nb  ')];

  testWidgets('shows title, subtitle and exact tafsir', (tester) async {
    await _open(tester, ayahs, 0);
    expect(find.text('Tafsir Kemenag'), findsOneWidget);
    expect(find.text('Latin2 · ayat 1'), findsOneWidget);
    expect(find.text('tafsir satu'), findsOneWidget);
  });

  testWidgets('keeps newlines and spacing verbatim', (tester) async {
    await _open(tester, ayahs, 2);
    expect(find.text('a\nb  '), findsOneWidget);
  });

  testWidgets('long tafsir scrolls to the end without overflow', (
    tester,
  ) async {
    await _open(tester, [_a(1, _longTafsir)], 0);
    expect(find.text(_longTafsir), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -200000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final sheet = tester.getRect(find.byType(BottomSheet));
    final text = tester.getRect(find.text(_longTafsir));
    expect(text.bottom, lessThanOrEqualTo(sheet.bottom + 1));
  });

  testWidgets('prev disabled at first, next disabled at last', (tester) async {
    await _open(tester, ayahs, 0);
    expect(tester.widget<TextButton>(_btn('Sebelumnya')).onPressed, isNull);
    expect(tester.widget<TextButton>(_btn('Berikutnya')).onPressed, isNotNull);
    await tester.tap(_btn('Berikutnya'));
    await tester.pump();
    await tester.tap(_btn('Berikutnya'));
    await tester.pump();
    expect(tester.widget<TextButton>(_btn('Berikutnya')).onPressed, isNull);
    expect(tester.widget<TextButton>(_btn('Sebelumnya')).onPressed, isNotNull);
  });

  testWidgets('next shows following tafsir and subtitle', (tester) async {
    await _open(tester, ayahs, 0);
    await tester.tap(_btn('Berikutnya'));
    await tester.pump();
    expect(find.text('Latin2 · ayat 2'), findsOneWidget);
    expect(find.text('tafsir satu'), findsNothing);
  });

  testWidgets('empty tafsir shows placeholder', (tester) async {
    await _open(tester, ayahs, 1);
    expect(find.text('Tafsir belum tersedia untuk ayat ini'), findsOneWidget);
  });

  testWidgets('sheet height is at most 90% of screen', (tester) async {
    await _open(tester, [_a(1, _longTafsir)], 0);
    expect(
      tester.getSize(find.byType(BottomSheet)).height,
      lessThanOrEqualTo(576),
    );
  });

  testWidgets('scrim uses scrim color at alpha 0.32', (tester) async {
    await _open(tester, ayahs, 0);
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(
      barrier.color,
      AppTheme.light.colorScheme.scrim.withValues(alpha: 0.32),
    );
  });

  testWidgets('tafsir icon on AyahCard opens the right ayah', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => AyahCard(
            ayah: ayahs[2],
            bookmarked: false,
            lastRead: false,
            prefs: const ReadingPrefs(
              arabicFontSize: 28,
              showTranslation: true,
            ),
            onBookmark: () {},
            onCopy: () {},
            onTafsir: () => showTafsirSheet(
              context,
              ayahs: ayahs,
              initialIndex: 2,
              surahName: 'Latin2',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Lihat tafsir'));
    await tester.pumpAndSettle();
    expect(find.text('Latin2 · ayat 3'), findsOneWidget);
  });

  testWidgets('Latin 130% at 360x640 has no exception', (tester) async {
    await _open(tester, ayahs, 1, scale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.tap(_btn('Berikutnya'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
