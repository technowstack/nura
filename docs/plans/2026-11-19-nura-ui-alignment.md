# Nura Penyelarasan UI Putaran 1.5: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menyelaraskan UI aplikasi dengan handoff desain Putaran 1.5 (`docs/design/`): token, font Arab (sumber bisa diganti), ikon Material Symbols, komponen dasar, lalu layar Daftar, Baca Surah, Pencarian, Bookmark, Beranda hero, dan widget layar depan.

**Architecture:** Fondasi dulu (token, font, ikon, Hijriah, komponen) agar layar hanya merakit komponen. Font Arab dan ikon masing-masing punya satu titik penggantian (`arabic_font.dart`, `nura_icons.dart`). Penanda akhir ayat dibuat di lapisan tampilan (fungsi murni), tidak menyentuh teks data. Beranda dipecah dua: tampilan hero statis dengan keadaan kosong jujur, lalu data waktu sholat dan hitung mundur.

**Tech Stack:** Flutter, GetX, `material_symbols_icons` (baru), `hijri` (baru), font Scheherazade New (berkas aset, OFL).

**Spec:** `docs/design/2026-11-17-nura-penyegaran-visual.md` (arah dan token), `docs/design/HANDOFF-flutter.md` (pemetaan, komponen, aturan teknis), `docs/design/2026-11-09-nura-ui-design-brief.md`, `docs/design/tokens.json` (sumber nilai), gambar acuan `docs/design/screenshots/` (Beranda, 06a, 07a, 07b, 07c, 10a, 11a; Light dan Dark), audit `docs/review/ui-audit.md` (UA-1 sampai UA-9), PRD 5.1 dan spec 5.4/5.6 (aturan ۝). Baca juga `AGENTS.md`.

## Global Constraints

- Kode Inggris, teks pengguna Indonesia. Tanpa `ignore_for_file`. Hindari `!`. `flutter analyze` bersih dan `flutter test` lulus sebelum tiap commit. Satu topik per commit (Conventional Commits Inggris). Jangan merge, jangan push.
- Nilai warna, ukuran, dan jarak **hanya dari `docs/design/tokens.json`** (Light dan Dark); tidak ada nilai buatan sendiri. Teks Arab dari data tidak diubah (Aturan Mutlak 3); penanda ۝ hanya di lapisan tampilan.
- Tidak ada perubahan skema `content.db`/`user.db`, `data-source/`, atau pemanggilan jaringan baru. Paket baru hanya `material_symbols_icons` dan `hijri` (disetujui pemilik); paket lain perlu persetujuan. Tidak ada `Icons.*` baru.
- Tidak ada teks UI baru kecuali yang tertulis di task; setiap teks baru dikumpulkan di laporan akhir.
- Setiap layar tetap menangani loading, kosong, dan error; target sentuh ≥ 48 dp; skala teks 130% pada 360×640 tanpa overflow; tes yang ada tidak boleh dilemahkan (diubah hanya bila perilaku memang berubah, dan alasannya dicatat).
- Acuan visual: tiap task membuka gambar desain yang disebut di task (Read menampilkan gambar) dan mencocokkan struktur, warna token, dan urutan elemen. Test widget memeriksa struktur dan nilai token. Golden test tidak dipakai (font uji berbeda antar mesin dan hasilnya tidak stabil); pemilik menguji visual di perangkat di akhir.

## Keputusan pemilik (2026-11-19) dan keputusan saya

