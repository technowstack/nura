import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/shell/views/shell_view.dart';
import '../../../support/fake_repositories.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.put<QuranRepository>(FakeQuranRepository());
    Get.put<UserRepository>(FakeUserRepository());
  });
  tearDown(Get.reset);

  const shell = MaterialApp(home: ShellView(dataVersion: 'v1'));

  testWidgets('has four labelled destinations and Hadis shows Segera hadir', (
    tester,
  ) async {
    await tester.pumpWidget(shell);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    for (final l in ['Beranda', "Al-Qur'an", 'Hadis', 'Sholat']) {
      expect(
        find.descendant(of: find.byType(NavigationBar), matching: find.text(l)),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('Hadis'));
    await tester.pumpAndSettle();
    expect(find.text('Segera hadir'), findsOneWidget);
  });

  testWidgets('Latin 130% at 360x640 does not throw', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.3),
        ),
        child: shell,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Sholat'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
