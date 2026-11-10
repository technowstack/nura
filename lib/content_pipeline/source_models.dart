class SourceAyah {
  const SourceAyah({
    required this.number,
    required this.arab,
    required this.translation,
    required this.tafsir,
  });

  final int number;
  final String arab;
  final String translation;
  final String tafsir;
}

class SourceSurah {
  const SourceSurah({
    required this.number,
    required this.nameArab,
    required this.nameLatin,
    required this.nameId,
    required this.ayahCount,
    required this.ayahs,
  });

  final int number;
  final String nameArab;
  final String nameLatin;
  final String nameId;
  final int ayahCount;
  final List<SourceAyah> ayahs;
}

class SourceHadith {
  const SourceHadith({
    required this.number,
    required this.arab,
    required this.translation,
  });

  final int number;
  final String arab;
  final String translation;
}

class SourceHadithBook {
  const SourceHadithBook({required this.slug, required this.hadiths});

  final String slug;
  final List<SourceHadith> hadiths;
}

// Kept here (not its own file) as the brief lists it with the source models.
class SourceFormatException implements Exception {
  const SourceFormatException(this.file, this.message);

  final String file;
  final String message;

  @override
  String toString() => 'SourceFormatException($file): $message';
}
