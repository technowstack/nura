import 'package:nura/app/data/sources/widget_storage.dart';

class FakeWidgetStorage implements WidgetStorage {
  final Map<String, String> data = {};

  /// Keys whose save throws.
  final Set<String> failingKeys = {};
  bool failAll = false;

  int notifies = 0;
  bool failNotify = false;

  /// Number of saved daily entries seen at each notify.
  final List<int> entriesAtNotify = [];

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
  Future<void> notifyWidgets() async {
    notifies++;
    entriesAtNotify.add(
      data.keys
          .where((k) => k.startsWith('daily_') && k.contains('_20'))
          .length,
    );
    if (failNotify) throw StateError('notify');
  }

  @override
  Future<String?> read(String key) async => data[key];
}
