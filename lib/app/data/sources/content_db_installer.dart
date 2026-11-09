import 'dart:io';
import 'dart:typed_data';

import 'content_database.dart';

const String contentDbAssetKey = 'assets/db/content.db';

typedef AssetBytesLoader = Future<Uint8List> Function(String assetKey);

/// Copies the bundled content.db into [targetDir] when missing, corrupt or
/// carrying a different data_version.
class ContentDbInstaller {
  ContentDbInstaller({required this.loadAsset, required this.targetDir});

  final AssetBytesLoader loadAsset;
  final Directory targetDir;

  Future<File> ensureInstalled() async {
    await targetDir.create(recursive: true);
    final target = File('${targetDir.path}/content.db');
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(await loadAsset(contentDbAssetKey), flush: true);
    final assetVersion = _versionOf(tmp);
    if (assetVersion != null && _versionOf(target) == assetVersion) {
      await tmp.delete();
      return target;
    }
    await tmp.rename(target.path);
    return target;
  }

  /// Returns null when the file is missing or unreadable.
  String? _versionOf(File file) {
    if (!file.existsSync()) return null;
    try {
      final db = ContentDatabase.open(file);
      final v = db.dataVersion;
      db.close();
      return v;
    } catch (_) {
      return null;
    }
  }
}
