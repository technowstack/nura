import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/attributions.dart';
import 'package:nura/app/core/font_licenses.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/modules/settings/views/attribution_view.dart';

const _tanzil =
    'Pemetaan juz: Tanzil.info (metadata Tanzil, Creative Commons '
    'Attribution 3.0; kredit ke Tanzil.info, tautan lisensi '
    'https://creativecommons.org/licenses/by/3.0/, data diformat ulang)';

void main() {
  Future<void> pump(
    WidgetTester t, {
    double scale = 1,
    ThemeData? theme,
  }) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      GetMaterialApp(
        theme: theme ?? AppTheme.light,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const AttributionView(),
      ),
    );
    await t.pump();
  }

  Future<void> reveal(WidgetTester t, Finder f) =>
      t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

  testWidgets('every entry shows its exact texts', (t) async {
    await pump(t);
    for (final a in kAttributions) {
      for (final s in [a.title, ...a.credits, a.licenseNote, ...a.links]) {
        await reveal(t, find.text(s));
        expect(find.text(s), findsOneWidget, reason: s);
      }
    }
    expect(kAttributions.expand((a) => a.credits), contains(_tanzil));
    expect(
      kAttributions.expand((a) => a.credits),
      containsAll([
        'Audio: EQuran.id (sumber: Verse By Verse Quran)',
        'Tempat turun surah: EQuran.id (sumber Kemenag)',
      ]),
    );
  });

  test('every attribution is backed by the PRD or data-source README', () {
    final docs =
        File('docs/PRD.md').readAsStringSync() +
        File('data-source/README.md').readAsStringSync();
    for (final k in [
      'Kementerian Agama',
      'gadingnst/hadith-api',
      'tafsirq.com',
      'equran.id',
      'Tanzil',
      'Verse By Verse Quran',
      'Plus Jakarta Sans',
      'disusun pemilik proyek',
    ]) {
      expect(docs.toLowerCase(), contains(k.toLowerCase()), reason: k);
    }
    final readme = File('data-source/README.md').readAsStringSync();
    expect(readme, contains('creativecommons.org/licenses/by/3.0'));
    expect(readme, contains('diformat ulang'));
    // Backed by README/PRD text.
    expect(docs, contains('Kementerian Agama'));
    expect(docs, contains('Kemenag'));
    // 'Bimas Islam Kemenag' is only in the owner brief / phase plan (D3),
    // not in the README or PRD.
    for (final f in ['attributions.dart', 'font_licenses.dart']) {
      expect(
        File('lib/app/core/$f').readAsStringSync(),
        isNot(contains('fontFamily')),
        reason: f,
      );
    }
    final all = kAttributions
        .expand((a) => [a.title, ...a.credits, a.licenseNote])
        .join(' ');
    for (final k in [
      'Kementerian Agama',
      'gadingnst/hadith-api',
      'tafsirq.com',
      'EQuran.id',
      'Tanzil',
      'Verse By Verse Quran',
      'Plus Jakarta Sans',
      'Scheherazade New',
      'Material Symbols',
    ]) {
      expect(all, contains(k), reason: k);
    }
  });

  testWidgets('license button opens the Flutter license page', (t) async {
    await pump(t);
    final b = find.text('Lisensi perangkat lunak');
    await reveal(t, b);
    await t.ensureVisible(b);
    await t.pump();
    await t.tap(b);
    await t.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('links are plain selectable text', (t) async {
    await pump(t);
    final link = find.widgetWithText(
      SelectableText,
      'https://creativecommons.org/licenses/by/3.0/',
    );
    await reveal(t, link);
    expect(link, findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('130% at 360x640 scrolls without overflow (dark=$dark)', (
      t,
    ) async {
      await pump(t, scale: 1.3, theme: dark ? AppTheme.dark : AppTheme.light);
      await reveal(t, find.text('Lisensi perangkat lunak'));
      expect(t.takeException(), isNull);
      expect(
        t
            .getSize(
              find.widgetWithText(OutlinedButton, 'Lisensi perangkat lunak'),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
    });
  }

  Future<Map<String, int>> collect() async {
    final c = <String, int>{};
    await LicenseRegistry.licenses.forEach((e) {
      for (final p in e.packages) {
        c[p] = (c[p] ?? 0) + 1;
      }
    });
    return c;
  }

  Future<Map<String, int>> counts(WidgetTester t) async {
    return (await t.runAsync(collect))!;
  }

  testWidgets('registering twice adds no duplicates', (t) async {
    LicenseRegistry.reset();
    resetFontLicensesForTest();
    registerFontLicenses();
    registerFontLicenses();
    final c = await counts(t);
    expect(c['Plus Jakarta Sans'], 1);
    expect(c['Scheherazade New'], 1);
  });

  testWidgets('a missing asset is skipped, not thrown', (t) async {
    LicenseRegistry.reset();
    resetFontLicensesForTest();
    registerFontLicenses(bundle: _EmptyBundle());
    expect(await counts(t), isEmpty);
    LicenseRegistry.reset();
    resetFontLicensesForTest();
  });

  testWidgets('font OFL texts are in the license registry', (t) async {
    registerFontLicenses();
    final byPackage = <String, String>{};
    await t.runAsync(
      () => LicenseRegistry.licenses.forEach((e) {
        for (final p in e.packages) {
          byPackage[p] = e.paragraphs.map((x) => x.text).join(' ');
        }
      }),
    );
    for (final n in ['Plus Jakarta Sans', 'Scheherazade New']) {
      expect(byPackage[n], contains('SIL OPEN FONT LICENSE'), reason: n);
    }
  });
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw FlutterError('missing $key');
}