| ID | Keputusan |
|---|---|
| K1 | Tidak ada screenshot perbandingan per task; pemilik menguji di perangkat di akhir. Dipakai: test widget dan perbandingan dengan gambar di `docs/design/screenshots/` |
| K2 | Font Arab: sumber font bisa diganti di satu tempat (`lib/app/core/theme/arabic_font.dart`). Cadangan OFL: **Scheherazade New** (alasan K6). LPMQ tetap menunggu Q6; menggantinya cukup mengubah satu konstanta, daftar font di `pubspec.yaml`, dan aset |
| K3 | Ikon: **`material_symbols_icons`** (Apache 2.0, versi 4.2960.0, hanya bergantung pada Flutter SDK). Tree-shaking hidup selama ikon dirujuk sebagai konstanta `Symbols.<nama>_rounded` (jangan impor `get.dart` atau `symbols_map.dart`); bobot 300 lewat parameter `weight` pada `Icon`. Diverifikasi di build rilis (Task 3) |
| K4 | Tanggal Hijriah offline: paket **`hijri`** (BSD, tanpa dependensi, tabel Umm al-Qura), alasan: teruji dan banyak dipakai, tanpa jaringan. Nama bulan Indonesia dibuat sendiri (paket hanya Inggris/Arab). Setelan `hijri_adjust` −1/0/+1 (default 0) disediakan sekarang; tempatnya di layar Pengaturan menyusul di Fase 8 |
| K5 | Audio di bilah aksi (keputusan saya, ditinjau pemilik di akhir): sel putar tetap ada di bilah 5 sel dan hilang saat audio mati (sesuai desain). "Putar dari sini" pindah ke menu ⋯ kartu ayat. "Putar surah" dan kontrol surah tidak berubah tempat. Sel hanya ikon dengan tooltip dan label semantik yang sudah disetujui ("Putar ayat", "Jeda", "Butuh internet"); teks status di bawah ikon dari mockup tidak dibuat. Bilah dibangun dari daftar sel sehingga komposisi mudah diubah. Alternatif: (a) "Putar dari sini" sebagai sel keenam (menyimpang dari desain 5 sel); (b) tekan lama pada sel putar |
| K6 | **Scheherazade New dipilih** setelah memeriksa cakupan glyph terhadap seluruh teks Quran di `data-source/` (87 titik kode, termasuk tanda waqaf U+06D6–U+06DC, ۝ U+06DD, U+08D6): Scheherazade New mencakup semuanya; Amiri Quran tidak memuat U+08D6, U+06D4, U+06D5, U+0608, U+0609. OFL 1.1, berkas OFL disertakan di `assets/fonts/ScheherazadeNew/`. Sumber unduhan: repo `google/fonts` (`ofl/scheherazadenew`), 2026-11-19 |
| K7 | "Bagikan" (sel ke-4 desain) tidak dibuat: butuh paket berbagi (mis. `share_plus`), yaitu paket baru di luar yang disetujui. Dilaporkan sebagai keputusan untuk pemilik |
| K8 | Hijriah berganti pada tengah malam (bukan Maghrib); penyesuaian −1/0/+1 menutup selisih. Dicatat di STATUS |

## Review Focus

1. **Penanda ۝ dan teks asli**: ayat berspasi di ujung, ayat satu kata, nomor ayat 1–286 (Arab-Indik), nomor tiga digit; teks sumber tidak boleh berubah (tes byte), `U+00A0` tepat satu, ۝ tidak jatuh sendirian pada Arab 36 (Task 2, 7).
2. **Penggantian font/ikon satu titik**: tidak ada nama font atau `Icons.*` yang tersebar di luar file penggantinya; build rilis tetap tree-shaken dan ukuran APK tidak melonjak (Task 2, 3).
3. **Hijriah**: penyesuaian di batas bulan dan tahun, nilai setelan rusak atau di luar −1..1 jatuh ke 0, bulan 29/30 hari, jam lokal larut malam (Task 4).
4. **Keadaan kosong Beranda**: jadwal belum ada, wilayah belum dipilih, internet mati, jadwal perkiraan (label "perkiraan"), pergantian hari saat layar terbuka, jam berganti tanpa membangun ulang seluruh Beranda (Task 9, 10).
5. **Regresi fungsi**: bookmark, last read, audio (putar, jeda, putar dari sini, butuh internet), tafsir, salin, pencarian dan sorotan tidak berubah perilakunya saat gaya berganti; teks Arab 36 dan skala 130% tanpa overflow (Task 5–8).

---

### Task 1 (UA-1): Token Putaran 1.5 dan tema

**Files:** Modify `lib/app/core/theme/nura_colors.dart`, `app_theme.dart`, `tokens.dart`, `nura_text_styles.dart`; Test `test/app/core/theme/tokens_round15_test.dart`.

