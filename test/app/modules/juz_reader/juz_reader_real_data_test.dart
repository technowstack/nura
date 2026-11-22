import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/repositories/isolate_quran_range_repository.dart';
import 'package:nura/app/data/repositories/quran_range_repository.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/sqlite_quran_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/app/modules/juz_reader/controllers/juz_reader_controller.dart';
import 'package:nura/app/modules/juz_reader/juz_args.dart';
import 'package:nura/app/modules/juz_reader/juz_item.dart';

import '../../../support/fake_repositories.dart';

/// Null when assets/db/content.db exists (see tool/prepare_content.sh).
final String? _noDb = File('assets/db/content.db').existsSync()
    ? null
    : 'run tool/prepare_content.sh first';

void main() {
  group('juz reader items with real content.db', skip: _noDb, () {
    late IsolateQuranRangeRepository range;
    late QuranRepository quran;

    setUp(() async {
      Get.reset();
      final file = File('assets/db/content.db');
      quran = SqliteQuranRepository(ContentDatabase.open(file));
      range = await IsolateQuranRangeRepository.start(file);
      Get.put<QuranRepository>(quran);
      Get.put<QuranRangeRepository>(range);
      Get.put<UserRepository>(FakeUserRepository());
    });
    tearDown(() async {
      Get.reset();
      await range.close();
    });

    Future<List<JuzItem>> items(int juz) async {
      final c = Get.put(JuzReaderController(JuzArgs(juz)));
      await c.load();
      final s = c.state.value;
      expect(s, isA<UiData<List<JuzItem>>>());
      return (s as UiData<List<JuzItem>>).value;
    }

    List<SurahHeaderItem> headers(List<JuzItem> l) =>
        l.whereType<SurahHeaderItem>().toList();
    List<Ayah> ayat(List<JuzItem> l) => [
      for (final i in l)
        if (i is AyahItem) i.ayah,
    ];

    test('juz 1: Al-Fatihah without Basmalah, Al-Baqarah with it', () async {
      final l = await items(1);
      final h = headers(l);
      expect(h.map((e) => e.surah.nameLatin), ['Al-Fatihah', 'Al-Baqarah']);
      expect(h.map((e) => e.withBasmalah), [false, true]);
      final a = ayat(l);
      expect(a, hasLength(7 + 141));
      expect((a.first.surahNumber, a.first.ayahNumber), (1, 1));
      expect((a.last.surahNumber, a.last.ayahNumber), (2, 141));
      expect(l.first, isA<SurahHeaderItem>());
      expect(l[8], isA<SurahHeaderItem>()); // after the 7 ayat of Al-Fatihah
    });

    test('juz 2 starts mid-surah: one header, no Basmalah', () async {
      final l = await items(2);
      final h = headers(l);
      expect(h, hasLength(1));
      expect(h.single.surah.number, 2);
      expect(h.single.withBasmalah, isFalse);
      final a = ayat(l);
      expect(a.first.ayahNumber, 142);
      expect((a.last.surahNumber, a.last.ayahNumber), (2, 252));
      expect(a, hasLength(252 - 142 + 1));
    });

    test('juz 15: Al-Isra with Basmalah, then Al-Kahf', () async {
      final l = await items(15);
      final h = headers(l);
      expect(h.first.surah.number, 17);
      expect(h.first.withBasmalah, isTrue);
      expect(h.map((e) => e.surah.number), [17, 18]);
      expect(h.last.withBasmalah, isTrue); // 18:1 is in the list
      final a = ayat(l);
      expect((a.last.surahNumber, a.last.ayahNumber), (18, 74));
    });

    test('juz 30: many consecutive headers', () async {
      final l = await items(30);
      final h = headers(l);
      expect(h.first.surah.number, 78);
      expect(h.last.surah.number, 114);
      expect(h, hasLength(37));
      expect(h.every((e) => e.withBasmalah), isTrue);
    });

    test('At-Taubah never gets a Basmalah', () async {
      final l = await items(10); // 8:41 - 9:92 includes 9:1
      final taubah = headers(l).singleWhere((h) => h.surah.number == 9);
      expect(taubah.withBasmalah, isFalse);
      Get.delete<JuzReaderController>();
      final mid = headers(await items(11)).first; // starts 9:93, mid-surah
      expect(mid.surah.number, 9);
      expect(mid.withBasmalah, isFalse);
    });

    test('ayah items equal the range size for every juz, 6236 total', () async {
      var total = 0;
      for (final j in quran.listJuz()) {
        final l = await items(j.number);
        final n = ayat(l).length;
        expect(n, (await range.getAyahRange(j.start, j.end)).length);
        total += n;
        Get.delete<JuzReaderController>();
      }
      expect(total, 6236);
    });
  });
}
