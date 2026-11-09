class BuildResult {
  const BuildResult({
    required this.surahCount,
    required this.ayahCount,
    required this.hadithCount,
    required this.warnings,
  });

  final int surahCount;
  final int ayahCount;
  final int hadithCount;
  final List<String> warnings;
}
