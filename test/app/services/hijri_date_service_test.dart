import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/services/hijri_date_service.dart';

void main() {
  late Directory tmp;
  late UserDatabase db;
  late HijriDateService s;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_hijri_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    s = HijriDateService(user: db);
  });

  test('default 0, set persists and clamps', () {
    expect(s.adjustDays, 0);
    s.adjustDays = 1;
    expect(s.adjustDays, 1);
    s.adjustDays = -1;
    expect(db.getSetting(SettingKeys.hijriAdjust), '-1');
    s.adjustDays = 5;
    expect(s.adjustDays, 1);
    s.adjustDays = -9;
    expect(s.adjustDays, -1);
  });

  test('invalid stored values read as 0', () {
    db.setSetting(SettingKeys.hijriAdjust, 'abc');
    expect(s.adjustDays, 0);
    db.setSetting(SettingKeys.hijriAdjust, '7');
    expect(s.adjustDays, 0);
  });

  test('adjust shifts the date by days', () {
    final d = DateTime(2026, 11, 19);
    s.adjustDays = 1;
    final plus = s.format(d);
    s.adjustDays = 0;
    expect(plus, s.format(DateTime(2026, 11, 20)));
    s.adjustDays = -1;
    final minus = s.format(d);
    s.adjustDays = 0;
    expect(minus, s.format(DateTime(2026, 11, 18)));
  });

  test('a full year never throws and day is 1..30', () {
    for (
      var d = DateTime(2026, 1, 1);
      d.year == 2026;
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      final day = int.parse(s.format(d).split(' ').first);
      expect(day, inInclusiveRange(1, 30));
    }
  });

  test('12 unique Indonesian month names', () {
    final names = <String>{};
    for (
      var d = DateTime(2026, 1, 1);
      d.year < 2028;
      d = DateTime(d.year, d.month, d.day + 5)
    ) {
      names.add(s.format(d).split(' ')[1]);
    }
    expect(names.length, 12);
    expect(names, containsAll(['Muharram', 'Ramadhan', 'Zulhijah']));
  });

  test('Zulhijah rolls over to Muharram', () {
    var d = DateTime(2026, 1, 1);
    var prev = s.format(d).split(' ');
    var seen = false;
    for (var i = 0; i < 800; i++) {
      d = DateTime(d.year, d.month, d.day + 1);
      final cur = s.format(d).split(' ');
      if (prev[1] == 'Zulhijah' && cur[1] == 'Muharram') {
        expect(cur[0], '1');
        expect(int.parse(cur[2]), int.parse(prev[2]) + 1);
        seen = true;
        break;
      }
      prev = cur;
    }
    expect(seen, isTrue);
  });

  test('time of day does not change the date', () {
    expect(
      s.format(DateTime(2026, 11, 19, 23, 59)),
      s.format(DateTime(2026, 11, 19, 0, 1)),
    );
  });
}
