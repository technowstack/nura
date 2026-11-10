import 'dart:convert';
import 'dart:io';

import 'source_models.dart';

SourceHadithBook parseHadithFile(String slug, String jsonText) {
  try {
    final list = jsonDecode(jsonText) as List<dynamic>;
    return SourceHadithBook(
      slug: slug,
      hadiths: [
        for (final e in list.cast<Map<String, dynamic>>())
          SourceHadith(
            number: e['number'] as int,
            arab: e['arab'] as String,
            translation: e['id'] as String,
          ),
      ],
    );
  } on Object catch (e) {
    throw SourceFormatException(slug, 'invalid hadith json: $e');
  }
}

List<SourceHadithBook> readHadithDir(Directory dir) {
  final books = [
    for (final f in dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.json'),
    ))
      parseHadithFile(
        f.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), ''),
        f.readAsStringSync(),
      ),
  ];
  return books..sort((a, b) => a.slug.compareTo(b.slug));
}
