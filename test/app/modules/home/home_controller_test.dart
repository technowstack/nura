import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';

import '../../../support/fake_daily.dart';

void main() {
  late FakeDailyContentRepository repo;
  late FakeDailySettingsStore store;
  late DateTime clock;

  setUp(() {
    Get.reset();
    repo = FakeDailyContentRepository();
    store = FakeDailySettingsStore();
    clock = DateTime(2026, 11, 15, 10);
    Get.put<DailyContentRepository>(repo);
    Get.put<DailySettingsStore>(store);
  });
  tearDown(Get.reset);

  // Closes the controller (cancelling its timer) before the framework checks
  // for pending timers.
  void tc(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        Get.delete<HomeController>(force: true);
      });

  HomeController make() =>
      Get.put(HomeController(now: () => clock), permanent: false);

  DailyCards cards(HomeController c) =>
      (c.cards.value as UiData<DailyCards>).value;

  tc('ayah null shows only the hadith', (tester) async {
    repo.withAyah = false;
    final c = make();
    expect(cards(c).ayah, isNull);
    expect(cards(c).hadith?.reference, 'HR. Shahih Bukhari No. 15');
  });

  tc('both present: ayah and hadith of today', (tester) async {
    final c = make();
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 15');
    expect(cards(c).hadith?.translation, contains('(default)'));
  });

  tc('both null is empty', (tester) async {
    repo.withAyah = false;
    repo.withHadith = false;
    expect(make().cards.value, isA<UiEmpty<DailyCards>>());
  });

  tc('failure is UiError and retry recovers', (tester) async {
    repo.failure = const ContentUnavailable('x');
    final c = make();
    expect(c.cards.value, isA<UiError<DailyCards>>());
    repo.failure = null;
    c.refreshForToday();
    expect(c.cards.value, isA<UiData<DailyCards>>());
  });

  tc('crossing local midnight switches the cards and re-arms', (tester) async {
    final c = make();
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 15');
    clock = DateTime(2026, 11, 16);
    await tester.pump(const Duration(hours: 14));
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 16');
    clock = DateTime(2026, 11, 17);
    await tester.pump(const Duration(hours: 24));
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 17');
  });

  tc('changing the source reloads the hadith and persists', (tester) async {
    final c = make();
    c.setHadithSource(HadithSource.allBooks);
    expect(store.hadithSource, HadithSource.allBooks);
    expect(c.hadithSource.value, HadithSource.allBooks);
    expect(cards(c).hadith?.translation, contains('(all)'));
  });

  tc('resume refreshes', (tester) async {
    final c = make();
    final before = repo.calls;
    clock = DateTime(2026, 11, 16, 8);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(repo.calls, before + 1);
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 16');
  });
}
