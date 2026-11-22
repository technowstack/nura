import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/widgets/error_state.dart';
import 'package:nura/app/data/models/bookmark.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/hadith_detail/bindings/hadith_detail_binding.dart';
import 'package:nura/app/modules/hadith_detail/controllers/hadith_detail_controller.dart';
import 'package:nura/app/modules/hadith_detail/hadith_detail_args.dart';
import 'package:nura/app/modules/hadith_detail/views/hadith_detail_view.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';

const _slug = 'bukhari';
const _note = 'Teks hadis ini terpotong di sumber data.';

Hadith _h(
  int n, {
  String? arab,
  String? tr,
  bool aT = false,
  bool tT = false,
}) => Hadith(
  ref: HadithRef(_slug, n),
  bookName: 'Shahih Bukhari',
  arab: arab ?? 'arab$n',
  translation: tr ?? 'trans$n',
  translationLength: (tr ?? 'trans$n').length,
  arabTruncated: aT,
  translationTruncated: tT,
);

void main() {
  late FakeHadithRepository repo;
  late FakeUserRepository user;

  setUp(() {
    Get.reset();
    repo = FakeHadithRepository(hadith: [_h(1), _h(2), _h(50), _h(51)]);
    user = FakeUserRepository();
    Get.put<HadithRepository>(repo);
    Get.put<UserRepository>(user);
  });
  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester, int number, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Get.put(HadithDetailController(HadithDetailArgs(_slug, number)));
    await tester.pumpWidget(
      GetMaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HadithDetailView(),
      ),
    );
    await tester.pumpAndSettle();
  }

  HadithDetailController ctl() => Get.find<HadithDetailController>();
  ScrollPosition pos(WidgetTester t) =>
      t.state<ScrollableState>(find.byType(Scrollable).first).position;

  void mockClipboard(WidgetTester tester, void Function(String?) onCopy) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          onCopy((call.arguments as Map)['text'] as String?);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  testWidgets('shows exact text incl. trailing spaces and U+200C', (t) async {
    const arab = 'بِسْمِ ‌ ';
    const tr = 'Terjemah ‌ dengan spasi ';
    repo.hadith = [_h(1, arab: arab, tr: tr)];
    await pump(t, 1);
    expect(find.text(arab), findsOneWidget);
    expect(find.text(tr), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Shahih Bukhari'),
      ),
      findsOneWidget,
    );
    expect(find.text('No. 1'), findsOneWidget);
    expect(find.text(_note), findsNothing);
  });

  testWidgets('8,724 Arabic + 16,384 translation scroll to the end', (t) async {
    final arab = '${'ب' * 8700}${'ا' * 24}';
    final tr = '${'kata ' * 3270}${'x' * 34}'; // 16,384 chars
    expect(arab.length, 8724);
    expect(tr.length, 16384);
    repo.hadith = [_h(1, arab: arab, tr: tr, aT: true, tT: true)];
    user.prefs = const ReadingPrefs(arabicFontSize: 40, showTranslation: true);
    await pump(t, 1, scale: 1.3);
    expect(t.takeException(), isNull);
    final p = pos(t);
    expect(p.maxScrollExtent, greaterThan(0));
    p.jumpTo(p.maxScrollExtent);
    await t.pump();
    expect(t.takeException(), isNull);
    for (final text in [arab, tr]) {
      final w = t.widget<Text>(find.text(text));
      expect(w.maxLines, isNull);
      expect(w.overflow, isNot(TextOverflow.ellipsis));
    }
    expect(p.pixels, p.maxScrollExtent);
    for (final text in [arab, tr]) {
      final rp = t.renderObject<RenderParagraph>(find.text(text));
      expect(rp.didExceedMaxLines, isFalse);
      // The end of the text is really laid out (caret at its last offset).
      final local = rp.getOffsetForCaret(
        TextPosition(offset: text.length),
        Rect.zero,
      );
      expect(local.dy, inInclusiveRange(0, rp.size.height));
      // Arabic has scrolled out above; only the translation ends on screen.
      if (text == tr) {
        expect(rp.localToGlobal(local).dy, inInclusiveRange(0, 640));
      }
    }
    expect(find.text(_note), findsOneWidget);
    expect(t.getRect(find.text('Berikutnya')).bottom, lessThanOrEqualTo(640));
  });

  for (final (aT, tT, shown) in [
    (true, false, true),
    (false, true, true),
    (true, true, true),
    (false, false, false),
  ]) {
    testWidgets('truncation note arab=$aT tr=$tT -> $shown', (t) async {
      repo.hadith = [_h(1, aT: aT, tT: tT, tr: 'x' * 16092)];
      await pump(t, 1);
      expect(find.text(_note), shown ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('showTranslation false hides translation', (t) async {
    user.prefs = const ReadingPrefs(arabicFontSize: 28, showTranslation: false);
    await pump(t, 1);
    expect(find.text('arab1'), findsOneWidget);
    expect(find.text('trans1'), findsNothing);
  });

  testWidgets('next crosses numbering gap, resets scroll, ends disabled', (
    t,
  ) async {
    repo.hadith = [_h(1), _h(2, tr: 'kata ' * 600), _h(50), _h(51)];
    await pump(t, 1);
    await t.tap(find.text('Berikutnya'));
    await t.pumpAndSettle();
    expect(find.text('No. 2'), findsOneWidget);
    pos(t).jumpTo(pos(t).maxScrollExtent);
    await t.pump();
    expect(pos(t).pixels, greaterThan(0));
    await t.tap(find.text('Berikutnya'));
    await t.pumpAndSettle();
    expect(find.text('No. 50'), findsOneWidget);
    expect(find.text('arab50'), findsOneWidget);
    expect(pos(t).pixels, 0);
    await t.tap(find.text('Berikutnya'));
    await t.pumpAndSettle();
    expect(find.text('No. 51'), findsOneWidget);
    expect(ctl().hasNext.value, isFalse);
    expect(
      t
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Berikutnya'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await t.tap(find.text('Sebelumnya'));
    await t.pumpAndSettle();
    expect(find.text('No. 50'), findsOneWidget);
  });

  testWidgets(
    'first hadith has Sebelumnya disabled; neighbor failure -> both off',
    (t) async {
      repo.neighborFailure = StateError('boom');
      await pump(t, 2);
      expect(find.text('arab2'), findsOneWidget);
      expect(ctl().hasPrevious.value, isFalse);
      expect(ctl().hasNext.value, isFalse);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('bookmark twice returns to Tambah bookmark', (t) async {
    await pump(t, 1);
    expect(find.bySemanticsLabel('Tambah bookmark'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Tambah bookmark'));
    await t.pump();
    expect(find.bySemanticsLabel('Hapus bookmark'), findsOneWidget);
    expect(ctl().bookmarked.value, isTrue);
    await t.tap(find.bySemanticsLabel('Hapus bookmark'));
    await t.pump();
    expect(find.bySemanticsLabel('Tambah bookmark'), findsOneWidget);
    expect(find.bySemanticsLabel('Hapus bookmark'), findsNothing);
    final size = t.getSize(
      find.ancestor(
        of: find.bySemanticsLabel('Tambah bookmark'),
        matching: find.byType(IconButton),
      ),
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('bookmark state is re-read when moving to another hadith', (
    t,
  ) async {
    user.hadithBookmarks.add(
      HadithBookmark(ref: const HadithRef(_slug, 2), createdAt: DateTime(2000)),
    );
    await pump(t, 1);
    expect(ctl().bookmarked.value, isFalse);
    await t.tap(find.text('Berikutnya'));
    await t.pumpAndSettle();
    expect(ctl().bookmarked.value, isTrue);
  });

  testWidgets('bookmark write failure keeps state and shows snackbar', (
    t,
  ) async {
    await pump(t, 1);
    user.failure = StateError('disk');
    await t.tap(find.bySemanticsLabel('Tambah bookmark'));
    await t.pump();
    expect(ctl().bookmarked.value, isFalse);
    expect(find.text('Gagal menyimpan bookmark'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('copy puts the format on the clipboard + snackbar', (t) async {
    String? copied;
    mockClipboard(t, (s) => copied = s);
    repo.hadith = [_h(1, arab: 'A ', tr: ' T')];
    await pump(t, 1);
    await ctl().copy();
    await t.pump();
    expect(copied, 'A \n\n T\n\nHR. Shahih Bukhari No. 1');
    expect(find.text('Hadis disalin'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('clipboard failure shows snackbar', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'x');
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(t, 1);
    await ctl().copy();
    await t.pump();
    expect(find.text('Gagal menyalin hadis'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  for (final (name, err) in [
    ('ContentUnavailable', const ContentUnavailable('x') as Object),
    ('StateError', StateError('x')),
  ]) {
    testWidgets('$name -> ErrorState, retry reloads', (t) async {
      repo.failure = err;
      await pump(t, 1);
      expect(find.byType(ErrorState), findsOneWidget);
      repo.failure = null;
      await t.tap(find.text('Coba lagi'));
      await t.pumpAndSettle();
      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('arab1'), findsOneWidget);
    });
  }

  testWidgets('unknown number -> ErrorState', (t) async {
    await pump(t, 999);
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('missing route args -> error, not another hadith', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: Text('home')),
        getPages: [
          GetPage(
            name: Routes.hadithDetail,
            page: HadithDetailView.new,
            binding: HadithDetailBinding(),
          ),
        ],
      ),
    );
    Get.toNamed(Routes.hadithDetail);
    await t.pumpAndSettle();
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('arab1'), findsNothing);
  });

  testWidgets('failing getReadingPrefs -> defaults, no red screen', (t) async {
    user.prefsFailure = StateError('prefs');
    await pump(t, 1);
    expect(t.takeException(), isNull);
    expect(find.text('arab1'), findsOneWidget);
    expect(find.text('trans1'), findsOneWidget);
    expect(ctl().prefs.value.arabicFontSize, 28);
  });

  testWidgets('stale slow getHadith does not overwrite newer content', (
    t,
  ) async {
    await pump(t, 1);
    final gate = Completer<void>();
    repo.hadithGates[2] = gate;
    final slow = ctl().goTo(next: true); // -> 2, slow
    await t.pump();
    repo.hadithGates.remove(2);
    ctl().load(); // retry of current ref (1) supersedes
    await t.pumpAndSettle();
    gate.complete();
    await slow;
    await t.pumpAndSettle();
    expect(find.text('arab1'), findsOneWidget);
    expect(find.text('arab2'), findsNothing);
  });

  testWidgets('Latin 130% on ordinary hadith, no exception', (t) async {
    repo.hadith = [_h(1, arab: 'ب' * 300, tr: 'Kata kata ' * 80)];
    await pump(t, 1, scale: 1.3);
    expect(t.takeException(), isNull);
  });

  testWidgets('result arriving after close changes nothing', (t) async {
    await pump(t, 1);
    final gate = Completer<void>();
    repo.hadithGates[2] = gate;
    final slow = ctl().goTo(next: true);
    await t.pump();
    final c = ctl();
    final before = c.state.value;
    Get.delete<HadithDetailController>();
    gate.complete();
    await slow;
    await t.pump();
    expect(t.takeException(), isNull);
    expect(identical(c.state.value, before), isTrue);
    expect(c.hasNext.value, isTrue);
  });
}
