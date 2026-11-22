import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/modules/home/widgets/daily_card.dart';

import 'hadith_variants/data.dart';
import 'hadith_variants/screens.dart';

const _enabled = bool.fromEnvironment('RENDER_HADITH_VARIANTS');
const _out = 'docs/review/hadith-variants';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await l.load();
}

void main() {
  testWidgets(
    'render hadith design variants',
    (tester) async {
      await _font('Plus Jakarta Sans', [
        for (final w in ['Regular', 'Medium', 'SemiBold'])
          'assets/fonts/PlusJakartaSans/PlusJakartaSans-$w.ttf',
      ]);
      await _font('Scheherazade New', [
        'assets/fonts/ScheherazadeNew/ScheherazadeNew-Regular.ttf',
      ]);
      final pkg = Platform.environment['HOME'] ?? '';
      await _font('packages/material_symbols_icons/MaterialSymbolsRounded', [
        '$pkg/.pub-cache/hosted/pub.dev/material_symbols_icons-4.2960.0/lib/fonts/MaterialSymbolsRounded.ttf',
      ]);

      final bukhari = loadBukhari();
      final list = bukhari.take(6).toList();
      final detail = bukhari[13];
      final d = loadDaily();
      final daily = DailyContent(
        kind: DailyKind.hadith,
        arab: d.arab,
        translation: d.tr,
        reference: d.ref,
        deepLink: '',
      );

      final key = GlobalKey();
      Future<void> shot(Widget w, double h, String name, bool dark) async {
        tester.view
          ..physicalSize = Size(360 * 2, h * 2)
          ..devicePixelRatio = 2;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (c, child) => RepaintBoundary(
              key: key,
              child: MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: child!,
              ),
            ),
            home: w,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final b =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 2);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          final dir = '$_out/${dark ? 'dark' : 'light'}';
          File('$dir/$name-${dark ? 'dark' : 'light'}.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data!.buffer.asUint8List());
        });
      }

      for (final dark in [false, true]) {
        await shot(const KitabScreen(), 880, 'kitab', dark);
        await shot(ListA(items: list), 860, 'daftar-A', dark);
        await shot(ListB(items: list), 700, 'daftar-B', dark);
        await shot(DetailA(hadith: detail), 1140, 'detail-A', dark);
        await shot(DetailB(hadith: detail), 1340, 'detail-B', dark);
        await shot(
          Builder(
            builder: (c) => ColoredBox(
              color: c.nuraColors.hero,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(c).colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.topCenter,
                      child: DailyHadithCard(content: daily, onOpen: () {}),
                    ),
                  ),
                ],
              ),
            ),
          ),
          460,
          'harian',
          dark,
        );
      }
      addTearDown(tester.view.reset);
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
