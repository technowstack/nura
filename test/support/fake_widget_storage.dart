import 'package:nura/app/data/sources/widget_storage.dart';

class FakeWidgetStorage implements WidgetStorage {
  final Map<String, String> data = {};

  /// Keys whose save throws.
  final Set<String> failingKeys = {};
  bool failAll = false;

  @override
  Future<void> save(String key, String? value) async {
    if (failAll || failingKeys.contains(key)) throw StateError('save $key');
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<String?> read(String key) async => data[key];
}
