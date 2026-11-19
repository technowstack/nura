import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/ayah_marker.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/modules/quran_detail/controllers/quran_detail_controller.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';
import 'package:nura/app/modules/quran_detail/widgets/surah_header_card.dart';

const _arab = 'بِسْمِ ٱللَّهِ';

Widget _host(Widget child, {ThemeData? theme, double scale = 1}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  builder: (c, w) => MediaQuery(
    data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
    child: w ?? const SizedBox.shrink(),
  ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

AyahCard _card({
  double size = 28,
  AyahAudioState audio = AyahAudioState.hidden,
  VoidCallback? onPlay,
}) => AyahCard(
  ayah: const Ayah(
    surahNumber: 2,
    ayahNumber: 7,
    arab: _arab,
    translation: 'terjemah',
    tafsir: '',
  ),
  bookmarked: false,
  lastRead: false,
  prefs: ReadingPrefs(arabicFontSize: size, showTranslation: true),
  onBookmark: () {},
  onCopy: () {},
  onTafsir: () {},
  audio: audio,
  onPlayFromHere: onPlay,
);

void main() {
  testWidgets('arabic is ayahDisplayText with exactly one marker', (t) async {
    await t.pumpWidget(_host(_card()));
    final shown = ayahDisplayText(_arab, 7);
    expect(find.text(shown), findsOneWidget);
    expect('۝'.allMatches(shown), hasLength(1));
    expect(find.text('7'), findsOneWidget); // small number, no frame
  });

  for (final size in [20.0, 28.0, 36.0]) {
    testWidgets('arabic $size at 360x640 and 130% has no overflow', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _host(_card(size: size, audio: AyahAudioState.ready), scale: 1.3),
      );
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('menu hidden when audio hidden', (t) async {
    await t.pumpWidget(_host(_card()));
    expect(find.byTooltip('Menu ayat'), findsNothing);
  });

  testWidgets('menu item calls onPlayFromHere when ready', (t) async {
    var n = 0;
    await t.pumpWidget(
      _host(_card(audio: AyahAudioState.ready, onPlay: () => n++)),
    );
    expect(t.getSize(find.byTooltip('Menu ayat')).shortestSide, 48);
    await t.tap(find.byTooltip('Menu ayat'));
    await t.pumpAndSettle();
    await t.tap(find.text('Putar dari sini'));
    await t.pumpAndSettle();
    expect(n, 1);
  });

  for (final s in [AyahAudioState.needsInternet, AyahAudioState.loading]) {
    testWidgets('menu item disabled for $s', (t) async {
      var n = 0;
      await t.pumpWidget(_host(_card(audio: s, onPlay: () => n++)));
      await t.tap(find.byTooltip('Menu ayat'));
      await t.pump(const Duration(milliseconds: 400)); // spinner never settles
      final item = t.widget<PopupMenuItem<void>>(
        find.byType(PopupMenuItem<void>),
      );
      expect(item.enabled, isFalse);
      expect(n, 0);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('header uses hero token, dark=$dark', (t) async {
      final theme = dark ? AppTheme.dark : AppTheme.light;
      await t.pumpWidget(
        _host(
          const SurahHeaderCard(
            surah: Surah(
              number: 2,
              nameArab: 'البقرة',
              nameLatin: 'Al-Baqarah',
              nameId: 'Sapi',
              ayahCount: 286,
              revelation: 'madaniyah',
            ),
            basmalah: 'b',
            showBismillah: false,
          ),
          theme: theme,
        ),
      );
      final deco = t.widget<Container>(
        find
            .byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration,
            )
            .first,
      );
      final colors = t.element(find.byType(SurahHeaderCard)).nuraColors;
      expect((deco.decoration! as BoxDecoration).color, colors.hero);
      expect(find.textContaining('[Q4]', findRichText: true), findsOneWidget);
    });
  }
}
