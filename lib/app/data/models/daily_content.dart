import 'ayah.dart';
import 'hadith.dart';

enum DailyKind { ayah, hadith }

enum HadithSource {
  defaultBm('default'),
  allBooks('all');

  const HadithSource(this.value);

  /// Value stored in `daily_hadith.list` and in user settings.
  final String value;
}

class DailyContent {
  const DailyContent({
    required this.kind,
    required this.arab,
    required this.translation,
    required this.reference,
    required this.deepLink,
    this.ayahRef,
    this.hadithRef,
  });

  final DailyKind kind;
  final String arab;
  final String translation;
  final String reference;
  final String deepLink;
  final AyahRef? ayahRef;
  final HadithRef? hadithRef;
}
