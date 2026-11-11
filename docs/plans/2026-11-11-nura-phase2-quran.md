# Nura Fase 2 (Al-Qur'an Offline): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Al-Qur'an bisa dibaca penuh secara offline: daftar surah dan juz, baca surah, tafsir Kemenag, bookmark, last read, ukuran teks Arab, dan tema, dengan tampilan sesuai desain putaran 1.

**Architecture:** `QuranRepository` (membaca `content.db` read-only) dan `UserRepository` (membaca dan menulis `user.db`) mendaftar sebagai singleton GetX di `bootstrap()`. Setiap layar punya controller GetX dengan `UiState<T>`, dan view hanya menampilkan state. Tema dibangun dari `docs/design/tokens.json`. Bottom navigation empat tab memuat tab Al-Qur'an; tab Hadis dan Sholat masih placeholder.

**Tech Stack:** Flutter, GetX, `sqlite3` (sudah ada). Paket baru hanya `scrollable_positioned_list` (Keputusan 1, menunggu persetujuan).

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (bagian 5.1–5.3, 5.6, 9, 10, 11 Fase 2). Desain: `docs/design/HANDOFF-flutter.md` dan `docs/design/2026-11-09-nura-ui-design-brief.md` (bagian 4, 5 layar 6–9 dan 11). Baca juga `AGENTS.md`.

## Keputusan yang dibutuhkan dari pemilik proyek

Desain dan spec diam atau ambigu pada hal berikut. Plan ini memakai asumsi di kolom kanan. Koreksi sebelum eksekusi bila berbeda.

| # | Hal | Asumsi plan |
|---|---|---|
| 1 | Scroll ke ayat dan pelacakan ayat terlihat butuh paket baru | Pakai `scrollable_positioned_list` (paket flutter.dev, kecil). Dipakai di Task 10 saja |
| 2 | File font tidak ada di repo (Q6) | Pemilik menyediakan file LPMQ Isep Misbah dan Plus Jakarta Sans di `assets/fonts/` beserta teks lisensinya. Task 2 menunggu file itu; task lain tidak bergantung padanya |
| 3 | Pencarian: spec menaruhnya di Fase 4, desain menaruh layarnya di halaman Fase 2 | Pencarian (SearchField dan layar 10) dikerjakan di Fase 4. Fase 2 tidak menampilkan SearchField |
| 4 | Desain tidak menyebut aksi manual untuk Last Read | Otomatis: ayat pertama yang terlihat disimpan saat pengguna meninggalkan layar surah atau aplikasi di-pause |
| 5 | Arti varian `SurahListItem` "Bookmarked" | Ikon bookmark bila surah punya minimal satu ayat ber-bookmark. Bila juga surah terakhir dibaca, state "Terakhir dibaca" yang menang |
| 6 | Desain hanya punya slider ukuran Arab, sakelar terjemahan, dan pilihan tema; PRD 5.1 menyebut ukuran font terjemahan juga | Ikuti desain: ukuran terjemahan tetap. PRD dirapikan di Task 12 |
| 7 | Aksi di `AyahActionBar` | Bookmark, tafsir, dan salin. "Bagikan" butuh `share_plus` dan ditunda. Audio disembunyikan sampai Fase 7. Format salin: teks Arab, baris kosong, terjemahan, baris kosong, `QS. <Nama Latin>: <ayat>` |
| 8 | Navigasi tafsir | "Sebelumnya" dan "Berikutnya" bergerak dalam satu surah, nonaktif di ayat pertama dan terakhir |
| 9 | Query berat di isolate (spec 3.5) | Fase 2 memakai query sinkron: satu surah paling banyak 286 ayat. Isolate dikerjakan di Fase 4 |
| 10 | Data meta belum ada (Q4) | `revelation` kosong: label tempat turun disembunyikan. Tabel `juz` kosong: tab Juz menampilkan keadaan kosong. Tidak perlu kode tambahan saat `juz.json` tersedia |

## Global Constraints

