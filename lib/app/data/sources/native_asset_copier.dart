import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel(
  'com.technowstack.nura/asset_copy',
);

/// Streams a bundled asset to [destination] on the Android side, so the whole
/// file is never held in Dart memory.
Future<void> copyAssetNatively(String assetKey, File destination) async {
  try {
    await _channel.invokeMethod<void>('copyAsset', {
      'assetKey': assetKey,
      'destination': destination.path,
    });
  } on PlatformException catch (e) {
    throw FileSystemException(
      'Native asset copy failed: ${e.message ?? e.code}',
      destination.path,
    );
  }
}
