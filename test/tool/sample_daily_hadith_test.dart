import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/content_db_builder.dart';
import 'package:nura/content_pipeline/content_schema.dart';

import '../support/source_tree.dart';

void main() {
  late Directory tmp;
  late File db;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sample_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final src = makeSource(
      tmp,
      'src',
      files: {
        'hadith/bukhari.json': hadithJson([
          for (var i = 1; i <= 40; i++) goodHadith(i),
        ]),
        'hadith/muslim.json': hadithJson([
          for (var i = 1; i <= 40; i++) goodHadith(i),
        ]),
        'hadith/abu-daud.json': hadithJson([goodHadith(900)]),
      },
    );
    db = File('${tmp.path}/content.db');
    buildContentDb(sourceRoot: src, output: db);
  });

  Future<String> run(String name) async {
    final out = '${tmp.path}/$name.md';
    final r = await Process.run('dart', [
      'run',
      'tool/sample_daily_hadith.dart',
      '--db',
      db.path,
      '--out',
      out,
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return File(out).readAsStringSync();
  }

  test('writes 50 deterministic samples from the default list only', () async {
    final a = await run('a');
    expect(await run('b'), a);
    expect(RegExp(r'^## \d+\. ', multiLine: true).allMatches(a), hasLength(50));
    expect(a, contains('Barangsiapa menegakkan malam qadar dengan iman'));
    expect(a, contains('مَنْ يَقُمْ لَيْلَةَ الْقَدْرِ'));
    expect(a, contains('HR. ${hadithBookNames['bukhari']} No. '));
    expect(a, contains('HR. ${hadithBookNames['muslim']} No. '));
    expect(a, isNot(contains(hadithBookNames['abu-daud']!)));
  });
}
