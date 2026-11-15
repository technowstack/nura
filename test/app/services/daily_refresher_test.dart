import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/services/daily_refresher.dart';
import 'package:nura/app/services/home_widget_service.dart';

import '../../support/fake_daily.dart';
import '../../support/fake_widget_storage.dart';

void main() {
  late List<String> log;
  late DateTime clock;
  late Object? widgetFailure;
  late Object? notifyFailure;
  Completer<void>? gate;

  DailyRefresher make() => DailyRefresher(
    renderWidgets: () async {
      log.add('widgets:start');
      await gate?.future;
      log.add('widgets:end');
      if (widgetFailure case final f?) throw f;
      return true;
    },
    reschedule: () async {
      log.add('notify');
      if (notifyFailure case final f?) throw f;
    },
    now: () => clock,
  );

  setUp(() {
    log = [];
    clock = DateTime(2026, 11, 15, 9);
    widgetFailure = null;
    notifyFailure = null;
    gate = null;
  });

  test('runs widgets then notifications', () async {
    await make().refresh();
    expect(log, ['widgets:start', 'widgets:end', 'notify']);
  });

  test('runs are serialized', () async {
    gate = Completer<void>();
    final r = make();
    final first = r.refresh(force: true);
    final second = r.refresh(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(log, ['widgets:start']);
    gate?.complete();
    await Future.wait([first, second]);
    expect(log, [
      'widgets:start',
      'widgets:end',
      'notify',
      'widgets:start',
      'widgets:end',
      'notify',
    ]);
  });

  test('a failing part never throws and the other part still runs', () async {
    widgetFailure = StateError('w');
    await make().refresh();
    expect(log.last, 'notify');
    log.clear();
    widgetFailure = null;
    notifyFailure = StateError('n');
    await make().refresh();
    expect(log, ['widgets:start', 'widgets:end', 'notify']);
  });

  test(
    'skips on the same date, runs after the date changes or forced',
    () async {
      final r = make();
      await r.refresh();
      log.clear();
      clock = DateTime(2026, 11, 15, 23);
      await r.refresh();
      expect(log, isEmpty);
      await r.refresh(force: true);
      expect(log, isNotEmpty);
      log.clear();
      clock = DateTime(2026, 11, 16, 0, 1);
      await r.refresh();
      expect(log, isNotEmpty);
    },
  );

  test('a failed run does not count as done', () async {
    final r = make();
    notifyFailure = StateError('n');
    await r.refresh();
    log.clear();
    notifyFailure = null;
    await r.refresh();
    expect(log, isNotEmpty);
  });

  testWidgets('runs after the first frame, on each resume, not after dispose', (
    tester,
  ) async {
    final r = make()..start();
    expect(log, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(log.where((e) => e == 'notify').length, 1);
    log.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // Same date: resume is skipped by the date guard.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(log, isEmpty);
    clock = DateTime(2026, 11, 16, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(log.where((e) => e == 'notify').length, 1);
    log.clear();
    r.dispose();
    clock = DateTime(2026, 11, 17, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(log, isEmpty);
  });

  test('a failed widget render is retried on the same date', () async {
    final dir = Directory.systemTemp.createTempSync('nura_ref');
    addTearDown(() => dir.deleteSync(recursive: true));
    var failRender = true;
    final widgets = HomeWidgetService(
      repository: FakeDailyContentRepository(),
      settings: FakeDailySettingsStore(),
      storage: FakeWidgetStorage(),
      directory: dir,
      render:
          (c, {required dp, required pixelRatio, required brightness}) async {
            if (failRender) throw StateError('render');
            return Uint8List(1);
          },
      now: () => clock,
      pixelRatio: () => 1,
    );
    var notifies = 0;
    final r = DailyRefresher(
      renderWidgets: widgets.refresh,
      reschedule: () async => notifies++,
      now: () => clock,
    );
    await r.refresh();
    expect(notifies, 1);
    failRender = false;
    await r.refresh();
    expect(notifies, 2);
    await r.refresh();
    expect(notifies, 2);
  });
}