- Branch kerja `feat/phase-2-quran`. Selesai: `merge --no-ff` ke `main` setelah review akhir. Jangan push.
- Tidak mengubah `data-source/`, skema `content.db`, atau `lib/content_pipeline/`. `content.db` hanya dibuka read-only (AGENTS aturan 4).
- Teks Arab, terjemahan, dan tafsir ditampilkan persis seperti di database: tanpa `trim` atau perubahan lain (aturan 3). Tidak ada teks Arab yang diketik di kode atau tes produksi. Basmalah diambil dari ayat 1:1 di database.
- Tidak ada akses jaringan. Tidak ada paket selain `scrollable_positioned_list`.
- Nilai tema bersumber dari `docs/design/tokens.json`. Kode tema di `lib/app/core/theme/`. Font Latin `Plus Jakarta Sans`, font Arab `LPMQ Isep Misbah`. Material 3. Target sentuh minimal 48 × 48. Status tidak hanya dibedakan lewat warna. Tata letak utuh pada Arab 40 dan teks Latin 130%.
- Pola AGENTS.md: view hanya menampilkan state controller; data dimuat di `onInit` atau aksi pengguna, tidak ada future di `build()`; setiap layar menangani loading, kosong, dan error; model immutable; satu class publik per file (model kecil dan hierarki sealed boleh berbagi file); tanpa `!` dan `ignore_for_file`.
- Teks yang dilihat pengguna dalam Bahasa Indonesia. Commit dalam Bahasa Inggris (Conventional Commits). `flutter analyze` bersih dan `flutter test` lulus sebelum setiap commit.
- `flutter test` butuh `assets/db/content.db` lokal (`tool/prepare_content.sh`). Tes memakai fixture (`buildFixtureDb` di `test/support/fixture_db.dart`, `fixtureDir('')` di `test/support/fixtures.dart`), bukan database penuh.

## Review Focus

1. **Surah tanpa Basmalah.** Al-Fatihah (1) dan At-Taubah (9) tidak menampilkan header Bismillah; surah lain menampilkannya, dengan teks dari ayat 1:1. Diuji di Task 7.
2. **Tafsir sangat panjang.** Tafsir terpanjang 19.245 karakter dan 4.371 tafsir berisi baris baru. Sheet harus bisa digulir sampai akhir dan baris baru dipertahankan. Diuji di Task 8.
3. **Ayat sangat panjang.** Arab terpanjang 1.218 karakter dan terjemahan terpanjang 1.670. Dengan Arab 40 dan Latin 130% tidak boleh ada overflow. Diuji di Task 7 dan 9.
4. **Database gagal dibaca.** `ContentUnavailable` harus menjadi `ErrorState` dengan tombol "Coba lagi", bukan crash. Diuji di Task 3, 6, 7.
5. **Bookmark dan Last Read.** Ketuk bookmark berulang tetap konsisten (unik per ayat). Pada peluncuran pertama `last_read` kosong dan tidak ada `null` yang sampai ke UI. Bookmark ke ayat yang tidak ada di database dilewati, tidak crash. Diuji di Task 4, 10, 11.

---

## Struktur File

```
lib/app/
  app_bootstrap.dart                           (ubah: daftarkan repository dan ThemeController)
  nura_app.dart                                (ubah: themeMode reaktif)
  core/
    ui_state.dart                              sealed UiState<T>: Loading, Empty, Data, Error
    errors.dart                                ContentUnavailable
    widgets/empty_state.dart, error_state.dart
    theme/tokens.dart, nura_colors.dart, nura_text_styles.dart, theme_controller.dart
    theme/app_theme.dart, theme_mode_setting.dart   (ubah)
  data/
    models/surah.dart, ayah.dart (Ayah + AyahRef), juz.dart, bookmark.dart, last_read.dart, reading_prefs.dart
    repositories/quran_repository.dart, sqlite_quran_repository.dart,
                 user_repository.dart, sqlite_user_repository.dart
    sources/setting_keys.dart                  (ubah: tambah dua kunci)
  modules/
    shell/{controllers,views,widgets}          BottomNav empat tab
    quran_list/{bindings,controllers,views,widgets}   tab Surah dan Juz
    quran_detail/{bindings,controllers,views,widgets} baca surah, tafsir, pengaturan
    bookmarks/{controllers,views,widgets}      tab Bookmark
  routes/app_routes.dart, app_pages.dart       (ubah)
assets/fonts/                                  (dari pemilik proyek)
test/support/fake_repositories.dart            FakeQuranRepository, FakeUserRepository
```

---

### Task 1: Tema dari token desain

