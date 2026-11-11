import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/theme/theme_controller.dart';
import 'package:nura/app/data/repositories/user_repository.dart';

import '../../../support/fake_repositories.dart';

void main() {
  late FakeUserRepository user;
  setUp(() {
    Get.reset();
    user = FakeUserRepository()..themeMode = ThemeMode.light;
    Get.put<UserRepository>(user);
  });
  tearDown(Get.reset);

  test('reads stored mode on init', () {
    expect(ThemeController().mode.value, ThemeMode.system);
    final c = Get.put(ThemeController());
    expect(c.mode.value, ThemeMode.light);
  });

  test('setMode persists and updates', () {
    final c = Get.put(ThemeController());
    c.setMode(ThemeMode.dark);
    expect(c.mode.value, ThemeMode.dark);
    expect(user.themeMode, ThemeMode.dark);
  });

  testWidgets('failed persistence keeps previous mode', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: SizedBox()));
    final c = Get.put(ThemeController());
    user.failure = StateError('disk');
    c.setMode(ThemeMode.dark);
    expect(c.mode.value, ThemeMode.light);
    expect(user.themeMode, ThemeMode.light);
    await tester.pump(const Duration(seconds: 3));
  });
}
