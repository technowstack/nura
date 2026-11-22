import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/reading_prefs.dart';
import '../../data/repositories/user_repository.dart';

/// Reading preferences (Arabic and translation size, translation) shared by
/// both readers and the Settings screen. The stored values are the single
/// source of truth; readers re-read them with [refreshPrefs] after Settings.
mixin ReadingPrefsMixin on GetxController {
  UserRepository get userRepository;

  // Defaults until load() reads the stored prefs; never touch user.db in build.
  final prefs = Rx<ReadingPrefs>(
    const ReadingPrefs(arabicFontSize: 28, showTranslation: true),
  );

  /// Re-reads the stored prefs; keeps the current ones when storage fails.
  void refreshPrefs() {
    try {
      prefs.value = userRepository.getReadingPrefs();
    } on Object catch (e) {
      debugPrint('ReadingPrefsMixin: read prefs failed: $e');
    }
  }

  void setArabicFontSize(double size) => _savePrefs(
    () => userRepository.setArabicFontSize(size),
    prefs.value.copyWith(arabicFontSize: size),
  );

  void setTranslationFontSize(double size) => _savePrefs(
    () => userRepository.setTranslationFontSize(size),
    prefs.value.copyWith(translationFontSize: size),
  );

  void setShowTranslation(bool show) => _savePrefs(
    () => userRepository.setShowTranslation(show),
    prefs.value.copyWith(showTranslation: show),
  );

  /// Persists first; the UI only changes when storage succeeded.
  void _savePrefs(void Function() save, ReadingPrefs next) {
    try {
      save();
    } on Object catch (e) {
      debugPrint('ReadingPrefsMixin: save prefs failed: $e');
      notify('Gagal menyimpan pengaturan');
      return;
    }
    prefs.value = next;
  }

  void notify(String message) => Get.showSnackbar(
    GetSnackBar(message: message, duration: const Duration(seconds: 2)),
  );
}