**Interfaces:** Produces: `NuraColors.{hero,heroShape,onHero,onHeroAccent,iconAccent}` (light dan dark), `ColorScheme.surfaceContainerLowest` terisi di kedua tema, `NuraSpace.s36 = 36`, `NuraTextStyles.arabicHero` (ukuran 40, tinggi baris 56, keluarga `nuraArabicFont`), semuanya dengan `copyWith`/`lerp` lengkap.

- [ ] **Step 1: Write the failing test** yang memuat `docs/design/tokens.json` dan membandingkan: tiap warna baru (Light dan Dark) dan `surfaceContainerLowest` persis dengan token; `s36`; `arabicHero` 40/56; `lerp(0)`/`lerp(1)` mengembalikan ujungnya; `copyWith` tanpa argumen menyamai asal.
- [ ] **Step 2: Run, expect FAIL. Step 3: Implement** (nilai dari tokens.json). **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat: add round 1.5 design tokens`.

### Task 2 (UA-2): Font Arab bisa diganti dan penanda akhir ayat

**Files:** Create `lib/app/core/theme/arabic_font.dart`, `lib/app/core/ayah_marker.dart`, `assets/fonts/ScheherazadeNew/{ScheherazadeNew-Regular.ttf,OFL.txt}` (sudah diunduh ke `$HOME/.cache/nura-tmp/fonts/`: `ScheherazadeNew-Regular.ttf` dan `OFL-scheh.txt` = OFL-nya); Modify `pubspec.yaml` (daftar font dan aset OFL), `nura_text_styles.dart` (hapus konstanta lama), `docs/STATUS.md` (alasan dan cara kembali ke LPMQ setelah Q6); Test `test/app/core/arabic_font_test.dart`, `ayah_marker_test.dart`.

**Interfaces:** Produces: `const String nuraArabicFont = 'Scheherazade New';` (satu-satunya tempat nama font Arab; komentar menjelaskan penggantian ke LPMQ). `String ayahDisplayText(String arab, int ayahNumber)` = `arab` tanpa spasi ASCII (`U+0020`) di ujung + ` ` + `۝` + angka Arab-Indik (`U+0660`–`U+0669`) nomor ayat. `String toArabicIndic(int n)`.

- [ ] **Step 1: Write failing tests**: (a) `ayahDisplayText('قُلْ ', 3)` persis `'قُلْ ۝٣'`; tanpa spasi ujung hasilnya sama; nomor 10 → `١٠`, 286 → `٢٨٦`; string input tidak berubah; tepat satu `U+00A0`; ayat satu kata; (b) tidak ada literal nama font Arab di `lib/` selain `arabic_font.dart`, `pubspec.yaml` mendaftarkan keluarga yang sama dengan konstanta, dan berkas aset ada; (c) cakupan: setiap titik kode non-ASCII pada seluruh ayat dan nama surah di `data-source/quran/*.json` (dibaca langsung) ada di cmap font aset; pembaca cmap sederhana ditulis di tes (tanpa paket baru).
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: add replaceable arabic font and ayah end marker`.

### Task 3 (UA-3a): Ikon Material Symbols

**Files:** Modify `pubspec.yaml` (`material_symbols_icons: ^4.2960.0`), semua berkas `lib/` yang memakai `Icons.` (cari dengan grep); Create `lib/app/core/nura_icons.dart`; Test `test/app/core/nura_icons_test.dart`.

**Interfaces:** Produces: `abstract final class NuraIcons` berisi konstanta `IconData` (dari `Symbols.<nama>_rounded`) untuk setiap ikon yang dipakai aplikasi sekarang, ditambah `moreHoriz`, `history`, `locationOn`, `chevronRight`, `contentCopy`, `search`. Widget `NuraIcon(IconData icon, {double size = 24, Color? color, bool filled = false, String? semanticLabel})` membungkus `Icon` dengan `weight: 300`, `fill: filled ? 1 : 0`.

- [ ] **Step 1: Write failing tests**: (a) memindai `lib/`: gagal bila ada `Icons.` dan bila ada impor `material_symbols_icons/get.dart` atau `symbols_map.dart`; (b) `NuraIcon` merender `Icon` dengan weight 300 dan fill sesuai; (c) tes widget yang mencari `Icons.x` diubah ke `NuraIcons.x`.
- [ ] **Step 2–4: Run fail, ganti semua `Icons.*` ke `NuraIcons`/`NuraIcon` secara mekanis (perilaku dan semantik tidak berubah), run pass.**
- [ ] **Step 5: Verifikasi tree-shaking:** `flutter build apk --release` (dengan `TMPDIR=$HOME/.cache/nura-tmp`); catat dari log baris tree-shaken font ikon (ukuran sebelum dan sesudah) dan ukuran APK; font ikon harus jauh lebih kecil dari ukuran penuh. Jika tidak ter-shake, berhenti dan laporkan.
- [ ] **Step 6: Commit** `feat: switch to material symbols rounded icons`.

### Task 4: Tanggal Hijriah offline dan setelan penyesuaian

**Files:** Modify `pubspec.yaml` (`hijri`), `lib/app/data/sources/setting_keys.dart` (`hijriAdjust = 'hijri_adjust'`), `lib/app/app_bootstrap.dart` (registrasi); Create `lib/app/services/hijri_date_service.dart`; Test `test/app/services/hijri_date_service_test.dart`.

**Interfaces:** Produces: `class HijriDateService { HijriDateService({required UserDatabase user}); int get adjustDays; set adjustDays(int v) /* clamp −1..1, disimpan sebagai string */; String format(DateTime gregorianLocal); }`. `format` memakai `HijriCalendar.fromDate` pada tanggal lokal (tanpa jam) setelah menambah `adjustDays` hari; keluaran "`D NamaBulan YYYY H`" dengan nama bulan Indonesia: Muharram, Safar, Rabiulawal, Rabiulakhir, Jumadilawal, Jumadilakhir, Rajab, Syakban, Ramadhan, Syawal, Zulkaidah, Zulhijah. Nilai setelan tidak valid (non-angka, di luar −1..1) dibaca sebagai 0.

- [ ] **Step 1: Write failing tests** (basis data dalam memori seperti tes lain): default 0; set 1 dan −1 tersimpan, set 5 menjadi 1 dan −9 menjadi −1; nilai rusak "abc" → 0; `format` dengan adjust +1 sama dengan `format` untuk besok dengan adjust 0, dan −1 sama dengan kemarin; sepanjang satu tahun Masehi penuh tidak pernah melempar dan hari ∈ 1..30; 12 nama bulan unik; pergantian Zulhijah→Muharram; 23:59 dan 00:01 pada tanggal yang sama menghasilkan hari yang sama.
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: add offline hijri date with day adjustment`.

