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

  test('canReach delegates to the probe', () async {
    expect(await OnlineService(db, probe: () async => false).canReach(), false);
    expect(await OnlineService(db, probe: () async => true).canReach(), true);
  });
}
