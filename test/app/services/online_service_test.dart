import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/services/online_service.dart';

void main() {
  late Directory tmp;
  late UserDatabase db;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_online_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
  });

  test('prayer sync defaults to off and reads the setting', () {
    final s = OnlineService(db, probe: () async => true);
    expect(s.prayerSyncEnabled, isFalse);
    db.setSetting(SettingKeys.prayerSyncEnabled, 'true');
    expect(s.prayerSyncEnabled, isTrue);
    db.setSetting(SettingKeys.prayerSyncEnabled, 'false');
    expect(s.prayerSyncEnabled, isFalse);
  });

  test('setPrayerSyncEnabled persists true and false', () {
    final s = OnlineService(db, probe: () async => true);
    s.setPrayerSyncEnabled(true);
    expect(db.getSetting(SettingKeys.prayerSyncEnabled), 'true');
    expect(s.prayerSyncEnabled, isTrue);
    s.setPrayerSyncEnabled(false);
    expect(db.getSetting(SettingKeys.prayerSyncEnabled), 'false');
    expect(s.prayerSyncEnabled, isFalse);
  });

  test('canReach delegates to the probe', () async {
    expect(await OnlineService(db, probe: () async => false).canReach(), false);
    expect(await OnlineService(db, probe: () async => true).canReach(), true);
  });

  test('canReach is false when the probe throws', () async {
    final s = OnlineService(db, probe: () async => throw StateError('x'));
    expect(await s.canReach(), isFalse);
  });

  test('audio defaults to off and persists across reopen', () {
    final s = OnlineService(db, probe: () async => true);
    expect(s.audioEnabled, isFalse);
    s.setAudioEnabled(true);
    expect(db.getSetting(SettingKeys.onlineEnabled), 'true');
    final reopened = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(reopened.close);
    expect(OnlineService(reopened).audioEnabled, isTrue);
    OnlineService(reopened).setAudioEnabled(false);
    expect(OnlineService(reopened).audioEnabled, isFalse);
  });

  test('audio changes are emitted once per actual change', () async {
    final s = OnlineService(db, probe: () async => true);
    final seen = <bool>[];
    final sub = s.audioEnabledChanges.listen(seen.add);
    s.setAudioEnabled(false);
    s.setAudioEnabled(true);
    s.setAudioEnabled(true);
    s.setAudioEnabled(false);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [true, false]);
    await sub.cancel();
  });

  test('audio and prayer sync are independent', () {
    final s = OnlineService(db, probe: () async => true);
    s.setAudioEnabled(true);
    expect(s.prayerSyncEnabled, isFalse);
    s.setPrayerSyncEnabled(true);
    s.setAudioEnabled(false);
    expect(s.prayerSyncEnabled, isTrue);
    expect(s.audioEnabled, isFalse);
  });
}
