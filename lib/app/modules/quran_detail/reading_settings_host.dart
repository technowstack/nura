import 'package:get/get.dart';

import '../../data/models/reading_prefs.dart';

/// What the reading-settings sheet needs from a reader controller.
abstract interface class ReadingSettingsHost {
  Rx<ReadingPrefs> get prefs;
  RxBool get audioVisible;
  RxString get qariId;

  /// Arabic line shown above the size slider; null hides it (not loaded).
  String? get previewText;

  void setArabicFontSize(double size);
  void setShowTranslation(bool show);
  void setAudioEnabled(bool on);
  void setQari(String id);
}
