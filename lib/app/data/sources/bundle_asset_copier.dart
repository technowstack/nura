import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the whole asset into memory via the bundle, then writes it.
/// Used where no native streaming copier exists.
Future<void> copyAssetFromBundle(
  String assetKey,
  File destination, {
  AssetBundle? bundle,
}) async {
  final data = await (bundle ?? rootBundle).load(assetKey);
  await destination.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
}
