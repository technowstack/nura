import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/modules/quran_detail/last_read_tracker.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

void main() {
  const a = AyahRef(1, 2);
  const b = AyahRef(1, 3);

  testWidgets('report debounces and saves only the last ref', (t) async {
    final saved = <AyahRef>[];
    final tr = LastReadTracker(saved.add, debounce: const Duration(seconds: 3));
    tr.report(a);
    await t.pump(const Duration(seconds: 2));
    tr.report(b);
    await t.pump(const Duration(seconds: 2));
    expect(saved, isEmpty);
    await t.pump(const Duration(seconds: 1));
    expect(saved, [b]);
    expect(tr.pending, b);
  });

  testWidgets('flush saves at once, markSaved suppresses a rewrite', (t) async {
    final saved = <AyahRef>[];
    final tr = LastReadTracker(saved.add, debounce: const Duration(seconds: 3));
    tr.report(a);
    tr.flush();
    expect(saved, [a]);
    tr.flush();
    expect(saved, [a]);
    final fresh = LastReadTracker(
      saved.add,
      debounce: const Duration(seconds: 3),
    )..markSaved(b);
    fresh.report(b);
    fresh.flush();
    expect(saved, [a]);
  });

  testWidgets('a failed save leaves saved unchanged so it is retried', (
    t,
  ) async {
    var fail = true;
    final saved = <AyahRef>[];
    final tr = LastReadTracker((r) {
      if (fail) throw StateError('disk');
      saved.add(r);
    }, debounce: const Duration(seconds: 3));
    tr.report(a);
    tr.flush();
    expect(saved, isEmpty);
    fail = false;
    tr.flush();
    expect(saved, [a]);
  });

  testWidgets('list reports are ignored until a real user scroll', (t) async {
    final saved = <AyahRef>[];
    final tr = LastReadTracker(saved.add, debounce: Duration.zero);
    final list = ListController();
    final scroll = ScrollController();
    addTearDown(list.dispose);
    addTearDown(scroll.dispose);
    int calls = 0;
    list.addListener(
      () => tr.onVisibleRange(list, scroll, (i) {
        calls++;
        return AyahRef(1, i + 1);
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        home: SuperListView.builder(
          listController: list,
          controller: scroll,
          itemCount: 100,
          itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
        ),
      ),
    );
    await t.pump();
    scroll.jumpTo(300); // programmatic: not a user scroll
    await t.pump();
    tr.flush();
    expect(calls, 0);
    expect(saved, isEmpty);
    final g = await t.startGesture(const Offset(180, 400));
    for (var i = 0; i < 4; i++) {
      await g.moveBy(const Offset(0, -150));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
    tr.flush();
    expect(calls, greaterThan(0));
    expect(saved, isNotEmpty);
  });
}
