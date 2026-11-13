import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/user_repository.dart';

class ThemeController extends GetxController {
  final UserRepository _user = Get.find();
  final mode = Rx<ThemeMode>(ThemeMode.system);

  @override
  void onInit() {
    super.onInit();
    try {
      mode.value = _user.getThemeMode();
    } on Object catch (e) {
      debugPrint('ThemeController: read failed: $e');
    }
  }

  /// Persists first; the UI only changes when storage succeeded.
  void setMode(ThemeMode value) {
    try {
      _user.setThemeMode(value);
    } on Object catch (e) {
      debugPrint('ThemeController: save failed: $e');
      Get.showSnackbar(
        const GetSnackBar(
          message: 'Gagal menyimpan tema',
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    mode.value = value;
    Get.changeThemeMode(value);
  }
}
