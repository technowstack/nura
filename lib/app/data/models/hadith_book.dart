class HadithBook {
  const HadithBook({
    required this.slug,
    required this.name,
    required this.hadithCount,
    required this.sortOrder,
  });

  final String slug;
  final String name;
  final int hadithCount;
  final int sortOrder;
}
