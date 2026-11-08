import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class ChecksumManifest {
  ChecksumManifest(this.entries);

  final Map<String, String> entries;

  static final _line = RegExp(r'^([0-9a-fA-F]{64})  (\S.*)$');

  static ChecksumManifest parse(String text) {
    final entries = <String, String>{};
    for (final raw in const LineSplitter().convert(text)) {
      if (raw.trim().isEmpty) continue;
      final m = _line.firstMatch(raw);
      if (m == null) throw FormatException('Malformed checksum line: "$raw"');
      entries[m.group(2) ?? ''] = (m.group(1) ?? '').toLowerCase();
    }
    return ChecksumManifest(entries);
  }

  List<String> verify(Directory root) {
    final problems = <String>[];
    for (final e in entries.entries) {
      final file = File('${root.path}/${e.key}');
      if (!file.existsSync()) {
        problems.add('missing file: ${e.key}');
      } else if (sha256.convert(file.readAsBytesSync()).toString() != e.value) {
        problems.add('hash mismatch: ${e.key}');
      }
    }
    final base = root.absolute.path;
    for (final dir in ['quran', 'hadith', 'meta']) {
      final d = Directory('${root.path}/$dir');
      if (!d.existsSync()) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        final rel = f.absolute.path.substring(base.length + 1).replaceAll(r'\', '/');
        if (!entries.containsKey(rel)) problems.add('unlisted file: $rel');
      }
    }
    return problems;
  }

  String toJson() => jsonEncode(Map.fromEntries(
        entries.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ));
}