### Task 5 (UA-3b): Komponen dasar

**Files:** Create `lib/app/core/widgets/ornament_badge.dart`, `lib/app/core/widgets/nura_card.dart`; Modify `lib/app/modules/quran_detail/widgets/ayah_action_bar.dart` (ditulis ulang), hapus `ayah_number_badge.dart` bila tidak lagi dipakai; Test `test/app/core/widgets/ornament_badge_test.dart`, `nura_card_test.dart`, `test/app/modules/quran_detail/ayah_action_bar_test.dart`.

**Interfaces:** Produces: `OrnamentBadge({required String label, double size = NuraSpace.s36})` (bintang delapan garis tipis `iconAccent` berisi `label`); `NuraCard({required Widget child, Color? color, EdgeInsetsGeometry padding, VoidCallback? onTap})` (`surfaceContainerLowest`, border `outlineVariant` 1 px, radius `lg`, area ketuk ≥ 48 bila `onTap`); `AyahActionBar` dengan konstruktor sekarang **tanpa** `onPlayFromHere` (pindah ke `AyahCard`, Task 7), dibangun dari daftar sel: salin, bookmark, putar (hilang bila `audio == hidden`), tafsir; sel sama lebar (`Expanded`), tinggi 48, latar `surfaceContainerLow`, radius `md`, ikon `iconAccent` (bookmark terisi `primary` bila `bookmarked`); tooltip dan semantik persis yang sekarang.

