import 'ayah.dart';

class Juz {
  const Juz({
    required this.number,
    required this.startSurah,
    required this.startAyah,
    required this.endSurah,
    required this.endAyah,
  });

  final int number;
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;

  AyahRef get start => AyahRef(startSurah, startAyah);
  AyahRef get end => AyahRef(endSurah, endAyah);
}
