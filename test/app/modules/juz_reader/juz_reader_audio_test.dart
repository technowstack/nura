import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/theme/theme_controller.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/juz.dart';
import 'package:nura/app/data/models/qari.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/audio_settings_store.dart';
import 'package:nura/app/data/repositories/quran_range_repository.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/sqlite_audio_settings_store.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/data/sources/audio_api_client.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/modules/juz_reader/controllers/juz_reader_controller.dart';
import 'package:nura/app/modules/juz_reader/juz_args.dart';
import 'package:nura/app/modules/quran_detail/controllers/quran_detail_controller.dart'
    show AyahAudioState;
import 'package:nura/app/modules/juz_reader/views/juz_reader_view.dart';
import 'package:nura/app/modules/quran_detail/widgets/ayah_card.dart';
import 'package:nura/app/services/audio_engine.dart';
import 'package:nura/app/services/audio_player_service.dart';
import 'package:nura/app/services/online_service.dart';

import '../../../support/fake_audio.dart';
import '../../../support/fake_repositories.dart';

const _counts = {1: 3, 2: 3, 3: 40};

String _body(int surah, int n) {
  String url(String q, int i) =>
      'https://cdn.equran.id/audio-partial/q$q/${surah.toString().padLeft(3, '0')}${i.toString().padLeft(3, '0')}.mp3';
  final ayat = [
    for (var i = 1; i <= n; i++)
      '{"nomorAyat":$i,"audio":{${[for (final q in kQaris) '"${q.id}":"${url(q.id, i)}"'].join(',')}}}',
  ];
  return '{"data":{"nomor":$surah,"ayat":[${ayat.join(',')}]}}';
}

Uri _u(int s, int a) => Uri.parse(
  'https://cdn.equran.id/audio-partial/q05/${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3',
);

Surah _s(int n) => Surah(
  number: n,
  nameArab: 'A$n',
  nameLatin: 'L$n',
  nameId: 'T$n',
  ayahCount: _counts[n] ?? 1,
  revelation: 'makkiyah',
);

Ayah _a(int s, int n) => Ayah(
  surahNumber: s,
  ayahNumber: n,
  arab: 'arab$s:$n',
  translation: 'trans$s:$n',
  tafsir: 't$s:$n',
);

final _all = [
  for (final e in _counts.entries)
    for (var i = 1; i <= e.value; i++) _a(e.key, i),
];

