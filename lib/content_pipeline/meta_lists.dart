import 'dart:convert';
import 'dart:io';

import 'source_models.dart';

const excludedHadithFile = 'meta/daily_hadith_exclude.json';

/// The objects of the optional list file `<root>/[path]`; empty when the file
/// is absent. Throws [SourceFormatException] when it is not a list of objects.
List<Map<String, dynamic>> readMetaObjects(Directory root, String path) {
  final f = File('${root.path}/$path');
  if (!f.existsSync()) return const [];
  final Object? json;
  try {
    json = jsonDecode(f.readAsStringSync());
  } on Object catch (e) {
    throw SourceFormatException(path, 'invalid json: $e');
  }
  if (json is! List<dynamic>) {
    throw SourceFormatException(path, 'must be a json list');
  }
  return [
    for (var i = 0; i < json.length; i++)
      json[i] is Map<String, dynamic>
          ? json[i] as Map<String, dynamic>
          : throw SourceFormatException(path, 'entry $i is not an object'),
  ];
}

/// `book:number` keys of the manually excluded hadith (spec 3.3).
Set<String> readExcludedHadith(Directory root) => {
  for (final e in readMetaObjects(root, excludedHadithFile))
    if (e['book'] is! String || e['number'] is! int)
      throw SourceFormatException(
        excludedHadithFile,
        'entry needs string "book" and integer "number": $e',
      )
    else
      '${e['book']}:${e['number']}',
};
