import 'package:home_widget/home_widget.dart';

/// Key/value store shared with the native home screen widget providers.
abstract interface class WidgetStorage {
  /// Stores [value]; null deletes the key.
  Future<void> save(String key, String? value);

  Future<String?> read(String key);
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
}
