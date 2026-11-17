/// Streaming audio URLs of one surah, per qari id, ordered by ayah 1..N.
/// A qari lacking a URL for any ayah is absent from the map.
class SurahAudio {
  const SurahAudio({required this.surah, required this.ayahUrlsByQari});

  final int surah;
  final Map<String, List<Uri>> ayahUrlsByQari;

  List<Uri>? urlsFor(String qariId) => ayahUrlsByQari[qariId];
}
