import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Source manifest only; the merged manifest is checked by hand per release.
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final permissions = RegExp(
    r'<uses-permission[^>]*?/>',
  ).allMatches(manifest).map((m) => m.group(0) ?? '').toList();

  String name(String tag) =>
      RegExp(r'android:name="([^"]+)"').firstMatch(tag)?.group(1) ?? '';

  test('foreground service permission is removed from the merge', () {
    final removed = permissions.where((p) => p.contains('tools:node="remove"'));
    expect(removed.map(name), ['android.permission.FOREGROUND_SERVICE']);
  });

  test('only the approved permissions are declared', () {
    final declared = permissions.where((p) => !p.contains('tools:node'));
    expect(declared.map(name), [
      'android.permission.INTERNET',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.SCHEDULE_EXACT_ALARM',
      'android.permission.RECEIVE_BOOT_COMPLETED',
    ]);
  });
}
