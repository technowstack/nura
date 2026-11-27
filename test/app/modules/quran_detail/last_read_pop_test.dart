import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/surah.dart';
import 'package:nura/app/data/repositories/quran_repository.dart';
import 'package:nura/app/data/repositories/hadith_repository.dart';
import 'package:nura/app/data/repositories/user_repository.dart';
import 'package:nura/app/modules/quran_detail/bindings/quran_detail_binding.dart';
import 'package:nura/app/modules/quran_detail/views/quran_detail_view.dart';
import 'package:nura/app/modules/quran_list/bindings/quran_list_binding.dart';
import 'package:nura/app/modules/quran_list/controllers/quran_list_controller.dart';
import 'package:nura/app/modules/quran_list/views/quran_list_view.dart';
import 'package:nura/app/routes/app_routes.dart';

import '../../../support/fake_repositories.dart';

void main() {
  late FakeUserRepository user;

  setUp(() {
    Get.reset();
    Get.put<QuranRepository>(
      FakeQuranRepository(
        surahs: const [
          Surah(
            number: 1,
            nameArab: 'A1',
            nameLatin: 'L1',
            nameId: 'T1',
            ayahCount: 40,
            revelation: 'makkiyah',
          ),
        ],
        ayahs: [
          for (var i = 1; i <= 40; i++)
            Ayah(
              surahNumber: 1,
              ayahNumber: i,
              arab: 'arab$i',
              translation: 'trans$i',
              tafsir: 't',
            ),
        ],
      ),
    );
    user = FakeUserRepository();
    Get.put<UserRepository>(user);
    Get.put<HadithRepository>(FakeHadithRepository());
    QuranListBinding().dependencies();
  });
  tearDown(Get.reset);

  testWidgets('a mark shows in the surah list after going back', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(body: QuranListView()),
        getPages: [
          GetPage(
            name: Routes.surah,
            page: QuranDetailView.new,
            binding: QuranDetailBinding(),
          ),
        ],
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('L1'));
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Tandai terakhir dibaca').first);
    await t.pumpAndSettle();
    expect(user.lastReadWrites, hasLength(1));

    Get.back<void>();
    await t.pumpAndSettle();
    expect(Get.find<QuranListController>().lastReadSurah.value, 1);
  });
}
