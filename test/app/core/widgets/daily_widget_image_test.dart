import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/nura_text_styles.dart';
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
}