void main() {
  late UserDatabase db;
  late OnlineService online;
  late FakeAudioEngine engine;
  late AudioPlayerService player;
  late StreamController<bool> conn;
  late StreamController<AppLifecycleState> life;
  late List<int> requests;
  late int status;
  late bool reachable;
  late int probeCalls;

  setUp(() {
    Get.reset();
    final tmp = Directory.systemTemp.createTempSync('nura_juz_audio_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    reachable = true;
    probeCalls = 0;
    status = 200;
    requests = [];
    conn = StreamController<bool>.broadcast(sync: true);
    life = StreamController<AppLifecycleState>.broadcast(sync: true);
    addTearDown(conn.close);
    addTearDown(life.close);
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
        final s = int.parse(uri.pathSegments.last);
        requests.add(s);
        return (
          status: status,
          body: status == 200 ? _body(s, _counts[s] ?? 1) : '',
        );
      }),
      settings,
      engine,
      connectivity: conn.stream,
      lifecycle: life.stream,
    );
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: [_s(1), _s(2), _s(3)],
        ayahs: _all,
        juz: const [
          Juz(number: 1, startSurah: 1, startAyah: 2, endSurah: 3, endAyah: 40),
        ],
      ),
    );
    Get.put<QuranRangeRepository>(FakeQuranRangeRepository(_all));
    Get.put<UserRepository>(FakeUserRepository());
    Get.put<OnlineService>(online);
    Get.put<AudioPlayerService>(player);
    Get.put<AudioSettingsStore>(settings);
    Get.put(ThemeController());
  });
  tearDown(Get.reset);

  Future<void> pumpPage(WidgetTester t, {double scale = 1}) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Get.put(
      JuzReaderController(const JuzArgs(1), lastReadDebounce: Duration.zero),
    );
    await t.pumpWidget(
      GetMaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const JuzReaderView(),
      ),
    );
    await t.pumpAndSettle();
    await t.pump(Duration.zero);
  }

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pumpAndSettle();
  }

  Finder card(int s, int n) => find.byWidgetPredicate(
    (w) => w is AyahCard && w.ayah.surahNumber == s && w.ayah.ayahNumber == n,
  );

  List<(int, int)> playingCards(WidgetTester t) => [
    for (final c in t.widgetList<AyahCard>(find.byType(AyahCard)))
      if (c.playing) (c.ayah.surahNumber, c.ayah.ayahNumber),
  ];

  Future<void> tapIn(WidgetTester t, Finder c, String tooltip) async {
    await t.scrollUntilVisible(
      c,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final b = find.descendant(of: c, matching: find.byTooltip(tooltip));
    await t.ensureVisible(b);
    await t.pump();
    await t.tap(b);
    await t.pumpAndSettle();
  }

  JuzReaderController ctl() => Get.find<JuzReaderController>();

  testWidgets('switch off: nothing shown, zero audio calls', (t) async {
    online.setAudioEnabled(false);
    reachable = false;
    await pumpPage(t);
    expect(find.byTooltip('Putar juz'), findsNothing);
    expect(find.byTooltip('Putar ayat'), findsNothing);
    expect(find.byTooltip('Menu ayat'), findsNothing);
    expect(find.textContaining('Butuh internet'), findsNothing);
    expect(find.byTooltip('Butuh internet'), findsNothing);
    expect(requests, isEmpty);
    expect(engine.calls, isEmpty);
    expect(probeCalls, 0);
  });

  testWidgets('Putar juz crosses surahs lazily and stops at the end', (
    t,
  ) async {
    await pumpPage(t);
    await t.tap(find.byTooltip('Putar juz'));
    await settle(t);
    expect(requests, [1]);
    expect(engine.queues.single, [_u(1, 2), _u(1, 3)]);
    expect(playingCards(t), [(1, 2)]);
    engine.emit(const IndexChanged(1));
    await settle(t);
    expect(requests, [1, 2]);
    engine.emit(const Completed());
    await settle(t);
    expect(engine.queues.last, [_u(2, 1), _u(2, 2), _u(2, 3)]);
    expect(playingCards(t), [(2, 1)]);
    engine.emit(const IndexChanged(2));
    await settle(t);
    expect(requests, [1, 2, 3]);
    engine.emit(const Completed());
    await settle(t);
    expect(engine.queues.last, [for (var i = 1; i <= 40; i++) _u(3, i)]);
    engine.emit(const IndexChanged(39));
    await settle(t);
    expect(playingCards(t), [(3, 40)]);
    engine.emit(const Completed());
    await settle(t);
    expect(player.state.value, isA<PlaybackIdle>());
    expect(playingCards(t), isEmpty);
    expect(requests, [1, 2, 3]);
  });

  testWidgets('Putar dari sini mid-juz plays to the end of the juz', (t) async {
    await pumpPage(t);
    await tapIn(t, card(2, 2), 'Menu ayat');
    await t.tap(find.text('Putar dari sini'));
    await settle(t);
    expect(engine.queues.single, [_u(2, 2), _u(2, 3)]);
    expect(requests, [2]);
    expect(playingCards(t), [(2, 2)]);
    engine.emit(const IndexChanged(1));
    engine.emit(const Completed());
    await settle(t);
    expect(engine.queues.last, [for (var i = 1; i <= 40; i++) _u(3, i)]);
    expect(requests, [2, 3]);
    engine.emit(const Completed());
    await settle(t);
    expect(player.state.value, isA<PlaybackIdle>());
  });

  testWidgets('per ayah play queues exactly that ayah', (t) async {
    await pumpPage(t);
    await tapIn(t, card(2, 1), 'Putar ayat');
    await settle(t);
    expect(engine.queues.single, [_u(2, 1)]);
    expect(playingCards(t), [(2, 1)]);
  });

  testWidgets('playing state is per (surah, ayah)', (t) async {
    await pumpPage(t);
    await player.playAyah(2, 2, 3);
    await settle(t);
    expect(playingCards(t), [(2, 2)]);
    expect(ctl().audioStateOf(const AyahRef(1, 2)), AyahAudioState.ready);
    expect(ctl().audioStateOf(const AyahRef(3, 2)), AyahAudioState.ready);
    expect(ctl().audioStateOf(const AyahRef(2, 2)), AyahAudioState.playing);
  });

  testWidgets('highlight and list follow the playing ayah', (t) async {
    await pumpPage(t);
    ctl().playFromAyah(const AyahRef(3, 1));
    await settle(t);
    expect(card(3, 31), findsNothing);
    engine.emit(const IndexChanged(30));
    await settle(t);
    expect(playingCards(t), [(3, 31)]);
    expect(card(3, 31), findsOneWidget);
  });

  testWidgets('backgrounding pauses and never resumes', (t) async {
    await pumpPage(t);
    await t.tap(find.byTooltip('Putar juz'));
    await settle(t);
    life.add(AppLifecycleState.paused);
    await settle(t);
    expect(player.state.value, const PlaybackPaused(1, 2));
    life.add(AppLifecycleState.resumed);
    await settle(t);
    expect(player.state.value, const PlaybackPaused(1, 2));
  });

  testWidgets('offline: controls disabled with Butuh internet', (t) async {
    reachable = false;
    await pumpPage(t);
    expect(find.byTooltip('Putar juz'), findsNothing);
    expect(find.byTooltip('Putar ayat'), findsNothing);
    final b = find.byTooltip('Butuh internet').first;
    final btn = find.ancestor(of: b, matching: find.byType(IconButton)).first;
    expect(t.widget<IconButton>(btn).onPressed, isNull);
    await t.tap(b, warnIfMissed: false);
    await settle(t);
    expect(requests, isEmpty);
    expect(engine.calls, isEmpty);
    conn.add(true);
    await settle(t);
    expect(find.byTooltip('Putar juz'), findsOneWidget);
  });

  testWidgets('failed play shows the snackbar', (t) async {
    status = 404;
    await pumpPage(t);
    await t.tap(find.byTooltip('Putar juz'));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Audio tidak dapat diputar.'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('leaving the juz reader stops its audio', (t) async {
    await pumpPage(t);
    await t.tap(find.byTooltip('Putar juz'));
    await settle(t);
    await t.pumpWidget(const SizedBox.shrink());
    Get.delete<JuzReaderController>();
    expect(player.state.value, isA<PlaybackIdle>());
  });

  testWidgets('130% text at 360x640 with controls: no overflow', (t) async {
    await pumpPage(t, scale: 1.3);
    expect(t.takeException(), isNull);
    expect(find.byTooltip('Putar juz'), findsOneWidget);
    await tapIn(t, card(2, 2), 'Menu ayat');
    expect(t.takeException(), isNull);
  });
}
