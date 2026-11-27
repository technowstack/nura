import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/modules/quran_detail/controllers/quran_detail_controller.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_action_bar.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';

void main() {
  Future<Map<String, int>> pump(
    WidgetTester t, {
    AyahAudioState audio = AyahAudioState.ready,
    bool bookmarked = false,
    ThemeData? theme,
    Map<String, int>? taps,
  }) async {
    final calls = taps ?? <String, int>{};
    void hit(String k) => calls[k] = (calls[k] ?? 0) + 1;
    await t.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AyahActionBar(
                bookmarked: bookmarked,
                onBookmark: () => hit('bookmark'),
                onCopy: () => hit('copy'),
                onTafsir: () => hit('tafsir'),
                audio: audio,
                onAudio: () => hit('audio'),
              ),
            ),
          ),
        ),
      ),
    );
    return calls;
  }

  Icon iconOf(WidgetTester t, String label) => t.widget<Icon>(
    find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == label),
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    for (final audio in AyahAudioState.values) {
      testWidgets('layout ${theme.brightness} $audio', (t) async {
        await pump(t, audio: audio, theme: theme);
        final n = audio == AyahAudioState.hidden ? 3 : 4;
        final cells = find.byType(Expanded);
        expect(cells, findsNWidgets(n));
        final rects = [
          for (final e in cells.evaluate()) t.getRect(find.byWidget(e.widget)),
        ];
        for (var i = 0; i < n; i++) {
          expect(rects[i].height, 48);
          expect(rects[i].width, closeTo((320 - (n - 1) * 8) / n, 0.01));
          if (i > 0) expect(rects[i].left - rects[i - 1].right, 8);
        }
        final low = theme.colorScheme.surfaceContainerLow;
        final decorated = audio == AyahAudioState.loading
            ? find.descendant(
                of: cells.at(2),
                matching: find.byType(DecoratedBox),
              )
            : null;
        if (decorated != null) {
          final d =
              t.widget<DecoratedBox>(decorated.first).decoration
                  as BoxDecoration;
          expect(d.color, low);
          expect(d.borderRadius, BorderRadius.circular(12));
        }
        for (final b in t.widgetList<IconButton>(find.byType(IconButton))) {
          final bg = b.style!.backgroundColor!.resolve({})!;
          expect(bg, low);
          final shape = b.style!.shape!.resolve({})! as RoundedRectangleBorder;
          expect(shape.borderRadius, BorderRadius.circular(12));
        }
      });
    }

    testWidgets('bookmark icon styling ${theme.brightness}', (t) async {
      await pump(t, theme: theme);
      var icon = iconOf(t, 'Tambah bookmark');
      expect(icon.fill, 0);
      final accent = iconOf(t, 'Salin ayat').color;
      expect(icon.color, accent);
      await pump(t, bookmarked: true, theme: theme);
      icon = iconOf(t, 'Hapus bookmark');
      expect(icon.fill, 1);
      expect(icon.color, theme.colorScheme.primary);
    });
  }

  testWidgets('cell order: copy, bookmark, audio, tafsir', (t) async {
    await pump(t);
    final xs = [
      for (final l in [
        'Salin ayat',
        'Tambah bookmark',
        'Putar ayat',
        'Lihat tafsir',
      ])
        t.getCenter(find.bySemanticsLabel(l)).dx,
    ];
    expect(xs, [...xs]..sort());
    expect(xs.toSet().length, 4);
  });

  testWidgets('needsInternet cell is dimmed and inert', (t) async {
    final calls = await pump(t, audio: AyahAudioState.needsInternet);
    expect(
      iconOf(t, 'Butuh internet').color,
      AppTheme.light.colorScheme.onSurface.withValues(alpha: 0.38),
    );
    await t.tap(find.byTooltip('Butuh internet'), warnIfMissed: false);
    expect(calls['audio'], isNull);
    await pump(t);
    expect(iconOf(t, 'Putar ayat').color, iconOf(t, 'Salin ayat').color);
  });

  testWidgets('audio states', (t) async {
    final calls = await pump(t);
    await t.tap(find.byTooltip('Putar ayat'));
    expect(calls['audio'], 1);
    await pump(t, audio: AyahAudioState.paused, taps: calls);
    await t.tap(find.byTooltip('Putar ayat'));
    expect(calls['audio'], 2);
    await pump(t, audio: AyahAudioState.playing, taps: calls);
    await t.tap(find.byTooltip('Jeda'));
    expect(calls['audio'], 3);
    await pump(t, audio: AyahAudioState.loading, taps: calls);
    expect(find.bySemanticsLabel('Memuat audio'), findsOneWidget);
    expect(find.byType(IconButton), findsNWidgets(3));
  });

  testWidgets('bookmark, tafsir, copy fire', (t) async {
    final calls = await pump(t);
    await t.tap(find.bySemanticsLabel('Tambah bookmark'));
    await t.tap(find.bySemanticsLabel('Lihat tafsir'));
    await t.tap(find.bySemanticsLabel('Salin ayat'));
    expect(calls, {'bookmark': 1, 'tafsir': 1, 'copy': 1});
  });

  testWidgets('AyahCard at 130% text scale, 360x640, has no overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(
            c,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: w!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AyahCard(
              ayah: const Ayah(
                surahNumber: 2,
                ayahNumber: 5,
                arab: 'الم',
                translation: 'Alif Lam Mim.',
                tafsir: '',
              ),
              bookmarked: true,
              lastRead: false,
              prefs: const ReadingPrefs(
                arabicFontSize: 28,
                showTranslation: true,
              ),
              onBookmark: () {},
              onCopy: () {},
              onTafsir: () {},
              onMarkLastRead: () {},
              audio: AyahAudioState.ready,
              onAudio: () {},
              onPlayFromHere: () {},
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });
}
