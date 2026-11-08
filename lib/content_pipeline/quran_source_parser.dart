import 'dart:convert';
import 'dart:io';

import 'source_models.dart';

SourceSurah parseQuranFile(String jsonText, {String file = '<memory>'}) {
  try {
    final top = jsonDecode(jsonText) as Map<String, dynamic>;
    final s = top.values.single as Map<String, dynamic>;
    final texts = s['text'] as Map<String, dynamic>;
    final id = (s['translations'] as Map<String, dynamic>)['id'] as Map<String, dynamic>;
    final translations = id['text'] as Map<String, dynamic>;
    final tafsirs = (((s['tafsir'] as Map<String, dynamic>)['id']
            as Map<String, dynamic>)['kemenag'] as Map<String, dynamic>)['text']
        as Map<String, dynamic>;
    final ayahCount = int.parse(s['number_of_ayah'] as String);
    if (texts.length != ayahCount) {
      throw SourceFormatException(
        file,
        'ayah count ${texts.length} != number_of_ayah $ayahCount',
      );
    }
    final keys = texts.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    final ayahs = <SourceAyah>[];
    for (final k in keys) {
      final translation = translations[k];
      final tafsir = tafsirs[k];
      if (translation is! String || tafsir is! String) {
        throw SourceFormatException(file, 'ayah $k missing translation or tafsir');
      }
      ayahs.add(SourceAyah(
        number: int.parse(k),
        arab: texts[k] as String,
        translation: translation,
        tafsir: tafsir,
      ));
    }
    return SourceSurah(
      number: int.parse(s['number'] as String),
      nameArab: s['name'] as String,
      nameLatin: s['name_latin'] as String,
      nameId: id['name'] as String,
      ayahCount: ayahCount,
      ayahs: ayahs,
    );
  } on SourceFormatException {
    rethrow;
  } on Object catch (e) {
    throw SourceFormatException(file, 'invalid quran json: $e');
  }
}

List<SourceSurah> readQuranDir(Directory dir) {
  final surahs = [
    for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')))
      parseQuranFile(f.readAsStringSync(), file: f.path),
  ];
  return surahs..sort((a, b) => a.number.compareTo(b.number));
}
