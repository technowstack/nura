class Surah {
  const Surah({
    required this.number,
    required this.nameArab,
    required this.nameLatin,
    required this.nameId,
    required this.ayahCount,
    required this.revelation,
  });

  final int number;
  final String nameArab;
  final String nameLatin;
  final String nameId;
  final int ayahCount;
  final String revelation;
}