- [ ] **Step 1: Write failing tests**: `OrnamentBadge` 36 dan memuat label; `NuraCard` memakai warna, border, dan radius token (Light dan Dark), area ketuk ≥ 48; `AyahActionBar`: empat sel sama lebar saat audio tampil, tiga saat `hidden`, tinggi 48, setiap keadaan audio (loading, needsInternet disabled, ready, playing, paused) memicu callback atau nonaktif seperti sekarang, label "Putar ayat"/"Jeda"/"Butuh internet" tetap, bookmark terisi berubah; 130% tanpa overflow.
- [ ] **Step 2–4: Run fail, implement, run pass** (tes AyahCard yang bergantung bilah lama disesuaikan sementara; "putar dari sini" dikerjakan di Task 7). **Step 5: Commit** `feat: add ornament badge, card and 5-cell ayah action bar`.

### Task 6 (UA-4): Daftar Al-Qur'an

**Files:** Modify `lib/app/modules/quran_list/widgets/surah_list_item.dart`, `juz_list_item.dart`, `views/quran_list_view.dart` (tab); Test tes yang ada di `test/app/modules/quran_list/`.

**Interfaces:** Consumes: `OrnamentBadge`, `NuraCard`, `NuraIcons`, token. Produces: `SurahListItem` = `NuraCard`: kiri `OrnamentBadge(label: nomor)`, tengah nama Latin (titleMedium) dan "Arti · [Q4] · N ayat" (teks yang sudah ada), kanan nama Arab dari field data dengan `arabicTitle` warna `iconAccent`; keadaan Default/Bookmarked/Terakhir dibaca tetap (latar `lastReadHighlight` + ikon `history`, ikon bookmark); `JuzListItem` selaras (badge, "Juz [Q4]", rentang "[Q4]", chevron); tab aktif bergaris bawah `primary` 2 px.

- [ ] **Step 1: Write failing tests** (struktur dan token; nama Arab diambil dari data; tiga keadaan; ketuk tetap membuka surah; 130% dan Arab 36 tanpa overflow). Acuan: `t15c-06a-light.png`, `t15c-06a-dark.png`.
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: restyle surah and juz list items`.

### Task 7 (UA-5): Baca Surah

**Files:** Modify `lib/app/modules/quran_detail/widgets/surah_header_card.dart`, `bismillah_header.dart`, `ayah_card.dart`, `views/quran_detail_view.dart`; Test tes yang ada di `test/app/modules/quran_detail/`.

**Interfaces:** Consumes: Task 1–5, `ayahDisplayText`. Produces: `SurahHeaderCard` kartu `ext/hero` (info kiri: label `onHero`, nilai `onHeroAccent`; nama Arab `arabicHero` kanan; "Tempat turun [Q4]" tetap placeholder), Basmalah di `NuraCard` terpisah di bawahnya (teks dari data ayat 1 Al-Fatihah; tidak untuk At-Taubah dan Al-Fatihah); `AyahCard` = `NuraCard` berisi baris atas (nomor kecil `iconAccent` kiri; menu ⋯ `NuraIcons.moreHoriz` kanan, area sentuh 48, membuka `PopupMenuButton` dengan item "Putar dari sini" (hanya bila audio tidak `hidden`; nonaktif bila butuh internet atau memuat; teks dan label yang sudah ada)), teks Arab rata kanan dari `ayahDisplayText(ayah.arab, ayah.ayahNumber)` dengan `arabicReading` dan ukuran pilihan pengguna, terjemahan (tetap bisa disembunyikan), garis `outlineVariant`, `AyahActionBar`; keadaan Terakhir dibaca (latar `lastReadHighlight`, label "Terakhir dibaca" + ikon `history`) dan Bookmarked tetap.

- [ ] **Step 1: Write failing tests**: teks Arab tampil persis `ayahDisplayText(...)`, satu penanda, data tidak berubah; Arab 20/28/36 tanpa overflow; menu ⋯ berisi "Putar dari sini" sesuai keadaan audio dan memanggil `onPlayFromHere`; bookmark/salin/tafsir/audio berfungsi seperti sebelumnya; header Al-Fatihah dan At-Taubah tanpa Basmalah terpisah; Arab 36 + skala 130%. Acuan: `t15c-07a/07b/07c-*.png`.
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: restyle surah reading screen` (boleh dua commit: header, kartu ayat).

### Task 8 (UA-6): Pencarian dan Bookmark

**Files:** Modify `lib/app/modules/search/widgets/search_result_tile.dart`, `views/search_view.dart`, `lib/app/modules/quran_list/widgets/bookmark_tile.dart`, `bookmarks_tab.dart`; Test tes yang ada.

