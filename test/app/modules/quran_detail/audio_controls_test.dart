import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/theme/theme_controller.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/qari.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/audio_settings_store.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/sqlite_audio_settings_store.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/data/sources/audio_api_client.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/modules/quran_detail/controllers/quran_detail_controller.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/modules/quran_detail/views/quran_detail_view.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';
import 'package:nura/app/services/audio_engine.dart';
import 'package:nura/app/services/audio_player_service.dart';
import 'package:nura/app/services/online_service.dart';

import '../../../support/fake_audio.dart';
import '../../../support/fake_repositories.dart';

const _totals = {1: 3, 94: 30};

String _body(int surah, int n) {
  String url(String q, int i) =>
      'https://cdn.equran.id/audio-partial/q$q/${surah.toString().padLeft(3, '0')}${i.toString().padLeft(3, '0')}.mp3';
  final ayat = [
    for (var i = 1; i <= n; i++)
      '{"nomorAyat":$i,"audio":{${[for (final q in kQaris) '"${q.id}":"${url(q.id, i)}"'].join(',')}}}',
  ];
  return '{"data":{"nomor":$surah,"ayat":[${ayat.join(',')}]}}';
}

Uri _u(String q, int s, int a) => Uri.parse(
  'https://cdn.equran.id/audio-partial/q$q/${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3',
);

Surah _s(int n) => Surah(
  number: n,
  nameArab: 'ArabSurah$n',
  nameLatin: 'Latin$n',
  nameId: 'Arti$n',
  ayahCount: _totals[n] ?? 3,
  revelation: 'makkiyah',
);

Ayah _a(int s, int n) => Ayah(
  surahNumber: s,
  ayahNumber: n,
  arab: 'arab$s:$n',
  translation: 'trans$s:$n',
  tafsir: 't',
);

