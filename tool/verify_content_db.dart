import 'dart:io';

import 'package:nura/content_pipeline/content_db_verifier.dart';

String? _opt(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

void main(List<String> args) {
  final source = _opt(args, '--source') ?? 'data-source';
  final db = _opt(args, '--db') ?? 'assets/db/content.db';
  try {
    final report = verifyContentDb(
      sourceRoot: Directory(source),
      database: File(db),
      expected: args.contains('--full') ? fullDatasetTotals : null,
      versionFile: args.contains('--full')
          ? File('${File(db).parent.path}/content.version')
          : null,
    );
    for (final w in report.warnings) {
      stdout.writeln('warning: $w');
    }
    for (final e in report.errors) {
      stdout.writeln('error: $e');
    }
    stdout.writeln(
      'errors=${report.errors.length} warnings=${report.warnings.length}',
    );
    exit(report.ok ? 0 : 1);
  } on Object catch (e) {
    stdout.writeln('error: $e');
    exit(1);
  }
}
