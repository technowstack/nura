class HadithRef {
  const HadithRef(this.slug, this.number);

  final String slug;
  final int number;

  @override
  bool operator ==(Object other) =>
      other is HadithRef && other.slug == slug && other.number == number;

  @override
  int get hashCode => Object.hash(slug, number);
}

class HadithSummary {
  const HadithSummary({
    required this.ref,
    required this.preview,
    required this.length,
  });

  final HadithRef ref;

  /// First 1000 code points of the translation (preview source), display only.
  final String preview;

  /// Full translation length in UTF-16 code units (`translation_length`).
  final int length;
}

class Hadith {
  const Hadith({
    required this.ref,
    required this.bookName,
    required this.arab,
    required this.translation,
    required this.translationLength,
    required this.arabTruncated,
    required this.translationTruncated,
  });

  final HadithRef ref;
  final String bookName;
  final String arab;
  final String translation;
  final int translationLength;
  final bool arabTruncated;
  final bool translationTruncated;
}

class HadithPage {
  const HadithPage({required this.items, required this.hasMore});

  final List<HadithSummary> items;
  final bool hasMore;
}
