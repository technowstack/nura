class Ayah {
  const Ayah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.arab,
    required this.translation,
    required this.tafsir,
  });

  final int surahNumber;
  final int ayahNumber;
  final String arab;
  final String translation;
  final String tafsir;
}

class AyahRef {
  const AyahRef(this.surah, this.ayah);

  final int surah;
  final int ayah;

  @override
  bool operator ==(Object other) =>
      other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);
}
