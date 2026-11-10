import 'dart:io';

import 'content_database.dart';

const String contentDbAssetKey = 'assets/db/content.db';
const String contentVersionAssetKey = 'assets/db/content.version';

/// Copies the bundled asset [assetKey] into [destination] (overwriting it).
typedef AssetCopier = Future<void> Function(String assetKey, File destination);
typedef AssetStringLoader = Future<String> Function(String assetKey);

/// Copies the bundled content.db into [targetDir] when the installed copy is
/// missing, unreadable or its `content.version` differs from the bundled one.
/// Only the small version asset is read on a normal start.
class ContentDbInstaller {
  ContentDbInstaller({
    required this.copyAsset,
    required this.loadVersion,
    required this.targetDir,
  });

  final AssetCopier copyAsset;
  final AssetStringLoader loadVersion;
  final Directory targetDir;

  Future<File> ensureInstalled() async {
    await targetDir.create(recursive: true);
    final assetVersion = (await loadVersion(contentVersionAssetKey)).trim();
    final target = File('${targetDir.path}/content.db');
    final versionFile = File('${targetDir.path}/content.version');
    if (_isCurrent(target, versionFile, assetVersion)) return target;

    final tmp = File('${target.path}.tmp');
    try {
      await copyAsset(contentDbAssetKey, tmp);
    } catch (_) {
      if (tmp.existsSync()) await tmp.delete();
      rethrow;
    }
    final schema = _schemaOf(tmp);
    if (schema == null || schema != assetVersion.split(':').first) {
      await tmp.delete();
      throw StateError('Bundled content.db does not match content.version');
    }
    // Write to .tmp then rename: atomic replace on POSIX/Android.
    await tmp.rename(target.path);
    // Version file goes last: a crash before this recopies on next start.
    final versionTmp = File('${versionFile.path}.tmp');
    await versionTmp.writeAsString(assetVersion, flush: true);
    await versionTmp.rename(versionFile.path);
    return target;
  }

  bool _isCurrent(File db, File versionFile, String assetVersion) =>
      db.existsSync() &&
      versionFile.existsSync() &&
      versionFile.readAsStringSync().trim() == assetVersion &&
      _schemaOf(db) != null;

  /// Returns the meta schema_version, or null when unreadable.
  String? _schemaOf(File file) {
    try {
      final db = ContentDatabase.open(file);
      try {
        return db.schemaVersion;
      } finally {
        db.close();
      }
    } catch (_) {
      return null;
    }
  }
}