void main() {
  late UserDatabase db;
  late OnlineService online;
  late FakeAudioEngine engine;
  late AudioPlayerService player;
  late StreamController<bool> conn;
  late List<Uri> requests;
  late int status;
  late bool reachable;
  late int probeCalls;

  setUp(() {
    Get.reset();
    final tmp = Directory.systemTemp.createTempSync('nura_audio_ui_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    reachable = true;
    probeCalls = 0;
    status = 200;
    requests = [];
    conn = StreamController<bool>.broadcast(sync: true);
    addTearDown(conn.close);
    online = OnlineService(
      db,
      probe: () async {
        probeCalls++;
        return reachable;
      },
      connectivity: conn.stream.map(
        (up) => [up ? ConnectivityResult.wifi : ConnectivityResult.none],
      ),
    );
    online.setAudioEnabled(true);
    engine = FakeAudioEngine();
    final settings = SqliteAudioSettingsStore(db);
    player = AudioPlayerService(
      online,
      AudioApiClient((uri, {jsonBody}) async {
        requests.add(uri);
        final s = int.parse(uri.pathSegments.last);
        return (
          status: status,
          body: status == 200 ? _body(s, _totals[s] ?? 3) : '',
        );
      }),
      settings,
      engine,
      connectivity: conn.stream,
    );
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: [_s(1), _s(94)],
        ayahs: [
          for (var i = 1; i <= 3; i++) _a(1, i),
          for (var i = 1; i <= 30; i++) _a(94, i),
        ],
      ),
    );
    Get.put<UserRepository>(FakeUserRepository());
    Get.put<OnlineService>(online);
    Get.put<AudioPlayerService>(player);
    Get.put<AudioSettingsStore>(settings);
    Get.put(ThemeController());
  });
  tearDown(Get.reset);

  Future<void> pumpPage(
    WidgetTester t, {
    int surah = 94,
    double scale = 1,
  }) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Get.put(
      QuranDetailController(SurahArgs(surah), lastReadDebounce: Duration.zero),
    );
    await t.pumpWidget(
      GetMaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const QuranDetailView(),
      ),
    );
    await t.pumpAndSettle();
    await t.pump(Duration.zero);
  }

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump();
    await t.pumpAndSettle();
  }

  int? playingCard(WidgetTester t) => t
      .widgetList<AyahCard>(find.byType(AyahCard))
      .where((c) => c.playing)
      .map((c) => c.ayah.ayahNumber)
      .firstOrNull;

  Finder play(int ayah) => find.descendant(
    of: find.widgetWithText(AyahCard, 'arab94:$ayah'),
    matching: find.byTooltip('Putar ayat'),
  );

  Finder button(Finder f) =>
      find.ancestor(of: f, matching: find.byType(IconButton)).first;

  testWidgets('switch off: no audio control and zero audio calls', (t) async {
    online.setAudioEnabled(false);
    await pumpPage(t);
    expect(find.byTooltip('Putar ayat'), findsNothing);
    expect(find.byTooltip('Jeda ayat'), findsNothing);
    expect(find.byTooltip('Putar dari sini'), findsNothing);
    expect(find.byTooltip('Butuh internet'), findsNothing);
    expect(find.text('Putar surah'), findsNothing);
    expect(find.textContaining('Butuh internet'), findsNothing);
    expect(requests, isEmpty);
    expect(engine.calls, isEmpty);
    expect(probeCalls, 0);
  });

  testWidgets('switch on and online: ready, tap plays one ayah', (t) async {
    await pumpPage(t);
    expect(find.text('Putar surah'), findsOneWidget);
    expect(play(1), findsOneWidget);
    await t.tap(play(1));
    await settle(t);
    expect(engine.queues.single, [_u('05', 94, 1)]);
    expect(playingCard(t), 1);
    expect(find.byTooltip('Jeda ayat'), findsOneWidget);
  });

  testWidgets('tap playing pauses, tap again resumes', (t) async {
    await pumpPage(t);
    await t.tap(play(2));
    await settle(t);
    await t.tap(find.byTooltip('Jeda ayat'));
    await settle(t);
    expect(player.state.value, const PlaybackPaused(94, 2));
    expect(find.byTooltip('Jeda ayat'), findsNothing);
    await t.tap(play(2));
    await settle(t);
    expect(player.state.value, const PlaybackPlaying(94, 2));
    expect(engine.queues, hasLength(1));
  });

  testWidgets('another surah playing shows nothing as playing here', (t) async {
    await pumpPage(t);
    await player.playAyah(1, 2, 3);
    await settle(t);
    expect(playingCard(t), isNull);
    expect(find.byTooltip('Jeda ayat'), findsNothing);
    expect(find.byTooltip('Putar ayat'), findsWidgets);
  });

  testWidgets('switch on but offline: disabled with Butuh internet', (t) async {
    reachable = false;
    await pumpPage(t);
    expect(find.byTooltip('Putar ayat'), findsNothing);
    final b = find.byTooltip('Butuh internet').first;
    expect(t.widget<IconButton>(button(b)).onPressed, isNull);
    expect(find.text('Putar surah · Butuh internet'), findsOneWidget);
    await t.tap(b, warnIfMissed: false);
    await t.tap(find.text('Putar surah · Butuh internet'), warnIfMissed: false);
    await settle(t);
    expect(engine.calls, isEmpty);
    expect(requests, isEmpty);
    // Coming online enables the controls.
    conn.add(true);
    await settle(t);
    expect(find.byTooltip('Butuh internet'), findsNothing);
    expect(play(1), findsOneWidget);
    expect(t.widget<IconButton>(button(play(1))).onPressed, isNotNull);
  });

  testWidgets('playSurah starts at ayah 1, from here at chosen ayah', (
    t,
  ) async {
    await pumpPage(t);
    await t.tap(find.text('Putar surah'));
    await settle(t);
    expect(engine.queues.last, [for (var i = 1; i <= 30; i++) _u('05', 94, i)]);
    await t.scrollUntilVisible(
      find.text('arab94:3'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    final row = find.descendant(
      of: find.widgetWithText(AyahCard, 'arab94:3'),
      matching: find.byTooltip('Putar dari sini'),
    );
    await t.tap(row);
    await settle(t);
    expect(engine.queues.last.first, _u('05', 94, 3));
    expect(engine.queues.last, hasLength(28));
    expect(playingCard(t), 3);
  });

  testWidgets('playing ayah highlight and list follow changes', (t) async {
    await pumpPage(t);
    await t.tap(find.text('Putar surah'));
    await settle(t);
    expect(playingCard(t), 1);
    expect(find.text('arab94:26'), findsNothing);
    engine.emit(const IndexChanged(25));
    await settle(t);
    expect(playingCard(t), 26);
    expect(find.text('arab94:26'), findsOneWidget);
    expect(Get.find<QuranDetailController>().playingAyah.value, 26);
    engine.emit(const IndexChanged(1));
    await settle(t);
    expect(playingCard(t), 2);
    expect(find.text('arab94:2'), findsOneWidget);
  });

  testWidgets('failure shows one snackbar, not an error screen', (t) async {
    status = 404;
    await pumpPage(t);
    await t.tap(play(1));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Audio tidak dapat diputar.'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(AyahCard), findsWidgets);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('network failure says Butuh internet, controls stay', (t) async {
    status = 500;
    await pumpPage(t);
    await t.tap(play(1));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Butuh internet'), findsOneWidget);
    expect(play(1), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('leaving the screen stops audio of this surah only', (t) async {
    await pumpPage(t);
    await t.tap(play(1));
    await settle(t);
    await t.pumpWidget(const SizedBox.shrink());
    Get.delete<QuranDetailController>();
    expect(player.state.value, isA<PlaybackIdle>());
    // Another surah keeps playing when a different screen closes.
    await player.playAyah(1, 1, 3);
    Get.put(QuranDetailController(const SurahArgs(94)));
    Get.delete<QuranDetailController>();
    expect(player.state.value, const PlaybackPlaying(1, 1));
  });

  testWidgets('sheet: switch off while playing stops and hides controls', (
    t,
  ) async {
    await pumpPage(t);
    await t.tap(play(1));
    await settle(t);
    await t.tap(find.byTooltip('Pengaturan tampilan'));
    await settle(t);
    await t.tap(find.text('Fitur Online'));
    await settle(t);
    expect(player.state.value, isA<PlaybackIdle>());
    await t.tapAt(const Offset(10, 10));
    await settle(t);
    expect(find.byTooltip('Putar ayat'), findsNothing);
    expect(find.text('Putar surah'), findsNothing);
  });

  testWidgets('sheet: qari picker only with switch, change notifies', (
    t,
  ) async {
    online.setAudioEnabled(false);
    await pumpPage(t);
    await t.tap(find.byTooltip('Pengaturan tampilan'));
    await settle(t);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Fitur Online'), findsOneWidget);
    expect(find.text('Qari'), findsNothing);
    await t.tap(find.text('Fitur Online'));
    await settle(t);
    expect(online.audioEnabled, isTrue);
    expect(find.text('Qari'), findsOneWidget);
    await player.playAyah(94, 1, 30);
    expect(requests, hasLength(1));
    await t.ensureVisible(find.text('Abdurrahman As-Sudais'));
    await t.tap(find.text('Abdurrahman As-Sudais'));
    await settle(t);
    expect(SqliteAudioSettingsStore(db).qariId, '03');
    expect(player.state.value, isA<PlaybackIdle>());
    await player.playAyah(94, 1, 30);
    expect(requests, hasLength(2)); // cache cleared by onQariChanged
    expect(engine.queues.last, [_u('03', 94, 1)]);
  });

  testWidgets('audio tap targets are at least 48dp', (t) async {
    await pumpPage(t);
    for (final f in [play(1), find.byTooltip('Putar dari sini').first]) {
      final size = t.getSize(f);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    final h = t.getSize(find.widgetWithText(OutlinedButton, 'Putar surah'));
    expect(h.height, greaterThanOrEqualTo(48));
  });

  testWidgets('130% text: screen and sheet without overflow', (t) async {
    await pumpPage(t, scale: 1.3);
    expect(t.takeException(), isNull);
    await t.tap(find.byTooltip('Pengaturan tampilan'));
    await settle(t);
    await t.tap(find.text('Fitur Online'));
    await settle(t);
    await t.tap(find.text('Fitur Online'));
    await settle(t);
    expect(t.takeException(), isNull);
  });

  test('no download UI in the reading module', () {
    for (final f in Directory(
      'lib/app/modules/quran_detail',
    ).listSync(recursive: true).whereType<File>()) {
      expect(f.readAsStringSync().toLowerCase(), isNot(contains('unduh')));
    }
  });
}
