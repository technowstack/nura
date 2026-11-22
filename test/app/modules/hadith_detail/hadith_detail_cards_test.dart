import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/nura_icons.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/models/hadith_book.dart';
import 'package:nura/app/data/models/reading_prefs.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/hadith_detail/controllers/hadith_detail_controller.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/modules/hadith_detail/hadith_detail_args.dart';
import 'package:nura/app/modules/hadith_detail/hadith_detail_content.dart';
import 'package:nura/app/modules/hadith_detail/views/hadith_detail_view.dart';

import '../../../support/fake_repositories.dart';

Hadith _h(String slug, int n, {String? arab}) => Hadith(
  ref: HadithRef(slug, n),
  bookName: 'Shahih Bukhari',
  arab: arab ?? 'arab$n',
  translation: 'trans$n',
  translationLength: 6,
  arabTruncated: false,
  translationTruncated: false,
);

void main() {
  late FakeHadithRepository repo;
  late FakeUserRepository user;

  setUp(() {
    Get.reset();
    repo = FakeHadithRepository(
      hadith: [_h('bukhari', 1), _h('bukhari', 2), _h('zzz', 1)],
      books: const [
        HadithBook(
          slug: 'bukhari',
          name: 'Shahih Bukhari',
          hadithCount: 6638,
          sortOrder: 1,
        ),
        HadithBook(slug: 'zzz', name: 'Zzz', hadithCount: 5, sortOrder: 2),
      ],
    );
    user = FakeUserRepository();
    Get.put<HadithRepository>(repo);
    Get.put<UserRepository>(user);
  });
  tearDown(Get.reset);

  Future<void> pump(
    WidgetTester t,
    String slug,
    int n, {
    double scale = 1,
    ThemeMode mode = ThemeMode.light,
  }) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Get.put(HadithDetailController(HadithDetailArgs(slug, n)));
    await t.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HadithDetailView(),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('hero shows kitab, nomor, formatted count and Arabic name', (
    t,
  ) async {
    await pump(t, 'bukhari', 1);
    expect(find.textContaining('Kitab', findRichText: true), findsOneWidget);
    expect(find.textContaining('Nomor', findRichText: true), findsOneWidget);
    expect(find.textContaining('6.638', findRichText: true), findsOneWidget);
    expect(find.text('صحيح البخاري'), findsOneWidget);
  });

  testWidgets('unknown slug has no Arabic name in hero', (t) async {
    await pump(t, 'zzz', 1);
    expect(find.textContaining('Kitab', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('hadith-hero-arab')), findsNothing);
  });

  testWidgets('reference row and copy string unchanged', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await pump(t, 'bukhari', 1);
    expect(find.text('HR. Bukhari No. 1'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Salin hadis'));
    await t.pump();
    expect(copied, 'arab1\n\ntrans1\n\nHR. Bukhari No. 1');
    await t.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('action cells are 48 dp, outside the app bar, bookmark fills', (
    t,
  ) async {
    await pump(t, 'bukhari', 1);
    final cell = find.ancestor(
      of: find.bySemanticsLabel('Tambah bookmark'),
      matching: find.byType(IconButton),
    );
    expect(t.getSize(cell).height, 48);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.bySemanticsLabel('Salin hadis'),
      ),
      findsNothing,
    );
    await t.tap(cell);
    await t.pump();
    expect(find.bySemanticsLabel('Hapus bookmark'), findsOneWidget);
  });

  OutlinedButton nav(WidgetTester t, String l) =>
      t.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, l));

  testWidgets('prev/next disabled at both ends, one tap navigates', (t) async {
    await pump(t, 'bukhari', 1);
    expect(nav(t, 'Sebelumnya').onPressed, isNull);
    expect(nav(t, 'Berikutnya').onPressed, isNotNull);
    await t.tap(find.text('Berikutnya'));
    await t.pumpAndSettle();
    expect(find.text('arab2'), findsOneWidget);
    expect(nav(t, 'Berikutnya').onPressed, isNull);
    expect(nav(t, 'Sebelumnya').onPressed, isNotNull);
  });

  testWidgets('book missing from listBooks -> no Jumlah hadis', (t) async {
    repo.books = const [];
    await pump(t, 'bukhari', 1);
    expect(
      find.textContaining('Jumlah hadis', findRichText: true),
      findsNothing,
    );
    expect(find.textContaining('Kitab', findRichText: true), findsOneWidget);
  });

  testWidgets('older load finishing after a newer one changes nothing', (
    t,
  ) async {
    late final HadithDetailController c;
    await t.runAsync(() async {
      // Created here: completers must live in the real-async zone.
      final gate = Completer<void>();
      Get.delete<HadithRepository>(force: true);
      Get.put<HadithRepository>(_GatedBooksRepository(repo, gate));
      c = HadithDetailController(HadithDetailArgs('bukhari', 1));
      Get.put(c); // onInit starts load A in the real-async zone
      await Future<void>.delayed(const Duration(milliseconds: 20)); // A waits
      repo.hadith = [_h('bukhari', 1, arab: 'new')];
      c.load(); // B: books call is not gated
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    final s = c.state.value as UiData<HadithDetailContent>;
    expect(s.value.arab, 'new');
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('hero and action colors use tokens ($mode)', (t) async {
      await pump(t, 'bukhari', 1, mode: mode);
      final colors = t.element(find.byType(HadithDetailView)).nuraColors;
      final scheme = Theme.of(
        t.element(find.byType(HadithDetailView)),
      ).colorScheme;
      final hero = t.widget<DecoratedBox>(
        find.byKey(const ValueKey('hadith-hero')),
      );
      expect((hero.decoration as BoxDecoration).color, colors.hero);
      final rich = t.widget<RichText>(
        find.descendant(
          of: find.byKey(const ValueKey('hadith-hero')),
          matching: find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText().startsWith('Kitab'),
          ),
        ),
      );
      final inner = (rich.text as TextSpan).children!.single as TextSpan;
      final spans = inner.children!.cast<TextSpan>();
      expect(spans[0].style?.color, colors.onHero);
      expect(spans[1].style?.color, colors.onHeroAccent);

      NuraIcon icon(String label) => t.widget<NuraIcon>(
        find.descendant(
          of: find.ancestor(
            of: find.bySemanticsLabel(label),
            matching: find.byType(IconButton),
          ),
          matching: find.byType(NuraIcon),
        ),
      );
      expect(icon('Salin hadis').color, colors.iconAccent);
      final off = icon('Tambah bookmark');
      expect(off.filled, isFalse);
      expect(off.color, colors.iconAccent);
      await t.tap(find.bySemanticsLabel('Tambah bookmark'));
      await t.pump();
      final on = icon('Hapus bookmark');
      expect(on.filled, isTrue);
      expect(on.color, scheme.primary);
      expect(NuraIcons.bookmark, isNotNull);
    });
  }

  testWidgets('copy and bookmark cells have equal width', (t) async {
    await pump(t, 'bukhari', 1);
    Size cell(String l) => t.getSize(
      find.ancestor(
        of: find.bySemanticsLabel(l),
        matching: find.byType(IconButton),
      ),
    );
    expect(cell('Salin hadis').width, cell('Tambah bookmark').width);
  });

  testWidgets('Bukhari No. 3 from data-source scrolls, no overflow, 130%', (
    t,
  ) async {
    final list =
        jsonDecode(File('data-source/hadith/bukhari.json').readAsStringSync())
            as List;
    final arab =
        (list.firstWhere((e) => e['number'] == 3) as Map)['arab'] as String;
    repo.hadith = [_h('bukhari', 3, arab: arab)];
    user.prefs = const ReadingPrefs(arabicFontSize: 40, showTranslation: true);
    await pump(t, 'bukhari', 3, scale: 1.3);
    expect(t.takeException(), isNull);
    expect(find.text(arab), findsOneWidget);
    final p = t.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(p.maxScrollExtent, greaterThan(0));
    p.jumpTo(p.maxScrollExtent);
    await t.pump();
    expect(t.takeException(), isNull);
  });
}

/// Delegates to [inner]; the first listBooks call waits for [gate].
class _GatedBooksRepository extends FakeHadithRepository {
  _GatedBooksRepository(this.inner, this.gate);
  final FakeHadithRepository inner;
  final Completer<void> gate;
  int _calls = 0;

  @override
  Future<List<HadithBook>> listBooks() async {
    if (_calls++ == 0) await gate.future;
    return inner.listBooks();
  }

  @override
  Future<Hadith> getHadith(HadithRef ref) async {
    return inner.getHadith(ref);
  }

  @override
  Future<HadithRef?> neighbor(HadithRef ref, {required bool next}) =>
      inner.neighbor(ref, next: next);
}
