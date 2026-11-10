class BuildResult {
  const BuildResult({
    required this.surahCount,
    required this.ayahCount,
    required this.hadithCount,
    required this.warnings,
    required this.contentVersion,
  });

  final int surahCount;
  final int ayahCount;
  final int hadithCount;
  final List<String> warnings;

  /// Contents for the `content.version` sidecar of the built file.
  final String contentVersion;
}
