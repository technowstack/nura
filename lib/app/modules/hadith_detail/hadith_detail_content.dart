import '../../data/models/hadith.dart';

/// Display model: every string and flag the view renders.
class HadithDetailContent {
  const HadithDetailContent({
    required this.ref,
    required this.title,
    required this.subtitle,
    required this.arab,
    required this.translation,
    required this.showTruncationNote,
    required this.referenceLabel,
  });

  final HadithRef ref;
  final String title;
  final String subtitle;
  final String arab;
  final String translation;
  final bool showTruncationNote;

  /// `HR. <book> No. <n>`, appended when copying.
  final String referenceLabel;
}
