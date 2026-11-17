import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppLifecycleState;

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/qari.dart';
import 'package:nura/app/data/repositories/audio_settings_store.dart';
import 'package:nura/app/data/sources/audio_api_client.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/services/audio_engine.dart';
import 'package:nura/app/services/audio_player_service.dart';
import 'package:nura/app/services/online_service.dart';

import '../../support/fake_audio.dart';

class _Settings implements AudioSettingsStore {
  String id = kDefaultQariId;
  @override
  String get qariId => id;
  @override
  void setQariId(String v) => id = v;
}

/// Builds a valid equran-shaped body for [n] ayat with all qaris.
String _body(int surah, int n) {
  final ayat = [
    for (var i = 1; i <= n; i++)
      '{"nomorAyat":$i,"audio":{${[for (final q in kQaris) '"${q.id}":"https://cdn.equran.id/audio-partial/q${q.id}/${surah.toString().padLeft(3, '0')}${i.toString().padLeft(3, '0')}.mp3"'].join(',')}}}',
  ];
  return '{"data":{"nomor":$surah,"ayat":[${ayat.join(',')}]}}';
}

Uri _u(String qari, int surah, int ayah) => Uri.parse(
  'https://cdn.equran.id/audio-partial/q$qari/${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3',
);

void main() {
  late Directory tmp;
  late UserDatabase db;
  late OnlineService online;
  late _Settings settings;
  late FakeAudioEngine engine;
  late StreamController<AppLifecycleState> life;
  late List<Uri> requests;
  late int status;
  late Completer<void>? httpGate;
  late AudioPlayerService svc;
  var reachable = true;
  var probeCalls = 0;
  Completer<void>? probeGate;
  late StreamController<bool> conn;
  const totals = {94: 8, 1: 7};

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_audio_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    reachable = true;
    probeCalls = 0;
    probeGate = null;
    conn = StreamController<bool>.broadcast(sync: true);
    addTearDown(conn.close);
    online = OnlineService(
      db,
      probe: () async {
        probeCalls++;
        await probeGate?.future;
        return reachable;
      },
    );
    online.setAudioEnabled(true);
    settings = _Settings();
    engine = FakeAudioEngine();
    life = StreamController<AppLifecycleState>.broadcast(sync: true);
    requests = [];
    status = 200;
    httpGate = null;
    final api = AudioApiClient((uri, {jsonBody}) async {
      requests.add(uri);
      await httpGate?.future;
      final s = int.parse(uri.pathSegments.last);
      return (status: status, body: status == 200 ? _body(s, totals[s]!) : '');
    });
    svc = AudioPlayerService(
      online,
      api,
      settings,
      engine,
      lifecycle: life.stream,
      connectivity: conn.stream,
    );
    addTearDown(life.close);
  });

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test('switch off: switchedOff, no engine or http calls', () async {
    online.setAudioEnabled(false);
    expect(await svc.playAyah(94, 1, 8), PlayResult.switchedOff);
    expect(await svc.playFrom(94, 1, 8), PlayResult.switchedOff);
    expect(engine.calls, isEmpty);
    expect(requests, isEmpty);
    expect(probeCalls, 0);
  });

  test('offline: needsInternet, no engine or http calls', () async {
    reachable = false;
    expect(await svc.playAyah(94, 1, 8), PlayResult.needsInternet);
    expect(engine.calls, isEmpty);
    expect(requests, isEmpty);
    expect(svc.state.value, isA<PlaybackIdle>());
  });

  test('playAyah queues exactly one url of the selected qari', () async {
    settings.id = '03';
    expect(await svc.playAyah(94, 4, 8), PlayResult.ok);
    expect(engine.queues.single, [_u('03', 94, 4)]);
    expect(engine.calls.last, 'play');
    expect(svc.state.value, const PlaybackPlaying(94, 4));
  });

  test('playFrom queues to the end and follows index events', () async {
    await svc.playFrom(94, 3, 8);
    expect(engine.queues.single, [
      for (var i = 3; i <= 8; i++) _u('05', 94, i),
    ]);
    expect(svc.state.value, const PlaybackPlaying(94, 3));
    engine.emit(const IndexChanged(1));
    expect(svc.state.value, const PlaybackPlaying(94, 4));
    engine.emit(const IndexChanged(2));
    expect(svc.state.value, const PlaybackPlaying(94, 5));
    engine.emit(const Completed());
    expect(svc.state.value, isA<PlaybackIdle>());
  });

  test(
    'engine Failed mid-queue: idle + lastError, cleared next play',
    () async {
      await svc.playFrom(94, 1, 8);
      engine.emit(const Failed('boom'));
      await tick();
      expect(svc.state.value, isA<PlaybackIdle>());
      expect(svc.lastError.value, isNotNull);
      await svc.playAyah(94, 2, 8);
      expect(svc.lastError.value, isNull);
    },
  );

  test('engine setUrls error: failed, idle', () async {
    engine.setUrlsError = StateError('x');
    expect(await svc.playAyah(94, 1, 8), PlayResult.failed);
    expect(svc.state.value, isA<PlaybackIdle>());
  });

  test(
    'one fetch per surah, other surah fetches, failure not cached',
    () async {
      await svc.playAyah(94, 1, 8);
      await svc.playAyah(94, 2, 8);
      await svc.playFrom(94, 3, 8);
      expect(requests.length, 1);
      await svc.playAyah(1, 1, 7);
      expect(requests.length, 2);
      svc.onQariChanged();
      await svc.playAyah(94, 1, 8);
      expect(requests.length, 2);
    },
  );

  test('failed fetch is retried next time', () async {
    status = 500;
    expect(await svc.playAyah(94, 1, 8), PlayResult.needsInternet);
    status = 200;
    expect(await svc.playAyah(94, 1, 8), PlayResult.ok);
    expect(requests.length, 2);
  });

  test('bad response and not found map to failed', () async {
    status = 404;
    expect(await svc.playAyah(94, 1, 8), PlayResult.failed);
    status = 418;
    expect(await svc.playAyah(94, 1, 8), PlayResult.failed);
    expect(engine.calls, isNot(contains('setUrls')));
  });

  test('concurrent calls share one request', () async {
    httpGate = Completer();
    final a = svc.playAyah(94, 1, 8);
    final b = svc.playAyah(94, 2, 8);
    await tick();
    await tick();
    httpGate?.complete();
    await Future.wait([a, b]);
    expect(requests.length, 1);
  });

  test(
    'new play replaces old queue; stale slow call cannot override',
    () async {
      httpGate = Completer();
      final slow = svc.playAyah(94, 1, 8);
      await tick();
      await tick();
      httpGate?.complete();
      await slow;
      engine.calls.clear();
      await svc.playAyah(94, 5, 8);
      expect(engine.calls, ['stop', 'setUrls', 'play']);

      // Slow earlier call finishing after a newer one.
      final gate = Completer<void>();
      engine.setUrlsGate = gate;
      final older = svc.playAyah(94, 6, 8);
      await tick();
      await tick();
      engine.setUrlsGate = null;
      final newer = svc.playAyah(94, 7, 8);
      await newer;
      gate.complete();
      await older;
      expect(svc.state.value, const PlaybackPlaying(94, 7));
      // Only the newer queue was started after the stale one finished.
      expect(engine.calls.where((c) => c == 'play').length, 2);
    },
  );

  test('switch off while playing stops and no more http', () async {
    await svc.playFrom(94, 1, 8);
    final before = requests.length;
    online.setAudioEnabled(false);
    await tick();
    expect(svc.state.value, isA<PlaybackIdle>());
    expect(engine.calls.last, 'stop');
    await svc.playAyah(1, 1, 7);
    expect(requests.length, before);
  });

  test('switch off while loading cancels the start', () async {
    httpGate = Completer();
    final f = svc.playAyah(94, 1, 8);
    await tick();
    await tick();
    online.setAudioEnabled(false);
    httpGate?.complete();
    await f;
    expect(engine.calls, isNot(contains('setUrls')));
    expect(svc.state.value, isA<PlaybackIdle>());
  });

  test(
    'background pauses and foreground does not resume; resume works',
    () async {
      await svc.playFrom(94, 1, 8);
      life.add(AppLifecycleState.paused);
      await tick();
      expect(svc.state.value, const PlaybackPaused(94, 1));
      expect(engine.calls.last, 'pause');
      life.add(AppLifecycleState.resumed);
      await tick();
      expect(svc.state.value, const PlaybackPaused(94, 1));
      await svc.resume();
      expect(svc.state.value, const PlaybackPlaying(94, 1));
      expect(engine.calls.last, 'play');
    },
  );

  test('qari change stops playback, keeps the cache', () async {
    await svc.playFrom(94, 1, 8);
    svc.onQariChanged();
    await tick();
    expect(svc.state.value, isA<PlaybackIdle>());
    settings.id = '01';
    await svc.playAyah(94, 1, 8);
    expect(requests.length, 1);
    expect(engine.queues.last, [_u('01', 94, 1)]);
  });

  test('no files are written during play, queue and failure', () async {
    List<String> list(Directory d) =>
        d.listSync(recursive: true).map((e) => e.path).toList()..sort();
    // Other tests share the system temp dir in parallel: only look for audio.
    List<String> audioFiles() => list(Directory.systemTemp)
        .where((p) => RegExp(r'\.(mp3|m4a|aac|ogg|wav|part)$').hasMatch(p))
        .toList();
    final before = [list(tmp), audioFiles()];
    await svc.playFrom(94, 1, 8);
    engine.emit(const IndexChanged(2));
    engine.emit(const Failed('x'));
    await tick();
    await svc.playAyah(94, 2, 8);
    await svc.stop();
    expect([list(tmp), audioFiles()], before);
  });

  test('dispose cancels subscriptions', () async {
    await svc.playFrom(94, 1, 8);
    await svc.dispose();
    expect(engine.disposed, isTrue);
    expect(engine.hasListener, isFalse);
    engine.emit(const IndexChanged(3));
    expect(svc.state.value, isA<PlaybackIdle>());
    db.setSetting(SettingKeys.onlineEnabled, 'true');
    online.setAudioEnabled(false);
    await tick();
    expect(svc.state.value, isA<PlaybackIdle>());
  });

  group('review fixes', () {
    test('(a) background while connectivity probe pending cancels', () async {
      probeGate = Completer();
      final f = svc.playAyah(94, 1, 8);
      await tick();
      life.add(AppLifecycleState.paused);
      probeGate?.complete();
      await f;
      expect(engine.calls, isNot(contains('play')));
      expect(svc.state.value, isA<PlaybackIdle>());
    });

    test('(b) background while api fetch pending cancels', () async {
      httpGate = Completer();
      final f = svc.playAyah(94, 1, 8);
      await tick();
      await tick();
      life.add(AppLifecycleState.hidden);
      httpGate?.complete();
      await f;
      expect(engine.calls, isNot(contains('play')));
      expect(svc.state.value, isA<PlaybackIdle>());
    });

    test('(c) old queue playing, new play pending, background', () async {
      await svc.playFrom(94, 1, 8);
      engine.calls.clear();
      probeGate = Completer();
      final f = svc.playAyah(94, 5, 8);
      await tick();
      life.add(AppLifecycleState.detached);
      probeGate?.complete();
      await f;
      await tick();
      expect(engine.calls, isNot(contains('play')));
      expect(svc.state.value, isA<PlaybackIdle>());
    });

    test('inactive does not pause', () async {
      await svc.playFrom(94, 1, 8);
      life.add(AppLifecycleState.inactive);
      await tick();
      expect(svc.state.value, const PlaybackPlaying(94, 1));
    });

    test('connection lost while playing stops, online no resume', () async {
      await svc.playFrom(94, 1, 8);
      conn.add(false);
      await tick();
      expect(svc.state.value, isA<PlaybackIdle>());
      expect(svc.lastError.value, 'Koneksi terputus. Pemutaran dihentikan.');
      engine.calls.clear();
      conn.add(true);
      await tick();
      expect(engine.calls, isEmpty);
      expect(svc.state.value, isA<PlaybackIdle>());
    });

    test('connection lost while loading cancels the start', () async {
      httpGate = Completer();
      final f = svc.playAyah(94, 1, 8);
      await tick();
      await tick();
      conn.add(false);
      httpGate?.complete();
      await f;
      expect(engine.calls, isNot(contains('play')));
      expect(svc.lastError.value, isNotNull);
    });

    test('failed results set lastError, needsInternet does not', () async {
      status = 404;
      expect(await svc.playAyah(94, 1, 8), PlayResult.failed);
      expect(svc.lastError.value, 'Audio tidak dapat diputar.');
      status = 200;
      await svc.playAyah(94, 1, 8);
      expect(svc.lastError.value, isNull);
      reachable = false;
      expect(await svc.playAyah(94, 1, 8), PlayResult.needsInternet);
      expect(svc.lastError.value, isNull);
    });

    test('engine pause/resume throwing: idle + lastError, no throw', () async {
      await svc.playFrom(94, 1, 8);
      engine.pauseError = StateError('p');
      await svc.pause();
      expect(svc.state.value, isA<PlaybackIdle>());
      expect(svc.lastError.value, isNotNull);
      engine.pauseError = null;
      await svc.playFrom(94, 1, 8);
      await svc.pause();
      engine.playError = StateError('r');
      await svc.resume();
      expect(svc.state.value, isA<PlaybackIdle>());
      expect(svc.lastError.value, isNotNull);
    });

    test('platform pause moves state to paused', () async {
      await svc.playFrom(94, 2, 8);
      engine.emit(const PausedByPlatform());
      expect(svc.state.value, const PlaybackPaused(94, 2));
      engine.calls.clear();
      life.add(AppLifecycleState.paused);
      await tick();
      expect(engine.calls, ['pause']);
      expect(svc.state.value, const PlaybackPaused(94, 2));
    });

    test('dispose sets state idle and cancels connectivity', () async {
      await svc.playFrom(94, 1, 8);
      await svc.dispose();
      expect(svc.state.value, isA<PlaybackIdle>());
      expect(conn.hasListener, isFalse);
    });

    test('no file-writing APIs in audio sources', () {
      final files = [
        ...Directory('lib/app/services').listSync().whereType<File>().where(
          (f) => f.uri.pathSegments.last.startsWith('audio_'),
        ),
        File('lib/app/data/sources/audio_api_client.dart'),
      ];
      expect(files.length, greaterThanOrEqualTo(3));
      for (final f in files) {
        final t = f.readAsStringSync();
        for (final bad in [
          'LockCachingAudioSource',
          'File(',
          'writeAs',
          'audio_download',
        ]) {
          expect(t.contains(bad), isFalse, reason: '${f.path} has $bad');
        }
      }
    });
  });
}
