import '../../data/models/ayah.dart';
import '../../data/models/surah.dart';

/// One row of the flat juz reader list.
sealed class JuzItem {
  const JuzItem();
}

/// Surah header, shown whenever the surah changes (also at the top of the
/// juz). [withBasmalah] only when ayah 1 of the surah is in the list.
class SurahHeaderItem extends JuzItem {
  const SurahHeaderItem(this.surah, {required this.withBasmalah});

  final Surah surah;
  final bool withBasmalah;
}

class AyahItem extends JuzItem {
  const AyahItem(this.ayah);

  final Ayah ayah;
}
