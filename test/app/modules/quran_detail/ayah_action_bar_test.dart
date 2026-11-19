import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/modules/quran_detail/controllers/quran_detail_controller.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_action_bar.dart';

void main() {
  Future<Map<String, int>> pump(
    WidgetTester t, {
    AyahAudioState audio = AyahAudioState.ready,
    bool bookmarked = false,
    double scale = 1,
    Map<String, int>? taps,
  }) async {
    final calls = taps ?? <String, int>{};
    void hit(String k) => calls[k] = (calls[k] ?? 0) + 1;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
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
      ),
    );
    return calls;
  }

  testWidgets('four equal cells of height 48 when audio shown', (t) async {
    await pump(t);
    final cells = find.byType(Expanded);
    expect(cells, findsNWidgets(4));
    for (final e in cells.evaluate()) {
      final size = t.getSize(find.byWidget(e.widget));
      expect(size.height, 48);
      expect(size.width, closeTo((320 - 3 * 8) / 4, 0.01));
    }
  });

  testWidgets('three cells when audio hidden', (t) async {
    await pump(t, audio: AyahAudioState.hidden);
    expect(find.byType(Expanded), findsNWidgets(3));
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

    await pump(t, audio: AyahAudioState.needsInternet, taps: calls);
    await t.tap(find.byTooltip('Butuh internet'), warnIfMissed: false);
    expect(calls['audio'], 3);

    await pump(t, audio: AyahAudioState.loading, taps: calls);
    expect(find.bySemanticsLabel('Memuat audio'), findsOneWidget);
    expect(find.byType(IconButton), findsNWidgets(3));
  });

  testWidgets('bookmark, tafsir, copy fire; bookmark fills when set', (
    t,
  ) async {
    final calls = await pump(t);
    await t.tap(find.bySemanticsLabel('Tambah bookmark'));
    await t.tap(find.bySemanticsLabel('Lihat tafsir'));
    await t.tap(find.bySemanticsLabel('Salin ayat'));
    expect(calls, containsPair('bookmark', 1));
    expect(calls, containsPair('tafsir', 1));
    expect(calls, containsPair('copy', 1));

    await pump(t, bookmarked: true);
    final icon = t.widget<Icon>(
      find.descendant(
        of: find.widgetWithIcon(
          IconButton,
          t.widget<Icon>(find.byType(Icon).at(1)).icon!,
        ),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.fill, 1);
    expect(icon.color, AppTheme.light.colorScheme.primary);
    expect(find.bySemanticsLabel('Hapus bookmark'), findsOneWidget);
  });

  testWidgets('130% text scale does not overflow', (t) async {
    await pump(t, scale: 1.3);
    expect(t.takeException(), isNull);
  });
}
