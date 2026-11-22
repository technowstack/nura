import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/reading_prefs.dart';
import '../../data/repositories/user_repository.dart';

/// Reading preferences (Arabic size, translation) shared by both readers.
mixin ReadingPrefsMixin on GetxController {
  UserRepository get userRepository;

  // Defaults until load() reads the stored prefs; never touch user.db in build.
  final prefs = Rx<ReadingPrefs>(
    const ReadingPrefs(arabicFontSize: 28, showTranslation: true),
  );

  void setArabicFontSize(double size) {
    final p = prefs.value;
    _savePrefs(
      () => userRepository.setArabicFontSize(size),
      ReadingPrefs(arabicFontSize: size, showTranslation: p.showTranslation),
    );
  }

  void setShowTranslation(bool show) {
    final p = prefs.value;
    _savePrefs(
      () => userRepository.setShowTranslation(show),
      ReadingPrefs(arabicFontSize: p.arabicFontSize, showTranslation: show),
    );
  }

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
