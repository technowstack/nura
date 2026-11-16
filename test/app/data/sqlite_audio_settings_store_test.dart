import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/qari.dart';
import 'package:nura/app/data/repositories/sqlite_audio_settings_store.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';

void main() {
  late Directory tmp;
  late UserDatabase db;
  late SqliteAudioSettingsStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_aset_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    store = SqliteAudioSettingsStore(db);
  });

  test('catalog has exactly the six qaris', () {
    expect({for (final q in kQaris) q.id: q.name}, {
      '01': 'Abdullah Al-Juhany',
      '02': 'Abdul Muhsin Al-Qasim',
      '03': 'Abdurrahman As-Sudais',
      '04': 'Ibrahim Al-Dossari',
      '05': 'Misyari Rasyid Al-Afasi',
      '06': 'Yasser Al-Dosari',
    });
    expect(kQaris.length, 6);
    expect(qariById('03')?.name, 'Abdurrahman As-Sudais');
    expect(qariById('99'), isNull);
  });

  test('default qari is 05, also for unknown stored id', () {
    expect(kDefaultQariId, '05');
    expect(store.qariId, '05');
    db.setSetting(SettingKeys.qariId, '99');
    expect(store.qariId, '05');
  });

  test('round trips every qari id', () {
    for (final q in kQaris) {
      store.setQariId(q.id);
      expect(store.qariId, q.id);
      expect(db.getSetting(SettingKeys.qariId), q.id);
    }
  });

  test('unknown id throws and leaves stored value untouched', () {
    store.setQariId('02');
    expect(() => store.setQariId('99'), throwsArgumentError);
    expect(store.qariId, '02');
    expect(db.getSetting(SettingKeys.qariId), '02');
  });
}
