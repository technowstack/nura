import 'dart:convert';
import 'dart:io';

import 'package:nura/app/data/models/prayer_region.dart';

const _base = 'https://equran.id/api/v2/shalat';

/// Fetches provinces (arg null) or kab/kota of one province.
typedef RegionFetcher = Future<List<String>> Function(String? provinsi);

Future<int> fetchPrayerRegions({
  required RegionFetcher fetch,
  required File out,
  Duration delay = const Duration(milliseconds: 200),
  DateTime? now,
}) async {
  final regions = <String, List<String>>{};
  try {
    final provinces = await fetch(null);
    for (final p in provinces) {
      if (zoneOfProvince(p) == null) {
        stderr.writeln('error: no time zone for province "$p"');
        return 1;
      }
      await Future<void>.delayed(delay);
      final kab = await fetch(p);
      if (kab.isEmpty) {
        stderr.writeln('error: province "$p" returned 0 regions');
        return 1;
      }
      regions[p] = kab;
    }
  } on Object catch (e) {
    stderr.writeln('error: $e');
    return 1;
  }
  if (regions.isEmpty) {
    stderr.writeln('error: no provinces');
    return 1;
  }
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'source': _base, 'fetched_at': (now ?? DateTime.now()).toUtc().toIso8601String(), 'regions': regions})}\n',
  );
  stdout.writeln(
    'provinces=${regions.length} '
    'regions=${regions.values.fold<int>(0, (a, l) => a + l.length)}',
  );
  return 0;
}

Future<List<String>> _httpFetch(HttpClient c, String? provinsi) async {
  final req = provinsi == null
      ? await c.getUrl(Uri.parse('$_base/provinsi'))
      : await c.postUrl(Uri.parse('$_base/kabkota'));
  if (provinsi != null) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'provinsi': provinsi}));
  }
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
  final data = (jsonDecode(body) as Map<String, dynamic>)['data'] as List;
  return List<String>.from(data);
}

Future<void> main(List<String> args) async {
  final i = args.indexOf('--out');
  final out = File(
    i >= 0 && i + 1 < args.length
        ? args[i + 1]
        : 'data-source/meta/prayer_regions.json',
  );
  final client = HttpClient();
  final code = await fetchPrayerRegions(
    fetch: (p) => _httpFetch(client, p),
    out: out,
  );
  client.close();
  exit(code);
}
