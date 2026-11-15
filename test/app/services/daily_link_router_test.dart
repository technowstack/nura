import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/modules/hadith_detail/hadith_detail_args.dart';
import 'package:nura/app/modules/quran_detail/surah_args.dart';
import 'package:nura/app/routes/app_routes.dart';
import 'package:nura/app/services/daily_link_router.dart';
import 'package:nura/app/services/daily_notifier.dart';

void main() {
  late List<(String, Object)> opened;
  late int homes;
  late StreamController<Uri?> clicks;
  Uri? initial;

  DailyLinkRouter make() => DailyLinkRouter(
    open: (route, args) => opened.add((route, args)),
    popToRoot: () => opened.add(('popToRoot', 0)),
    goHome: () => homes++,
    clicks: clicks.stream,
    initialLink: () async => initial,
  );

  setUp(() {
    opened = [];
    homes = 0;
    initial = null;
    clicks = StreamController<Uri?>.broadcast(sync: true);
  });
  tearDown(() => clicks.close());

  test('ayah link opens the surah at that ayah', () {
    make().handle('nura://ayah/94/6');
    expect(opened.map((e) => e.$1), ['popToRoot', Routes.surah]);
    final a = opened.last.$2 as SurahArgs;
    expect((a.surah, a.ayah), (94, 6));
  });

  test('hadith link opens the hadith detail', () {
    make().handle('nura://hadith/bukhari/34');
    expect(opened.map((e) => e.$1), ['popToRoot', Routes.hadithDetail]);
    final a = opened.last.$2 as HadithDetailArgs;
    expect((a.slug, a.number), ('bukhari', 34));
  });

  test('null, empty, garbage and other schemes do nothing', () {
    final r = make();
    for (final s in [
      null,
      '',
      'garbage',
      'https://ayah/94/6',
      'nura://ayah/x/1',
      'nura://other/a/1',
    ]) {
      r.handle(s);
    }
    expect(opened, isEmpty);
  });

  testWidgets('cold start is handled after the first frame', (tester) async {
    initial = Uri.parse('nura://hadith/muslim/7');
    final r = make()..start();
    await tester.pump();
    expect(opened, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(opened.last.$1, Routes.hadithDetail);
    r.dispose();
  });

  testWidgets('warm clicks are handled until dispose', (tester) async {
    final r = make()..start();
    clicks.add(Uri.parse('nura://ayah/94/5'));
    clicks.add(null);
    expect(opened.length, 2);
    r.dispose();
    expect(clicks.hasListener, isFalse);
    clicks.add(Uri.parse('nura://ayah/94/4'));
    expect(opened.length, 2);
  });

  test('daily notification tap goes to Beranda; others are ignored', () {
    final r = make();
    r.onNotificationTap(dailyPayload);
    expect(homes, 1);
    r.onNotificationTap('prayer');
    r.onNotificationTap(null);
    expect(homes, 1);
  });
}