**Interfaces:** Consumes: `NuraCard`, `NuraIcons`, `ayahDisplayText`. Produces: hasil dan bookmark memakai `NuraCard`, ikon `iconAccent`; cuplikan terjemahan dan sorotan (spec 5.5) tidak berubah; teks Arab hasil memakai penanda ۝ bila menampilkan ayat penuh.

- [ ] **Step 1: Write failing tests**: gaya kartu token; cuplikan dan sorotan tetap persis (kasus spec 5.5: Al-Baqarah 45, 153, Ali 'Imran 146, An-Nahl 42); ۝ tidak jatuh sendiri pada hasil Arab. Acuan: `t15c-10a-*.png`, `t15c-11a-*.png`.
- [ ] **Step 2–4: fail, implement, pass. Step 5: Commit** `feat: restyle search results and bookmarks`.

### Task 9 (UA-7a): Beranda hero, tampilan statis

**Files:** Create `lib/app/modules/home/widgets/home_hero.dart`, `hero_silhouette.dart`, `last_read_card.dart`, `home_hero_data.dart`; Modify `lib/app/modules/home/home_view.dart`, `home_controller.dart`; Test `test/app/modules/home/`.

**Interfaces:** Produces: `HomeHeroData({String locationLabel, String hijriDate, String clock, String? countdownText, List<HeroPrayerTime> times, int? nextIndex, bool approximate})` dan `HeroPrayerTime({String name, String time, IconData icon})`; `HomeHero(data)` = hero full-bleed `ext/hero` (±360 termasuk status bar): baris atas (chip lokasi dengan ikon pin + ikon cari yang membuka rute pencarian), tanggal Hijriah (dari `HijriDateService`), jam besar `onHero`, `countdownText`, baris 6 waktu, siluet datar `heroShape` (CustomPainter, tanpa gradasi), label "perkiraan" bila `approximate`; lembar konten `surface` menumpuk 24 px dengan sudut atas radius `xl`; di dalamnya `LastReadCard` (dari repository last read yang ada: nama surah Arab kecil, "QS. Nama: ayat", tombol "Lanjutkan" membuka surah di ayat itu; keadaan kosong bila belum ada), `DailyAyahCard`, `DailyHadithCard` (gaya `NuraCard`; ornamen bintang tipis hanya di kartu Ayat). `NextPrayerCard` tidak dipasang. **Versi statis tidak menampilkan data sholat palsu** (Aturan Mutlak 6): `times` kosong menampilkan keadaan kosong jujur (teks yang sudah ada di layar Sholat untuk jadwal belum tersedia atau belum memilih lokasi) dan jam memakai jam perangkat; data jadwal dan hitung mundur masuk Task 10. Ikon header `tune` (pengaturan harian) dipertahankan sampai Fase 8, di tempat yang tidak mengganggu desain.

- [ ] **Step 1: Write failing tests**: hero memakai token (`hero`, `onHero`, `onHeroAccent`, `heroShape`), lembar 24 px dengan radius `xl`; enam waktu tampil bila `times` terisi dan waktu berikutnya = warna `onHeroAccent` **plus titik**; `times` kosong tanpa angka palsu; last read kosong dan terisi; tanggal Hijriah mengikuti setelan penyesuaian; ketuk "Lanjutkan" dan ikon cari menavigasi; skala 130% pada 360×640 tanpa overflow dan hero menggulir bersama lembar; kartu harian tetap membuka sumbernya. Acuan: `t15b-05-Beranda-Light.png`, `t15b-05-Beranda-Dark.png`.
- [ ] **Step 2–4: fail, implement, pass. Step 5: Commit** `feat: add static home hero layout`.

### Task 10 (UA-7b): Beranda hero hidup: waktu sholat dan hitung mundur

**Files:** Modify `lib/app/modules/home/home_controller.dart`, `widgets/home_hero.dart`; Create `lib/app/modules/home/hero_data_builder.dart`; Test `test/app/modules/home/hero_data_builder_test.dart`, `home_controller_test.dart`.

**Interfaces:** Consumes: `PrayerRepository`, `PrayerClock`, wilayah terpilih (seperti `PrayerController`), `HijriDateService`. Produces: `HomeHeroData buildHeroData({required PrayerDay? today, required PrayerDay? tomorrow, required DateTime now, required String? regionLabel, required String hijri})` (fungsi murni): enam waktu (Subuh, Terbit, Dzuhur, Ashar, Maghrib, Isya), `nextIndex`, `countdownText` ("Maghrib dalam 27 menit" atau "dalam 1 jam 5 menit"; setelah Isya → Subuh besok), `approximate` bila sumber jadwal bukan API; pembaruan per menit lewat `Timer.periodic` di controller yang dibatalkan di `onClose`, hanya membangun ulang hero (bukan seluruh Beranda), dan menyegarkan data saat hari berganti atau aplikasi kembali ke latar depan.

- [ ] **Step 1: Write failing tests** (fungsi murni, jam tetap): sebelum Subuh, di antara waktu, tepat pada waktu, setelah Isya (menunjuk Subuh besok), jadwal besok tidak ada, wilayah belum dipilih, jadwal kosong, sumber perkiraan; teks hitung mundur menit/jam; pergantian hari di tengah malam; controller membatalkan timer saat ditutup dan tidak memanggil jaringan baru; `home_view_test` memakai jam tetap.
- [ ] **Step 2–4: fail, implement, pass. Step 5: Commit** `feat: add prayer times and countdown to home hero`.

### Task 11 (UA-8): Widget layar depan

**Files:** Modify `lib/app/core/widgets/daily_widget_image.dart`; Test `test/app/core/widgets/daily_widget_image_test.dart`.

**Interfaces:** Produces: komposisi gambar widget mengikuti bahasa baru: kartu terang (`surfaceContainerLowest`), nama surah Arab (`arabicTitle`, `iconAccent`) untuk Ayat, label `iconAccent`; tetap tanpa tombol, satu area ketuk, teks dipotong elipsis, tidak overflow pada tinggi kurang (regresi Fase 6: strut dan flex tetap).

- [ ] **Step 1: Write failing tests**: nama Arab muncul untuk Ayat dan tidak untuk Hadis; warna token Light dan Dark; tes `layout never overflows when it gets less height` tetap lulus; teks panjang terpotong. **Step 2–4. Step 5: Commit** `feat: restyle daily widget image`.

### Task 12 (UA-9): Penyelesaian dan checklist uji perangkat

**Files:** `docs/STATUS.md`, `docs/review/ui-audit.md` (status tiap butir), `docs/design/HANDOFF-flutter.md` hanya bila ada catatan penyimpangan.

- [ ] **Step 1:** `flutter analyze` bersih, `flutter test` lulus, `flutter build apk --debug` berhasil; `flutter build apk --release` (verifikasi tree-shaking ikon, ukuran APK dicatat).
- [ ] **Step 2:** Perbarui STATUS: keputusan K1–K8, paket baru (nama, lisensi, alasan), penyimpangan dari desain (K5 audio, K7 bagikan, teks status sel audio, font Scheherazade sementara sampai Q6), daftar teks UI baru bila ada, dan checklist uji perangkat (Beranda hero Light dan Dark, jam dan hitung mundur berganti, label perkiraan, keadaan tanpa wilayah; daftar surah dan juz; baca surah Arab 20/28/36, penanda ۝ tidak putus, tanda waqaf tampil, menu ⋯ dan "Putar dari sini", bilah aksi; pencarian dan bookmark; widget hadis dan ayat; ikon; tema gelap; teks 130%; penyesuaian Hijriah; build rilis).
- [ ] **Step 3: Commit** `docs: update status after ui alignment`.

## Cakupan audit

| Audit | Task |
|---|---|
| F1 token | 1 |
| F2 font, penanda ۝ | 2 |
| F4 ikon | 3 |
| Tanggal Hijriah (pertanyaan 4) | 4 |
| F5, F3 komponen dan kartu | 5 |
| UA-4 daftar | 6 |
| UA-5 baca surah | 7 |
| UA-6 pencarian dan bookmark | 8 |
| UA-7 Beranda | 9, 10 |
| UA-8 widget | 11 |
| UA-9 uji dan checklist | 12 |