**Files:**
- Create: `lib/app/core/theme/tokens.dart`, `nura_colors.dart`, `nura_text_styles.dart`
- Modify: `lib/app/core/theme/app_theme.dart`
- Test: `test/app/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `AppTheme.light` dan `AppTheme.dark` (`ThemeData`, `useMaterial3: true`) dengan `ColorScheme` berisi 15 peran dari handoff bagian 2 (primary, onPrimary, primaryContainer, onPrimaryContainer, secondary, surface, surfaceContainerLow, surfaceContainer, onSurface, onSurfaceVariant, outline, outlineVariant, error, onError, scrim). `NuraColors extends ThemeExtension<NuraColors>` dengan `arabicText`, `lastReadHighlight`, `searchHighlight`, `ornament`, `offlineBadge`. `NuraTextStyles extends ThemeExtension<NuraTextStyles>` dengan `arabicReading`, `arabicCard`, `arabicTitle`, `arabicReading36`, `translation`. `abstract final class NuraSpace` (`s4, s8, s12, s16, s20, s24, s32, s40, s48`) dan `NuraRadius` (`sm, md, lg, xl, full`). `extension NuraThemeContext on BuildContext { NuraColors get nuraColors; NuraTextStyles get nuraText; }` (jatuh ke nilai Light bila extension tidak terpasang, tanpa `!`).

- [ ] **Step 1: Tulis tes yang gagal.** Tes membaca `docs/design/tokens.json` lalu membandingkan: tiap peran `ColorScheme` dan tiap warna `NuraColors` di Light dan Dark dengan token `color/*` dan `color/ext/*`; `arabicReading.fontSize == 28` dengan `height == 56 / 28`; `translation` 15/24; `titleLarge` 20/28; `fontFamily` Latin `Plus Jakarta Sans` dan Arab `LPMQ Isep Misbah`; `NuraSpace.s48 == 48`, `NuraRadius.lg == 16`. Satu tes lagi: `ThemeData.extension<NuraColors>()` tidak null di kedua tema.
- [ ] **Step 2: Jalankan** `flutter test test/app/core/theme/app_theme_test.dart`. Harapan: GAGAL (class belum ada).
- [ ] **Step 3: Implementasi** sesuai Interfaces. Ambil nilai dari `tokens.json` (format FigCraft: baca strukturnya dulu), bukan dari brief. Tinggi baris Flutter = lineHeight / ukuran. Keadaan disabled memakai default M3.
- [ ] **Step 4: Jalankan tes sampai lulus**, lalu `flutter analyze`.
- [ ] **Step 5: Commit** `feat: apply design tokens to app theme`.

### Task 2: Aset font (prasyarat dari pemilik proyek)

**Files:**
- Modify: `pubspec.yaml` (bagian `flutter.fonts`)
- Create (oleh pemilik proyek): `assets/fonts/` berisi file `Plus Jakarta Sans` (bobot 400, 500, 600), `LPMQ Isep Misbah`, dan teks lisensi masing-masing
- Test: `test/app/core/theme/font_assets_test.dart`

**Interfaces:**
- Produces: family `Plus Jakarta Sans` dan `LPMQ Isep Misbah` terdaftar di `pubspec.yaml`.

- [ ] **Step 1: Periksa prasyarat.** Jika `assets/fonts/` belum berisi file font dan lisensi, BERHENTI dan tanyakan ke pemilik proyek. Jangan mengunduh font sendiri. Task lain tidak bergantung pada Task ini.
- [ ] **Step 2: Tulis tes yang gagal.** Tes membaca `pubspec.yaml` dan memastikan kedua family terdaftar dan setiap file yang dideklarasikan ada di disk.
- [ ] **Step 3: Daftarkan font** di `pubspec.yaml` dengan bobot 400, 500, 600 untuk Latin.
- [ ] **Step 4: Jalankan** `flutter test` penuh, lalu catat sumber dan tanggal unduh font (dari pemilik proyek) di `docs/STATUS.md` bagian Catatan Teknis. Status lisensi tetap Q6.
- [ ] **Step 5: Commit** `build: bundle app fonts`.

### Task 3: Model, UiState, `QuranRepository`

**Files:**
- Create: `lib/app/core/ui_state.dart`, `lib/app/core/errors.dart`, `lib/app/data/models/surah.dart`, `ayah.dart`, `juz.dart`, `lib/app/data/repositories/quran_repository.dart`, `sqlite_quran_repository.dart`
- Modify: `lib/app/app_bootstrap.dart`, `test/app/bootstrap_test.dart`
- Test: `test/app/data/sqlite_quran_repository_test.dart`

**Interfaces:**
- Produces:
  - `sealed class UiState<T>` dengan `UiLoading<T>`, `UiEmpty<T>`, `UiData<T>(T value)`, `UiError<T>(String message)`.
  - `class ContentUnavailable implements Exception { const ContentUnavailable(this.message); final String message; }`
  - `class Surah { number, nameArab, nameLatin, nameId, ayahCount, revelation }`, `class Ayah { surahNumber, ayahNumber, arab, translation, tafsir }`, `class AyahRef { const AyahRef(this.surah, this.ayah); }` (dengan `==` dan `hashCode`), `class Juz { number, startSurah, startAyah, endSurah, endAyah }`. Semua immutable.
  - `abstract interface class QuranRepository { List<Surah> listSurah(); Surah getSurah(int number); List<Ayah> listAyah(int surahNumber); Ayah getAyah(AyahRef ref); List<Juz> listJuz(); }`. Semua melempar `ContentUnavailable` bila baris tidak ada atau `SqliteException`.
  - `class SqliteQuranRepository implements QuranRepository { SqliteQuranRepository(ContentDatabase db); }`
  - `bootstrap()` mendaftarkan `QuranRepository` (`permanent: true`) setelah database terbuka.

- [ ] **Step 1: Tulis tes yang gagal** (fixture dari `buildFixtureDb`):
  - `listSurah()` urut nomor; surah 1 punya `nameLatin == 'Al-Fatihah'`, `nameId == 'Pembukaan'`, `ayahCount == 7`, `revelation == ''`.
  - `listAyah(100)` punya nomor 1..11 berurutan numerik (menjaga "10" tidak sebelum "2").
  - `listAyah(1).first.arab` sama persis dengan `jsonDecode` dari `test/fixtures/data-source/quran/1.json` (`['1']['text']['1']`), begitu juga terjemahan dan tafsir.
  - `getAyah(AyahRef(1, 1))` benar; `getSurah(999)` dan `getAyah(AyahRef(1, 999))` melempar `ContentUnavailable`.
  - `listJuz()` mengembalikan list kosong pada fixture.
  - Database yang sudah ditutup: semua metode melempar `ContentUnavailable`, bukan `SqliteException`.
  - `bootstrap` sukses: `Get.find<QuranRepository>()` tersedia.
- [ ] **Step 2: Jalankan** `flutter test test/app/data/sqlite_quran_repository_test.dart`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces dengan parameter SQL (`?`), tanpa `trim` pada kolom teks.
- [ ] **Step 4: Jalankan tes** repository dan `bootstrap_test` sampai lulus.
- [ ] **Step 5: Commit** `feat: add quran repository over content db`.

### Task 4: `UserRepository` (bookmark, last read, preferensi)

**Files:**
- Create: `lib/app/data/models/bookmark.dart`, `last_read.dart`, `reading_prefs.dart`, `lib/app/data/repositories/user_repository.dart`, `sqlite_user_repository.dart`
- Modify: `lib/app/data/sources/setting_keys.dart` (tambah `arabicFontSize = 'arabic_font_size'`, `showTranslation = 'show_translation'`), `lib/app/core/theme/theme_mode_setting.dart` (tambah `String themeModeToSetting(ThemeMode)`), `lib/app/app_bootstrap.dart`, `test/app/bootstrap_test.dart`
- Test: `test/app/data/sqlite_user_repository_test.dart`

**Interfaces:**
- Consumes: `UserDatabase` (`raw`, `getSetting`, `setSetting`), `AyahRef`.
- Produces:
  - `class Bookmark { final AyahRef ref; final DateTime createdAt; }`, `class LastRead { final AyahRef ref; final DateTime updatedAt; }`, `class ReadingPrefs { final double arabicFontSize; final bool showTranslation; }`.
  - `abstract interface class UserRepository { bool toggleBookmark(AyahRef ref); List<Bookmark> listBookmarks(); Set<int> bookmarkedAyahNumbers(int surahNumber); Set<int> bookmarkedSurahNumbers(); LastRead? getLastRead(); void setLastRead(AyahRef ref); ReadingPrefs getReadingPrefs(); void setArabicFontSize(double size); void setShowTranslation(bool value); ThemeMode getThemeMode(); void setThemeMode(ThemeMode mode); }`. `toggleBookmark` mengembalikan keadaan baru.
  - `class SqliteUserRepository implements UserRepository { SqliteUserRepository(UserDatabase db, {DateTime Function()? now}); }`. Waktu disimpan sebagai epoch milidetik UTC.
  - `getLastRead()` mengembalikan `null` bila belum ada (controller yang menerjemahkannya, `null` tidak boleh sampai ke UI). Default preferensi: `arabicFontSize == 28.0`, `showTranslation == true`. `setArabicFontSize` membatasi ke 20–40.

- [ ] **Step 1: Tulis tes yang gagal** (`UserDatabase` di direktori sementara): toggle dua kali memberi `true` lalu `false` dan tidak menggandakan baris; ketuk toggle 5 kali berturut-turut berakhir `true` dengan satu baris; `listBookmarks` terbaru dulu (jam palsu menaik); `bookmarkedAyahNumbers(1)` dan `bookmarkedSurahNumbers()` benar; `getLastRead()` `null` pada database baru; dua kali `setLastRead` menyisakan satu baris dengan nilai terakhir; default dan klem preferensi (`setArabicFontSize(100)` jadi `40.0`, `10` jadi `20.0`); semua nilai bertahan setelah `UserDatabase` dibuka ulang; `themeModeToSetting`/`themeModeFromSetting` bolak-balik untuk `light`, `dark`, `system`.
- [ ] **Step 2: Jalankan** tes itu. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces: `kind = 'ayah'`, `ref_a` berisi nomor surah sebagai teks, `ref_b` nomor ayat; upsert untuk `last_read`.
- [ ] **Step 4: Daftarkan** `UserRepository` di `bootstrap()`, jalankan semua tes sampai lulus.
- [ ] **Step 5: Commit** `feat: add user repository for bookmarks and reading prefs`.

### Task 5: Shell navigasi dan komponen keadaan

**Files:**
- Create: `lib/app/core/widgets/empty_state.dart`, `error_state.dart`, `lib/app/modules/shell/views/shell_view.dart`, `controllers/shell_controller.dart`, `widgets/coming_soon_tab.dart`
- Modify: `lib/app/routes/app_pages.dart` (route `Routes.home` memakai `ShellView`)
- Test: `test/app/modules/shell/shell_view_test.dart`, `test/app/core/widgets/state_widgets_test.dart`

**Interfaces:**
- Produces: `EmptyState({required String title, String description = '', Widget? action})`, `ErrorState({required String title, required String description, required VoidCallback onRetry})` dengan tombol "Coba lagi". `ShellView` berisi `NavigationBar` empat tujuan berlabel `Beranda`, `Al-Qur'an`, `Hadis`, `Sholat` (ikon dan label, bukan warna saja) dan `IndexedStack`: tab Beranda memakai `HomeView` yang ada, tab Hadis dan Sholat memakai `ComingSoonTab` (`EmptyState` berjudul "Segera hadir"), tab Al-Qur'an sementara `SizedBox.shrink()` (diganti di Task 6).

- [ ] **Step 1: Tulis tes yang gagal:** `NavigationBar` punya empat label; mengetuk "Hadis" menampilkan "Segera hadir"; `ErrorState` menampilkan judul dan deskripsi, dan mengetuk "Coba lagi" memanggil `onRetry`; `EmptyState` tanpa deskripsi tidak merender teks kosong.
- [ ] **Step 2: Jalankan** kedua tes. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. Target sentuh ≥ 48. Warna dan jarak dari tema dan `NuraSpace`.
- [ ] **Step 4: Jalankan** `flutter test` penuh (tes Fase 1 yang menunggu `HomeView` harus tetap lulus atau disesuaikan ke `ShellView`).
- [ ] **Step 5: Commit** `feat: add bottom navigation shell and state widgets`.

### Task 6: Daftar Al-Qur'an (tab Surah dan Juz)

**Files:**
- Create: `lib/app/modules/quran_list/bindings/quran_list_binding.dart`, `controllers/quran_list_controller.dart`, `views/quran_list_view.dart`, `widgets/surah_list_item.dart`, `widgets/juz_list_item.dart`, `lib/app/modules/quran_detail/surah_args.dart`, `test/support/fake_repositories.dart`
- Modify: `lib/app/modules/shell/views/shell_view.dart` (tab Al-Qur'an memakai `QuranListView`), `lib/app/routes/app_routes.dart` (`Routes.surah = '/quran/surah'`)
- Test: `test/app/modules/quran_list/quran_list_test.dart`

**Interfaces:**
- Consumes: `QuranRepository`, `UserRepository`, `UiState`, `EmptyState`, `ErrorState`.
- Produces:
  - `class SurahArgs { const SurahArgs(this.surah, [this.ayah = 0]); final int surah; final int ayah; }` (`ayah == 0` berarti tanpa target).
  - `QuranListController`: `Rx<UiState<List<Surah>>> surahs`, `Rx<UiState<List<Juz>>> juz`, `RxSet<int> bookmarkedSurahs`, `RxInt lastReadSurah` (0 = belum ada), `void load()`. Memuat di `onInit`.
  - `enum SurahItemState { normal, bookmarked, lastRead }`; `SurahListItem({required Surah surah, required SurahItemState state, required VoidCallback onTap})`; `JuzListItem({required Juz juz, required VoidCallback onTap})`.
  - `QuranListView`: `TabBar` dengan tab "Surah" dan "Juz" (tab "Bookmark" ditambah di Task 11). Mengetuk surah memanggil `Get.toNamed(Routes.surah, arguments: SurahArgs(number))`.
  - `FakeQuranRepository` dan `FakeUserRepository` di `test/support/fake_repositories.dart` (data dan kegagalan dapat diatur per tes).

- [ ] **Step 1: Tulis tes yang gagal** (repository palsu): daftar menampilkan nama Latin, arti (`nameId`), `7 ayat`, dan nama Arab; `revelation == ''` tidak menampilkan label tempat turun; `makkiyah` tampil "Makkiyah", `madaniyah` tampil "Madaniyah", nilai lain disembunyikan; item surah terakhir dibaca menampilkan teks "Terakhir dibaca" dan ikon; item bookmarked menampilkan ikon bookmark dengan label semantik; repository melempar `ContentUnavailable` → `ErrorState` dan "Coba lagi" memuat ulang; tab Juz dengan `listJuz() == []` menampilkan `EmptyState` "Daftar juz belum tersedia"; baris juz menampilkan nomor dan rentang `1:1 – 1:7` untuk `Juz(1, 1, 1, 1, 7)`; mengetuk surah membuka route `Routes.surah` dengan `SurahArgs` berisi nomor yang benar.
- [ ] **Step 2: Jalankan** `flutter test test/app/modules/quran_list`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. `SurahListItem`: nomor di bingkai ornamen, nama Latin, arti, jumlah ayat, tempat turun (bila ada), nama Arab (gaya `arabicTitle`); teks keterangan wrap, tinggi mengikuti isi dengan `minHeight`.
- [ ] **Step 4: Jalankan tes** sampai lulus, termasuk keadaan loading yang terlihat sebelum data.
- [ ] **Step 5: Commit** `feat: list surah and juz in quran tab`.

### Task 7: Baca Surah

**Files:**
- Create: `lib/app/modules/quran_detail/bindings/quran_detail_binding.dart`, `controllers/quran_detail_controller.dart`, `views/quran_detail_view.dart`, `widgets/surah_header_card.dart`, `bismillah_header.dart`, `ayah_card.dart`, `ayah_number_badge.dart`, `ayah_action_bar.dart`
- Modify: `lib/app/routes/app_pages.dart` (daftarkan `Routes.surah`), `test/support/fake_repositories.dart`
- Test: `test/app/modules/quran_detail/quran_detail_test.dart`

**Interfaces:**
- Consumes: `QuranRepository`, `UserRepository`, `SurahArgs`, `NuraTextStyles`, `NuraColors`.
- Produces:
  - `class SurahContent { final Surah surah; final String basmalah; final List<Ayah> ayahs; }`.
  - `QuranDetailController(SurahArgs args)`: `Rx<UiState<SurahContent>> state`, `RxSet<int> bookmarked`, `Rx<ReadingPrefs> prefs`, `void load()`, `void toggleBookmark(int ayahNumber)`, `Future<void> copyAyah(Ayah ayah)`. `basmalah` = `getAyah(AyahRef(1, 1)).arab`.
  - `SurahHeaderCard({required Surah surah, required String basmalah, required bool showBismillah})` dengan `showBismillah = surah.number != 1 && surah.number != 9`; `BismillahHeader({required String text})`; `AyahNumberBadge({required int number})`; `AyahActionBar({required bool bookmarked, required VoidCallback onBookmark, required VoidCallback onCopy})`; `AyahCard({required Ayah ayah, required bool bookmarked, required bool lastRead, required ReadingPrefs prefs, required VoidCallback onBookmark, required VoidCallback onCopy})`.
  - App bar: nama surah dan subjudul `<Nama Latin> · <n> ayat`. Daftar memakai `ListView.builder`. Teks Arab `textDirection: TextDirection.rtl` dengan gaya `arabicReading` berukuran `prefs.arabicFontSize`; terjemahan hanya bila `prefs.showTranslation`.

- [ ] **Step 1: Tulis tes yang gagal:** surah 1 dan surah 9 tidak punya `BismillahHeader`; surah 2 punya tepat satu dengan teks sama persis dengan Arab ayat 1:1 dari repository; `AyahCard` merender `ayah.arab` dan `ayah.translation` persis (entri sintetis berisi spasi di akhir dan karakter U+200C, dicari dengan `find.text` string utuh); `showTranslation == false` menyembunyikan terjemahan; mengetuk ikon bookmark memanggil `toggleBookmark` dan ikon berubah terisi dengan label semantik "Hapus bookmark" atau "Tambah bookmark"; ayat sintetis Arab 1.218 karakter dan terjemahan 1.670 karakter pada `arabicFontSize == 40` dan `textScaler` 1,3 di layar 360 × 800 tidak menimbulkan exception layout; `copyAyah` menaruh teks format Keputusan 7 ke clipboard dan menampilkan snackbar "Ayat disalin"; `ContentUnavailable` → `ErrorState` dan "Coba lagi" memuat ulang; urutan ayat mengikuti repository.
- [ ] **Step 2: Jalankan** `flutter test test/app/modules/quran_detail`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. Tata letak `AyahCard`: baris badge kiri dan `AyahActionBar` kanan, lalu Arab, lalu terjemahan. Tanpa bayangan, jarak antarkartu 12, padding horizontal 20.
- [ ] **Step 4: Jalankan tes** sampai lulus.
- [ ] **Step 5: Commit** `feat: read surah with ayah cards and bookmark`.

### Task 8: Tafsir (bottom sheet)

**Files:**
- Create: `lib/app/modules/quran_detail/widgets/tafsir_sheet.dart`
- Modify: `widgets/ayah_action_bar.dart` (tambah `onTafsir`), `widgets/ayah_card.dart`, `views/quran_detail_view.dart`
- Test: `test/app/modules/quran_detail/tafsir_sheet_test.dart`

**Interfaces:**
- Produces: `Future<void> showTafsirSheet(BuildContext context, {required List<Ayah> ayahs, required int initialIndex, required String surahName})`. Sheet: pegangan, judul "Tafsir Kemenag", subjudul `<surahName> · ayat <n>`, isi tafsir yang bisa digulir, dan dua tombol teks berikon "Sebelumnya" dan "Berikutnya" (wrap bila tidak muat). Tinggi maksimum 90% layar, `barrierColor` = `colorScheme.scrim` dengan alpha 0,32.

- [ ] **Step 1: Tulis tes yang gagal:** sheet menampilkan `ayah.tafsir` persis; tafsir sintetis 19.245 karakter berisi `\n` dapat digulir sampai teks terakhir terlihat dan tidak overflow, dan `\n` dipertahankan; "Sebelumnya" nonaktif pada ayat pertama dan "Berikutnya" nonaktif pada ayat terakhir; "Berikutnya" menampilkan tafsir ayat berikutnya dan subjudul berubah; tafsir kosong (`''`) menampilkan "Tafsir belum tersedia untuk ayat ini"; tinggi sheet ≤ 0,9 × tinggi layar (720 pada 800); mengetuk ikon tafsir pada `AyahCard` membuka sheet untuk ayat yang benar.
- [ ] **Step 2: Jalankan** tes itu. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. `isScrollControlled: true`.
- [ ] **Step 4: Jalankan tes** sampai lulus.
- [ ] **Step 5: Commit** `feat: show tafsir kemenag in bottom sheet`.

### Task 9: Pengaturan tampilan baca dan tema reaktif

**Files:**
- Create: `lib/app/modules/quran_detail/widgets/reading_settings_sheet.dart`, `lib/app/core/theme/theme_controller.dart`
- Modify: `lib/app/nura_app.dart` (tema dibaca dari `ThemeController`), `lib/app/app_bootstrap.dart` (daftarkan `ThemeController`), `controllers/quran_detail_controller.dart`, `views/quran_detail_view.dart` (aksi di app bar)
- Test: `test/app/modules/quran_detail/reading_settings_test.dart`, `test/app/core/theme/theme_controller_test.dart`

**Interfaces:**
- Produces:
  - `class ThemeController extends GetxController { Rx<ThemeMode> mode; void setMode(ThemeMode mode); }` — membaca `UserRepository.getThemeMode()` di `onInit`, menyimpan lewat `setThemeMode`, dan memanggil `Get.changeThemeMode`.
  - `QuranDetailController.setArabicFontSize(double)` dan `setShowTranslation(bool)`: memperbarui `prefs` dan menyimpan lewat `UserRepository`.
  - `showReadingSettingsSheet(BuildContext context, {required QuranDetailController controller, required ThemeController theme})`: slider ukuran Arab 20–40 (`divisions: 10`) dengan pratinjau langsung memakai Basmalah dari `SurahContent`, sakelar "Tampilkan terjemahan", dan pilihan tema "Sistem", "Terang", "Gelap" (`SegmentedButton`). Tinggi maksimum 90%, isi bisa digulir.

- [ ] **Step 1: Tulis tes yang gagal:** menggeser slider ke 36 mengubah `fontSize` teks Arab pada `AyahCard` menjadi 36 dan tersimpan di repository; sakelar menyembunyikan dan menampilkan terjemahan; memilih "Gelap" mengubah `GetMaterialApp.themeMode` menjadi `ThemeMode.dark` dan tersimpan; `ThemeController` baru yang dibuat setelah itu membaca `dark`; sheet pada `textScaler` 1,3 tidak overflow dan tinggi ≤ 90%.
- [ ] **Step 2: Jalankan** tes itu. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. Pilihan tema yang aktif ditandai dengan ikon centang, bukan warna saja.
- [ ] **Step 4: Jalankan tes** sampai lulus, termasuk `bootstrap_test`.
- [ ] **Step 5: Commit** `feat: add reading settings sheet and reactive theme`.

### Task 10: Last Read

**Files:**
- Modify: `pubspec.yaml` (tambah `scrollable_positioned_list`), `controllers/quran_detail_controller.dart`, `views/quran_detail_view.dart`, `widgets/ayah_card.dart`
- Test: `test/app/modules/quran_detail/last_read_test.dart`

**Interfaces:**
- Produces: `QuranDetailController.lastReadAyah` (`RxInt`, 0 = tidak ada di surah ini), `void onVisibleAyahChanged(int ayahNumber)`, `void flushLastRead()` (menyimpan `AyahRef(surah, ayat terakhir yang dilaporkan)` lewat `UserRepository.setLastRead`; tidak menulis apa pun bila belum pernah dilaporkan). `flushLastRead` dipanggil di `onClose` dan saat `AppLifecycleState.paused`. Daftar memakai `ScrollablePositionedList` dan membuka surah dengan menggulir ke `args.ayah` bila > 0, atau ke ayat last read bila ada di surah ini. `AyahCard(lastRead: true)`: latar `lastReadHighlight`, label "Terakhir dibaca", ikon `Icons.history_rounded`.

- [ ] **Step 1: Tulis tes yang gagal:** `flushLastRead()` tanpa laporan tidak menulis (repository palsu mencatat nol panggilan `setLastRead`); setelah `onVisibleAyahChanged(5)` lalu `flushLastRead()` tepat satu panggilan dengan `AyahRef(1, 5)`; dua laporan lalu flush menyimpan nilai terakhir; membuka surah 1 dengan last read 1:5 menampilkan tepat satu label "Terakhir dibaca" pada ayat 5; `SurahArgs(1, 3)` membuat ayat 3 terlihat; last read di surah lain tidak menandai ayat mana pun; peluncuran pertama (`getLastRead() == null`) tidak melempar.
- [ ] **Step 2: Jalankan** tes itu. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. Ayat terlihat = indeks terkecil dengan `itemTrailingEdge > 0`; header surah di indeks 0 dihitung sebagai ayat 1. Jika Keputusan 1 ditolak, hentikan dan minta arahan.
- [ ] **Step 4: Jalankan** `flutter test` penuh sampai lulus.
- [ ] **Step 5: Commit** `feat: track and highlight last read ayah`.

### Task 11: Tab Bookmark

**Files:**
- Create: `lib/app/modules/bookmarks/controllers/bookmarks_controller.dart`, `views/bookmarks_tab.dart`, `widgets/bookmark_tile.dart`
- Modify: `lib/app/modules/quran_list/views/quran_list_view.dart` (tab ketiga "Bookmark")
- Test: `test/app/modules/bookmarks/bookmarks_test.dart`

**Interfaces:**
- Produces: `BookmarksController`: `Rx<UiState<List<BookmarkItem>>> items`, `void load()`. `class BookmarkItem { final Bookmark bookmark; final Surah surah; final Ayah ayah; }`. `BookmarkTile({required BookmarkItem item, required VoidCallback onTap})`: `<Nama Latin> · ayat <n>` dan terjemahan maksimal dua baris dengan elipsis. Mengetuk membuka `Routes.surah` dengan `SurahArgs(surah, ayat)`. Daftar dimuat ulang saat kembali dari layar baca. `EmptyState` berjudul "Belum ada bookmark".

- [ ] **Step 1: Tulis tes yang gagal:** tiga bookmark tampil terbaru dulu; daftar kosong menampilkan "Belum ada bookmark"; bookmark ke ayat yang tidak ada di repository (`getAyah` melempar `ContentUnavailable`) dilewati dan yang lain tetap tampil; mengetuk tile membuka route dengan `SurahArgs` yang benar; setelah `toggleBookmark` dari layar baca lalu kembali, daftar diperbarui; kegagalan membaca menghasilkan `ErrorState`.
- [ ] **Step 2: Jalankan** tes itu. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces.
- [ ] **Step 4: Jalankan** `flutter test` penuh dan `flutter analyze`.
- [ ] **Step 5: Commit** `feat: list saved ayah in bookmark tab`.

### Task 12: Dokumen dan uji perangkat

**Files:**
- Modify: `docs/STATUS.md`, `docs/PRD.md` (sesuai Keputusan 6, bila disetujui), `docs/specs/2026-11-09-nura-v1-design.md` (bila ada keputusan yang mengubah spec)

- [ ] **Step 1: Perbarui `docs/STATUS.md`:** baris fitur Al-Qur'an offline (yang selesai dan yang menunggu Q4), baris Desain UI (tema dari token dan font), dan Langkah Berikutnya. Rapikan PRD 5.1 bila Keputusan 6 disetujui.
- [ ] **Step 2: Jalankan** `flutter analyze` dan `flutter test`; catat jumlah tes di STATUS.
- [ ] **Step 3: Commit** `docs: update status after phase 2`.
- [ ] **Step 4: Uji perangkat oleh pemilik proyek** (AGENTS: fitur UI selesai hanya setelah dijalankan di perangkat). Daftar periksa: daftar 114 surah tampil dan bisa digulir; baca Al-Baqarah sampai akhir tanpa jank; tafsir panjang bisa digulir; Arab 40 dan teks sistem besar tidak terpotong; tema gelap bertahan setelah aplikasi ditutup; bookmark dan last read bertahan setelah restart; mode pesawat tidak memengaruhi apa pun. Catat hasilnya di STATUS.

---

## Di Luar Rencana Ini

- Pencarian Al-Qur'an (SearchField, layar 10, cuplikan hasil): Fase 4. Aturan cuplikan sudah ada di spec bagian 5.5.
- Isi Beranda (kartu waktu sholat, kartu harian, LastReadCard): Fase 5 dan 6.
- Audio, bagikan ayat, dan layar hadis: Fase 7, tertunda, dan Fase 3.
- Data meta (`surah_info.json`, `juz.json`): menunggu Q4. Kode Fase 2 sudah menangani ketiadaannya.
