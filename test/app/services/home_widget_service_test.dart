import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/services/home_widget_service.dart';

import '../../support/fake_daily.dart';
import '../../support/fake_widget_storage.dart';

// Test code: `!` marks values the fixture guarantees; a null fails the test anyway.
void main() {
  late Directory dir;
  late FakeDailyContentRepository repo;
  late FakeDailySettingsStore settings;
  late FakeWidgetStorage storage;
  late DateTime clock;
  late Set<String> failRenderFor;
  var renderTag = 'v1';
  late HomeWidgetService service;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nura_widget');
    repo = FakeDailyContentRepository();
    settings = FakeDailySettingsStore();
    storage = FakeWidgetStorage();
    clock = DateTime(2026, 11, 15, 9);
    failRenderFor = {};
    service = HomeWidgetService(
      repository: repo,
      settings: settings,
      storage: storage,
      directory: dir,
      render: (c, {required dp, required pixelRatio, required brightness}) async {
        if (failRenderFor.contains(c.translation)) {
          throw StateError('render');
        }
        return Uint8List.fromList(
          utf8.encode(
            '${c.translation}|${brightness.name}|${dp.width}x${dp.height}|$pixelRatio|$renderTag',
          ),
        );
      },
      now: () => clock,
      pixelRatio: () => 2.5,
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  List<String> files() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  test('writes 7 dates x 2 kinds x 4 combos with keys and JSON', () async {
    await service.refresh();
    expect(
      storage.data.keys.where((k) => k.startsWith('daily_ayah_')).length,
      28,
    );
    expect(
      storage.data.keys.where((k) => k.startsWith('daily_hadith_')).length,
      28,
    );
    final e =
        jsonDecode(storage.data['daily_ayah_2026-11-21_dark_4x3']!)
            as Map<String, dynamic>;
    expect(e['link'], 'nura://ayah/94/21');
    expect(e['image'], '${dir.path}/daily_ayah_2026-11-21_dark_4x3.png');
    expect(File(e['image'] as String).existsSync(), isTrue);
    expect(storage.data['daily_hadith_2026-11-15_light_4x2'], isNotNull);
    expect(storage.data['daily_widget_updated'], isNotNull);
    expect(files().length, 56);
  });

  test('entry carries a TalkBack description', () async {
    await service.refresh();
    final a =
        jsonDecode(storage.data['daily_ayah_2026-11-15_light_4x2']!)
            as Map<String, dynamic>;
    expect(a['description'], 'Ayat hari ini. QS. Asy-Syarh: 15. Ayat hari 15');
    final h =
        jsonDecode(storage.data['daily_hadith_2026-11-15_light_4x2']!)
            as Map<String, dynamic>;
    expect(
      (h['description'] as String).startsWith(
        'Hadis hari ini. HR. Shahih Bukhari No. 15. Hadis hari 15',
      ),
      isTrue,
    );
  });

  test('description truncates long translations and survives JSON', () async {
    final tricky = 'Dia berkata "ya"\nlalu ${'a' * 200}';
    final long = HomeWidgetService(
      repository: _TextRepo(tricky),
      settings: settings,
      storage: storage,
      directory: dir,
      render:
          (c, {required dp, required pixelRatio, required brightness}) async =>
              Uint8List(1),
      now: () => clock,
      pixelRatio: () => 1,
    );
    await long.refresh();
    final e =
        jsonDecode(storage.data['daily_ayah_2026-11-15_dark_4x3']!)
            as Map<String, dynamic>;
    final d = e['description'] as String;
    const prefix = 'Ayat hari ini. QS. Asy-Syarh: 15. ';
    expect(d.startsWith(prefix), isTrue);
    final body = d.substring(prefix.length);
    expect(body.runes.length, 160);
    expect(body.endsWith('\u2026'), isTrue);
    expect(body.startsWith('Dia berkata "ya"\nlalu'), isTrue);
  });

  test(
    'notifies the widgets exactly once, after the entries are written',
    () async {
      await service.refresh();
      expect(storage.notifies, 1);
      expect(storage.entriesAtNotify.single, 56);
    },
  );

  test('no notify when nothing was written', () async {
    repo.withAyah = false;
    repo.withHadith = false;
    await service.refresh();
    expect(storage.notifies, 0);
  });

  test('a throwing notify neither throws nor changes the result', () async {
    storage.failNotify = true;
    expect(await service.refresh(), isTrue);
    expect(storage.notifies, 1);
  });

  test('a source change ends with a notify', () async {
    await service.refresh();
    settings.hadithSource = HadithSource.allBooks;
    await service.refresh();
    expect(storage.notifies, 2);
  });

  test('window crosses month and year boundary', () async {
    clock = DateTime(2026, 12, 29, 23, 59);
    await service.refresh();
    for (final d in ['2026-12-29', '2026-12-31', '2027-01-01', '2027-01-04']) {
      expect(storage.data['daily_hadith_${d}_light_4x2'], isNotNull, reason: d);
    }
    expect(storage.data['daily_hadith_2027-01-05_light_4x2'], isNull);
  });

  test('ayah skipped when none available', () async {
    repo.withAyah = false;
    await service.refresh();
    expect(storage.data.keys.any((k) => k.startsWith('daily_ayah_')), isFalse);
    expect(files().every((f) => f.startsWith('daily_hadith_')), isTrue);
  });

  test('one failing render keeps old value and others continue', () async {
    await service.refresh();
    final old = storage.data['daily_ayah_2026-11-16_light_4x2'];
    final oldFile = File(
      '${dir.path}/daily_ayah_2026-11-16_light_4x2.png',
    ).readAsStringSync();
    failRenderFor = {'Ayat hari 16'};
    settings.hadithSource = HadithSource.allBooks;
    await service.refresh();
    expect(storage.data['daily_ayah_2026-11-16_light_4x2'], old);
    expect(
      File(
        '${dir.path}/daily_ayah_2026-11-16_light_4x2.png',
      ).readAsStringSync(),
      oldFile,
    );
    expect(
      File(
        '${dir.path}/daily_hadith_2026-11-16_light_4x2.png',
      ).readAsStringSync(),
      contains('(all)'),
    );
    expect(files().where((f) => f.endsWith('.tmp')), isEmpty);
  });

  test('throwing storage does not escape and keeps old value', () async {
    await service.refresh();
    const k = 'daily_ayah_2026-11-16_light_4x2';
    final old = storage.data[k];
    expect(old, isNotNull);
    storage.failAll = true;
    await service.refresh();
    expect(storage.data[k], old);
    storage.failAll = false;
    storage.failingKeys.add(k);
    settings.hadithSource = HadithSource.allBooks;
    await service.refresh();
    expect(storage.data[k], old);
    expect(
      File(
        '${dir.path}/daily_hadith_2026-11-17_light_4x2.png',
      ).readAsStringSync(),
      contains('(all)'),
    );
  });

  test('renderer receives brightness, size and ratio per key', () async {
    await service.refresh();
    final sizes = {'4x2': '320.0x152.0', '4x3': '320.0x240.0'};
    for (final key in storage.data.keys.where(
      (k) => k.startsWith('daily_a') || k.startsWith('daily_h'),
    )) {
      final m = jsonDecode(storage.data[key]!) as Map<String, dynamic>;
      final parts = File(m['image'] as String).readAsStringSync().split('|');
      final bits = key.split('_');
      expect(parts[1], bits[3], reason: key);
      expect(parts[2], sizes[bits[4]], reason: key);
      expect(parts[3], '2.5', reason: key);
    }
  });

  test('lookup failure keeps old entries; others still refresh', () async {
    await service.refresh();
    const k = 'daily_ayah_2026-11-15_light_4x2';
    final old = storage.data[k];
    final oldPng = File('${dir.path}/$k.png').readAsStringSync();
    final failing = _ThrowingAyahRepo(DateTime(2026, 11, 15));
    final svc = HomeWidgetService(
      repository: failing,
      settings: settings,
      storage: storage,
      directory: dir,
      render:
          (c, {required dp, required pixelRatio, required brightness}) async =>
              Uint8List.fromList(utf8.encode('new')),
      now: () => clock,
      pixelRatio: () => 2.5,
    );
    await svc.refresh();
    expect(storage.data[k], old);
    expect(File('${dir.path}/$k.png').readAsStringSync(), oldPng);
    expect(storage.data['daily_ayah_2026-11-16_light_4x2'], isNotNull);
    expect(
      File(
        '${dir.path}/daily_ayah_2026-11-16_light_4x2.png',
      ).readAsStringSync(),
      'new',
    );
    expect(
      File(
        '${dir.path}/daily_hadith_2026-11-15_light_4x2.png',
      ).readAsStringSync(),
      'new',
    );
  });

  test('failed temp write keeps previous png and value, no tmp file', () async {
    await service.refresh();
    const k = 'daily_ayah_2026-11-16_light_4x2';
    final old = storage.data[k];
    final png = File('${dir.path}/$k.png');
    final oldPng = png.readAsStringSync();
    // A directory in place of the temp file makes the temp write fail.
    Directory('${dir.path}/$k.png.tmp').createSync();
    renderTag = 'v2';
    settings.hadithSource = HadithSource.allBooks;
    await service.refresh();
    expect(png.readAsStringSync(), oldPng);
    expect(storage.data[k], old);
  });

  test('failed rename keeps value and leaves no tmp file', () async {
    const k = 'daily_ayah_2026-11-15_light_4x2';
    // A non-empty directory at the target makes rename fail.
    Directory('${dir.path}/$k.png').createSync();
    File('${dir.path}/$k.png/x').writeAsStringSync('x');
    storage.data[k] = 'old';
    await service.refresh();
    expect(storage.data[k], 'old');
    expect(files().where((f) => f.endsWith('.tmp')), isEmpty);
    expect(storage.data['daily_ayah_2026-11-16_light_4x2'], isNotNull);
  });

  test('concurrent refresh calls are serialized', () async {
    var running = 0;
    var maxRunning = 0;
    final svc = HomeWidgetService(
      repository: repo,
      settings: settings,
      storage: storage,
      directory: dir,
      render:
          (c, {required dp, required pixelRatio, required brightness}) async {
            maxRunning = ++running > maxRunning ? running : maxRunning;
            await Future<void>.delayed(Duration.zero);
            running--;
            return Uint8List.fromList([1]);
          },
      now: () => clock,
      pixelRatio: () => 1,
    );
    await Future.wait([svc.refresh(), svc.refresh()]);
    expect(maxRunning, 1);
    expect(files().length, 56);
  });

  test('orphan keys are swept even when the index is lost', () async {
    await service.refresh();
    storage.data.remove('daily_widget_index');
    clock = DateTime(2026, 11, 16, 9);
    await service.refresh();
    expect(storage.data.keys.where((k) => k.contains('2026-11-15')), isEmpty);
  });

  test('refresh twice keeps the same files', () async {
    await service.refresh();
    final first = files();
    await service.refresh();
    expect(files(), first);
  });

  test('cross-midnight shifts the window and removes stale entries', () async {
    await service.refresh();
    clock = DateTime(2026, 11, 16, 0, 1);
    await service.refresh();
    expect(storage.data['daily_ayah_2026-11-15_light_4x2'], isNull);
    expect(storage.data['daily_ayah_2026-11-22_light_4x2'], isNotNull);
    expect(files().any((f) => f.contains('2026-11-15')), isFalse);
    expect(files().length, 56);
  });

  test('hadith source change rewrites hadith entries only', () async {
    await service.refresh();
    final ayah = storage.data['daily_ayah_2026-11-15_light_4x2'];
    settings.hadithSource = HadithSource.allBooks;
    await service.refresh();
    expect(storage.data['daily_ayah_2026-11-15_light_4x2'], ayah);
    expect(
      File(
        '${dir.path}/daily_hadith_2026-11-15_dark_4x3.png',
      ).readAsStringSync(),
      contains('(all)'),
    );
  });
}

class _ThrowingAyahRepo extends FakeDailyContentRepository {
  _ThrowingAyahRepo(this.badDate);

  final DateTime badDate;

  @override
  DailyContent? ayahFor(DateTime localDate) {
    if (localDate == badDate) throw StateError('lookup');
    return super.ayahFor(localDate);
  }
}

class _TextRepo extends FakeDailyContentRepository {
  _TextRepo(this.text);

  final String text;

  @override
  DailyContent? ayahFor(DateTime localDate) {
    final base = fakeAyah(localDate.day);
    return DailyContent(
      kind: base.kind,
      arab: base.arab,
      translation: text,
      reference: base.reference,
      deepLink: base.deepLink,
      ayahRef: base.ayahRef,
      surahNameArab: base.surahNameArab,
    );
  }
}
