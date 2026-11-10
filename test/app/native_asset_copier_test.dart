import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/native_asset_copier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.technowstack.nura/asset_copy');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('invokes copyAsset with key and destination path', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return null;
    });
    await copyAssetNatively('assets/db/content.db', File('/tmp/x.tmp'));
    expect(seen?.method, 'copyAsset');
    expect(seen?.arguments, {
      'assetKey': 'assets/db/content.db',
      'destination': '/tmp/x.tmp',
    });
  });

  test('maps PlatformException to FileSystemException with message', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'copy_failed', message: 'no space');
    });
    await expectLater(
      copyAssetNatively('assets/db/content.db', File('/tmp/x.tmp')),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          contains('no space'),
        ),
      ),
    );
  });
}
