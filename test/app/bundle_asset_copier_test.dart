import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/bundle_asset_copier.dart';

class _FakeBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    expect(key, 'assets/x.bin');
    return ByteData.sublistView(Uint8List.fromList([1, 2, 3, 4]));
  }
}

void main() {
  test('writes bundle bytes to destination', () async {
    final dir = Directory.systemTemp.createTempSync('nura_bundle_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final dest = File('${dir.path}/out.bin');
    await copyAssetFromBundle('assets/x.bin', dest, bundle: _FakeBundle());
    expect(dest.readAsBytesSync(), [1, 2, 3, 4]);
  });
}
