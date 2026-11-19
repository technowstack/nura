import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/arabic_font.dart';
import 'package:nura/app/core/theme/nura_colors.dart';
import 'package:nura/app/core/widgets/daily_widget_image.dart';
import 'package:nura/app/data/models/daily_content.dart';

import '../../../support/fake_daily.dart';

const _s42 = Size(320, 152);
const _s43 = Size(320, 240);

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

// Test code: `!` marks values the fixture guarantees; a null fails the test anyway.
void main() {
  for (final b in Brightness.values) {
    for (final size in [_s42, _s43]) {
      testWidgets('renders PNG of dp x ratio $size $b', (tester) async {
        final data = await tester.runAsync(
          () => renderDailyImage(
            fakeAyah(3),
            dp: size,
            pixelRatio: 2,
            brightness: b,
          ),
        );
        expect(data, isNotNull);
        expect(data, isNotEmpty);
        final img = await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(data!);
          return (await codec.getNextFrame()).image;
        });
        expect(img?.width, (size.width * 2).round());
        expect(img?.height, (size.height * 2).round());
      });
    }
  }

  testWidgets('long text is ellipsized without overflow', (tester) async {
    final long = DailyContent(
      kind: DailyKind.hadith,
      arab: List.filled(80, 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ').join(' '),
      translation: List.filled(80, 'Sesungguhnya amal itu').join(' '),
      reference: 'HR. Shahih Bukhari No. 1',
      deepLink: 'nura://hadith/bukhari/1',
    );
    for (final size in [_s42, _s43]) {
      await tester.pumpWidget(
        _host(
          DailyWidgetImage(
            content: long,
            size: size,
            brightness: Brightness.light,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('HR. Shahih Bukhari No. 1'), findsOneWidget);
      final arab = tester.widget<Text>(find.text(long.arab));
      expect(arab.maxLines, size == _s42 ? 1 : 2);
      expect(arab.style?.fontFamily, nuraArabicFont);
      final tr = tester.widget<Text>(find.text(long.translation));
      expect(tr.maxLines, size == _s42 ? 1 : 3);
      expect(tr.overflow, TextOverflow.ellipsis);
    }
  });

  testWidgets('short text shows label and reference', (tester) async {
    await tester.pumpWidget(
      _host(
        DailyWidgetImage(
          content: fakeAyah(1),
          size: _s42,
          brightness: Brightness.dark,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ayat hari ini'), findsOneWidget);
    expect(find.text('QS. Asy-Syarh: 1'), findsOneWidget);
    await tester.pumpWidget(
      _host(
        DailyWidgetImage(
          content: fakeHadith(1, HadithSource.defaultBm),
          size: _s43,
          brightness: Brightness.light,
        ),
      ),
    );
    expect(find.text('Hadis hari ini'), findsOneWidget);
  });

  // The device font can have taller line metrics than the test font; the
  // layout must absorb that instead of overflowing (seen on a device as
  // "bottom overflowed by 10 pixels" in the hadith widget).
  testWidgets('layout never overflows when it gets less height', (
    tester,
  ) async {
    for (final size in const [Size(320, 138), Size(320, 200), Size(320, 226)]) {
      await tester.pumpWidget(
        _host(
          DailyWidgetImage(
            content: fakeHadith(3, HadithSource.defaultBm),
            size: size,
            brightness: Brightness.light,
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$size');
      expect(
        find.text(fakeHadith(3, HadithSource.defaultBm).reference),
        findsOneWidget,
      );
    }
  });

  testWidgets('Arabic surah name only for Ayat, in arabicTitle/iconAccent', (
    tester,
  ) async {
    final ayah = fakeAyah(1);
    final name = ayah.surahNameArab;
    expect(name, isNotNull);
    if (name == null) return;
    await tester.pumpWidget(
      _host(
        DailyWidgetImage(
          content: ayah,
          size: _s42,
          brightness: Brightness.light,
        ),
      ),
    );
    final nameText = tester.widget<Text>(find.text(name));
    expect(nameText.style?.color, NuraColors.light.iconAccent);
    expect(nameText.style?.fontFamily, nuraArabicFont);
    await tester.pumpWidget(
      _host(
        DailyWidgetImage(
          content: fakeHadith(1, HadithSource.defaultBm),
          size: _s42,
          brightness: Brightness.light,
        ),
      ),
    );
    expect(find.text(name), findsNothing);
  });

  testWidgets('token colors per brightness', (tester) async {
    for (final b in Brightness.values) {
      final theme = b == Brightness.dark ? AppTheme.dark : AppTheme.light;
      final colors = b == Brightness.dark ? NuraColors.dark : NuraColors.light;
      await tester.pumpWidget(
        _host(
          DailyWidgetImage(content: fakeAyah(1), size: _s42, brightness: b),
        ),
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(DailyWidgetImage),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final deco = box.decoration as BoxDecoration;
      expect(deco.color, theme.colorScheme.surfaceContainerLowest);
      expect(
        (deco.border as Border).top.color,
        theme.colorScheme.outlineVariant,
      );
      final label = tester.widget<Text>(find.text('Ayat hari ini'));
      expect(label.style?.color, colors.iconAccent);
    }
  });

  testWidgets('ornament only for Ayat', (tester) async {
    final ornament = find.byWidgetPredicate((w) => w is Icon && w.size == 120);
    for (final (c, n) in [
      (fakeAyah(1), 1),
      (fakeHadith(1, HadithSource.defaultBm), 0),
    ]) {
      await tester.pumpWidget(
        _host(
          DailyWidgetImage(
            content: c,
            size: _s42,
            brightness: Brightness.light,
          ),
        ),
      );
      expect(ornament, findsNWidgets(n));
    }
  });

  testWidgets('long surah name at narrow width does not overflow', (
    tester,
  ) async {
    final base = fakeAyah(1);
    final long = DailyContent(
      kind: base.kind,
      arab: base.arab,
      translation: base.translation,
      reference: base.reference,
      deepLink: base.deepLink,
      ayahRef: base.ayahRef,
      surahNameArab: List.filled(30, 'ٱلشَّرْحِ').join(' '),
    );
    await tester.pumpWidget(
      _host(
        DailyWidgetImage(
          content: long,
          size: const Size(200, 152),
          brightness: Brightness.light,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
