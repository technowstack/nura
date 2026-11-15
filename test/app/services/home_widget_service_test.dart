import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/services/home_widget_service.dart';

import '../../support/fake_daily.dart';
import '../../support/fake_widget_storage.dart';

void main() {
  late Directory dir;
  late FakeDailyContentRepository repo;
  late FakeDailySettingsStore settings;
  late FakeWidgetStorage storage;
  late DateTime clock;
  late Set<String> failRenderFor;
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
      render:
          (c, {required dp, required pixelRatio, required brightness}) async {
            if (failRenderFor.contains(c.translation)) {
              throw StateError('render');
            }
            return Uint8List.fromList(utf8.encode('${c.translation}|$dp'));
          },
      now: () => clock,
      pixelRatio: () => 2,
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

  test('throwing storage does not escape', () async {
    storage.failAll = true;
    await service.refresh();
    storage.failAll = false;
    storage.failingKeys.add('daily_ayah_2026-11-16_light_4x2');
    await service.refresh();
    expect(storage.data['daily_ayah_2026-11-17_light_4x2'], isNotNull);
    expect(storage.data['daily_ayah_2026-11-16_light_4x2'], isNull);
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
