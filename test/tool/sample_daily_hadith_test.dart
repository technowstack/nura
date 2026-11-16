import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/content_db_builder.dart';
import 'package:nura/content_pipeline/content_schema.dart';

import '../support/source_tree.dart';

// Test code: `!` marks values the fixture guarantees; a null fails the test anyway.
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

  Future<String> run(String name, {String? seed}) async {
    final out = '${tmp.path}/$name.md';
    final r = await Process.run('dart', [
      'run',
      'tool/sample_daily_hadith.dart',
      if (seed != null) ...['--seed', seed],
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

  test(
    '--seed picks another deterministic set, still from default only',
    () async {
      final a = await run('a');
      final s2 = await run('s2', seed: '20261116');
      expect(await run('s2b', seed: '20261116'), s2);
      expect(s2, isNot(a));
      expect(s2, contains('seed 20261116'));
      expect(a, contains('seed 20261115'));
      expect(
        RegExp(r'^## \d+\. ', multiLine: true).allMatches(s2),
        hasLength(50),
      );
      expect(s2, isNot(contains(hadithBookNames['abu-daud']!)));
      // The header states the rule.
      expect(s2, contains('tanda kutip'));
    },
  );
}
