import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Key/value store shared with the native home screen widget providers.
abstract interface class WidgetStorage {
  /// Stores [value]; null deletes the key.
  Future<void> save(String key, String? value);

  Future<String?> read(String key);

  /// Asks the native providers to redraw; never throws.
  Future<void> notifyWidgets();
}

/// Backed by `home_widget` (Android SharedPreferences).
class HomeWidgetStorage implements WidgetStorage {
  const HomeWidgetStorage();

  @override
  Future<void> save(String key, String? value) async {
    await HomeWidget.saveWidgetData<String>(key, value);
  }

  @override
  Future<String?> read(String key) => HomeWidget.getWidgetData<String>(key);

  @override
  Future<void> notifyWidgets() async {
    for (final name in const [
      'DailyAyahWidgetProvider',
      'DailyHadithWidgetProvider',
    ]) {
      try {
        await HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.technowstack.nura.$name',
        );
      } on Object catch (e) {
        debugPrint('widget update $name failed: $e');
      }
    }
  }
}
