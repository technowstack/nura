import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/sources/prayer_adjustments.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';

void main() {
  test('reads the five settings at call time; bad values count as 0', () {
    final tmp = Directory.systemTemp.createTempSync('nura_adj_');
    final db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(() {
      db.close();
      tmp.deleteSync(recursive: true);
    });
    final read = prayerAdjustmentsFrom(db);
    expect(read().values.every((v) => v == 0), isTrue);
    db.setSetting(SettingKeys.prayerAdjustAsr, '2');
    db.setSetting(SettingKeys.prayerAdjustIsha, '-3');
    db.setSetting(SettingKeys.prayerAdjustFajr, 'abc');
    final m = read();
    expect(m[PrayerName.ashar], 2);
    expect(m[PrayerName.isya], -3);
    expect(m[PrayerName.subuh], 0);
    expect(m[PrayerName.dzuhur], 0);
  });
}
