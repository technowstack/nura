import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'fixtures.dart';

const _sal = "shallallahu 'alaihi wasallam";
const _key = 'صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ';

/// Arabic text with a sanad, the salawat, a speech verb and [body].
String arabWithMatan(String body, {String sanad = 'حَدَّثَنَا فُلَانٌ'}) =>
    '$sanad $_key قَالَ $body';

/// Translation with a sanad and [body] quoted after "bersabda:".
String translationWithMatan(String body) =>
    'Telah menceritakan kepada kami [Fulan] $_sal bersabda: "$body"';

/// A hadith JSON file in the source format.
String hadithJson(List<({int number, String arab, String id})> items) =>
    jsonEncode([
      for (final h in items) {'number': h.number, 'arab': h.arab, 'id': h.id},
    ]);

({int number, String arab, String id}) goodHadith(int number) => (
  number: number,
  arab: arabWithMatan('مَنْ يَقُمْ لَيْلَةَ الْقَدْرِ إِيمَانًا $number'),
  id: translationWithMatan(
    'Barangsiapa menegakkan malam qadar dengan iman $number',
  ),
);

({int number, String arab, String id}) narrativeHadith(int number) => (
  number: number,
  arab: 'حَدَّثَنَا فُلَانٌ أَنَّهُ ذَهَبَ إِلَى السُّوقِ',
  id: 'Telah menceritakan kepada kami [Fulan] bahwa dia pergi ke pasar',
);

/// Copies the fixture tree to `<parent>/<name>`, overlays [files] (paths
/// relative to the tree, null deletes) and rewrites CHECKSUMS.sha256 so the
/// tree verifies.
Directory makeSource(
  Directory parent,
  String name, {
  Map<String, String?> files = const {},
}) {
  final dst = Directory('${parent.path}/$name')..createSync(recursive: true);
  final from = fixtureDir('');
  for (final f in from.listSync(recursive: true).whereType<File>()) {
    final rel = f.path
        .substring(from.path.length)
        .replaceFirst(RegExp('^/'), '');
    File('${dst.path}/$rel')
      ..createSync(recursive: true)
      ..writeAsBytesSync(f.readAsBytesSync());
  }
  for (final e in files.entries) {
    final f = File('${dst.path}/${e.key}');
    final text = e.value;
    if (text == null) {
      if (f.existsSync()) f.deleteSync();
    } else {
      f
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    }
  }
  final lines = <String>[];
  for (final dir in ['quran', 'hadith', 'meta']) {
    final d = Directory('${dst.path}/$dir');
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(dst.path.length + 1);
      lines.add('${sha256.convert(f.readAsBytesSync())}  $rel');
    }
  }
  lines.sort();
  File(
    '${dst.path}/CHECKSUMS.sha256',
  ).writeAsStringSync('${lines.join('\n')}\n');
  return dst;
}
