/// Arguments for the surah page. `ayah == 0` means no target ayah.
class SurahArgs {
  const SurahArgs(this.surah, [this.ayah = 0]);

  final int surah;
  final int ayah;
}
