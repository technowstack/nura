import 'dart:io';

import 'package:crypto/crypto.dart';

/// First 16 hex chars of the sha256 of [bytes].
String shortSha256(List<int> bytes) =>
    sha256.convert(bytes).toString().substring(0, 16);

/// Value of the `content.version` sidecar: `<schema_version>:<hash of file>`.
String contentVersionOf(File db, int schemaVersion) =>
    '$schemaVersion:${shortSha256(db.readAsBytesSync())}';
