import 'dart:convert';
import 'dart:io';

import 'package:nura/content_pipeline/juz_rules.dart';
import 'package:nura/content_pipeline/quran_source_parser.dart';

import 'http_get_text.dart';

final juzSourceUrl = Uri.parse(
  'https://tanzil.net/res/text/metadata/quran-data.xml',
);

final _juzTag = RegExp(r'<juz\s+([^>]*?)/?>');

/// Start points (surah, ayah) of the `<juz>` elements, in file order.
/// Throws [FormatException] unless there are exactly 30, indexed 1..30.
List<(int, int)> parseJuzStarts(String xml) {
  final starts = <(int, int)>[];
  for (final m in _juzTag.allMatches(xml)) {
    int attr(String k) {
      final v = RegExp('\\b$k="(\\d+)"').firstMatch(m.group(1) ?? '');
      if (v == null) throw FormatException('juz element lacks "$k"');
      return int.parse(v.group(1) ?? '');
    }

    if (attr('index') != starts.length + 1) {
      throw const FormatException('juz index not 1..30 in order');
    }
    starts.add((attr('sura'), attr('aya')));
  }
  if (starts.length != 30) {
    throw FormatException('expected 30 juz, got ${starts.length}');
  }
  return starts;
}

Future<int> fetchJuz({
  required Uri url,
  required File out,
  required Map<int, int> ayahCounts,
  Duration? timeout,
  DateTime? now,
}) async {
  final List<JuzRange> juz;
  try {
    final xml = await httpGetText(url, timeout: timeout);
    juz = buildJuz(parseJuzStarts(xml), ayahCounts);
  } on Object catch (e) {
    stderr.writeln('error: $e');
    return 1;
  }
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'source': url.toString(),
      'fetched_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'juz': [for (final j in juz) j.toJson()],
    })}\n',
  );
  stdout.writeln('juz=${juz.length}');
  return 0;
}

Future<void> main(List<String> args) async {
  final i = args.indexOf('--out');
  final out = File(
    i >= 0 && i + 1 < args.length ? args[i + 1] : 'data-source/meta/juz.json',
  );
  final counts = {
    for (final s in readQuranDir(Directory('data-source/quran')))
      s.number: s.ayahCount,
  };
  exit(await fetchJuz(url: juzSourceUrl, out: out, ayahCounts: counts));
}
