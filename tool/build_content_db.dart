import 'dart:io';

import 'package:nura/content_pipeline/content_db_builder.dart';

String? _opt(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

void main(List<String> args) {
  final source = _opt(args, '--source') ?? 'data-source';
  final out = _opt(args, '--out') ?? 'assets/db/content.db';
  final sw = Stopwatch()..start();
  try {
    final output = File(out)..parent.createSync(recursive: true);
    final r = buildContentDb(sourceRoot: Directory(source), output: output);
    File(
      '${output.parent.path}/content.version',
    ).writeAsStringSync(r.contentVersion);
    stdout.writeln('content.version=${r.contentVersion}');
    stdout.writeln(
      'surahs=${r.surahCount} ayahs=${r.ayahCount} hadiths=${r.hadithCount}',
    );
    for (final w in r.warnings) {
      stdout.writeln('warning: $w');
    }
    stdout.writeln(
      'warnings=${r.warnings.length} time=${sw.elapsed.inSeconds}s '
      'size=${(output.lengthSync() / 1048576).toStringAsFixed(2)} MB',
    );
  } on Object catch (e) {
    stderr.writeln('error: $e');
    exit(1);
  }
}
