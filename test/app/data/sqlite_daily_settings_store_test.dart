import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/data/repositories/sqlite_daily_settings_store.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';

void main() {
  late Directory tmp;
  late UserDatabase db;
  late SqliteDailySettingsStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_dset_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    store = SqliteDailySettingsStore(db);
  });

  test('defaults', () {
    expect(store.hadithSource, HadithSource.defaultBm);
    expect(store.notifyEnabled, isFalse);
    expect(store.notifyTime, '06:00');
  });

  test('round trips and stored keys', () {
    store.setHadithSource(HadithSource.allBooks);
    store.setNotifyEnabled(true);
    store.setNotifyTime('05:30');
    expect(store.hadithSource, HadithSource.allBooks);
    expect(store.notifyEnabled, isTrue);
    expect(store.notifyTime, '05:30');
    expect(db.getSetting(SettingKeys.dailyHadithSource), 'all');
    expect(db.getSetting(SettingKeys.dailyNotifyEnabled), 'true');
    expect(db.getSetting(SettingKeys.dailyNotifyTime), '05:30');
  });

  test('invalid stored values fall back to defaults', () {
    db.setSetting(SettingKeys.dailyHadithSource, 'bogus');
    db.setSetting(SettingKeys.dailyNotifyTime, '25:00');
    expect(store.hadithSource, HadithSource.defaultBm);
    expect(store.notifyTime, '06:00');
  });

  test('setNotifyTime rejects invalid input', () {
    for (final t in ['6:00', '24:00', '12:60', 'ab:cd', '06:00 ', '']) {
      expect(() => store.setNotifyTime(t), throwsArgumentError, reason: t);
    }
    expect(store.notifyTime, '06:00');
    store.setNotifyTime('23:59');
    expect(store.notifyTime, '23:59');
  });
}
