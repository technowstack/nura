import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/services/online_service.dart';

void main() {
  test('connectivityChanges maps results to online flag', () async {
    final tmp = Directory.systemTemp.createTempSync('nura_conn_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    final src = StreamController<List<ConnectivityResult>>();
    addTearDown(src.close);
    final svc = OnlineService(db, connectivity: src.stream);
    final out = <bool>[];
    final sub = svc.connectivityChanges.listen(out.add);
    addTearDown(sub.cancel);
    src
      ..add([ConnectivityResult.none])
      ..add([ConnectivityResult.wifi])
      ..add([ConnectivityResult.none, ConnectivityResult.mobile]);
    await pumpEventQueue();
    expect(out, [false, true, true]);
  });
}
