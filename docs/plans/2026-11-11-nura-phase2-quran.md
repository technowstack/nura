# Nura Fase 2 (Al-Qur'an Offline): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Al-Qur'an bisa dibaca penuh secara offline: daftar surah dan juz, baca surah, tafsir Kemenag, bookmark, last read, ukuran teks Arab, dan tema, dengan tampilan sesuai desain putaran 1.

**Architecture:** `QuranRepository` (membaca `content.db` read-only) dan `UserRepository` (membaca dan menulis `user.db`) mendaftar sebagai singleton GetX di `bootstrap()`. Setiap layar punya controller GetX dengan `UiState<T>`, dan view hanya menampilkan state. Tema dibangun dari `docs/design/tokens.json`. Bottom navigation empat tab memuat tab Al-Qur'an; tab Hadis dan Sholat masih placeholder.

**Tech Stack:** Flutter, GetX, `sqlite3` (sudah ada). Paket baru hanya `super_sliver_list` (dipilih, lihat Keputusan 1).

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (bagian 5.1–5.3, 5.6, 9, 10, 11 Fase 2). Desain: `docs/design/HANDOFF-flutter.md` dan `docs/design/2026-11-09-nura-ui-design-brief.md` (bagian 4, 5 layar 6–9 dan 11). Baca juga `AGENTS.md`.

## Keputusan (dijawab pemilik proyek 2026-11-11)

| # | Hal | Keputusan |
|---|---|---|
| 1 | Paket scroll ke ayat dan pelacakan ayat terlihat | **`super_sliver_list`** (0.4.1). Alasan di bawah |
| 2 | Font | Plus Jakarta Sans (OFL) disediakan pemilik di `assets/fonts/` beserta lisensinya. LPMQ Isep Misbah menunggu Q6: sementara teks Arab memakai font fallback sistem. Task font (Task 11) tidak memblokir task lain |
| 3 | Pencarian | Fase 4. Fase 2 menyembunyikan kolom cari |
| 4 | Last Read | Otomatis: disimpan berkala (debounce 3 detik setelah scroll berhenti), saat meninggalkan layar surah, dan saat aplikasi di-pause |
| 5 | Layar utama pada teks Latin 130% | Widget test layar utama dengan `TextScaler.linear(1.3)` pada 360 × 640, gagal bila ada overflow. Ada di tiap task layar |
| 6 | Target 2,5 ayat terlihat di layar baca | Tidak ada aturan, tidak perlu tes |
| 7 | `SurahListItem` "Bookmarked" | Ikon bookmark bila surah punya minimal satu ayat ber-bookmark. Bila juga surah terakhir dibaca, state "Terakhir dibaca" yang menang |
| 8 | Pengaturan tampilan | Hanya ukuran Arab (20–40), sakelar terjemahan, dan tema. Ukuran terjemahan tetap. PRD dirapikan di Task 12 |
| 9 | Aksi `AyahActionBar` | Bookmark, tafsir, dan salin. "Bagikan" ditunda (butuh `share_plus`). Audio disembunyikan sampai Fase 7. Format salin: teks Arab, baris kosong, terjemahan, baris kosong, `QS. <Nama Latin>: <ayat>` |
| 10 | Navigasi tafsir | "Sebelumnya" dan "Berikutnya" dalam satu surah, nonaktif di ayat pertama dan terakhir |
| 11 | Query berat di isolate | Fase 2 memakai query sinkron (satu surah paling banyak 286 ayat). Isolate di Fase 4 |
| 12 | Data meta belum ada (Q4) | `revelation` kosong: label tempat turun disembunyikan. Tabel `juz` kosong: tab Juz menampilkan keadaan kosong |

### Perbandingan paket (Keputusan 1)

Data per 2026-11-11 dari pub.dev, GitHub, dan uji langsung pada Flutter proyek ini (daftar 300 item bertinggi bervariasi, satu item setinggi 940 px, layar 360 × 640).

| | `scrollable_positioned_list` | `super_sliver_list` |
|---|---|---|
| Rilis terakhir | 0.3.8, 2023-05-08 | 0.4.1, 2024-03-26 |
| Perawatan | Repositori `google/flutter.widgets` **diarsipkan** (commit terakhir 2024-08-08), 258 isu terbuka | Repositori aktif, tidak diarsipkan (commit terakhir 2026-10-09), 33 isu terbuka |
| SDK | Dart `>=2.15 <4.0` | Dart `>=3.0 <4.0` |
| Lompat ke indeks | `ItemScrollController.jumpTo(index)` | `ListController.jumpToItem(index, scrollController, alignment)` |
| Item terlihat | `ItemPositionsListener` (daftar posisi) | `ListController.visibleRange` (`(int, int)?`) dan `ChangeNotifier` |
| Uji pada Flutter kita | Lolos: lompat ke 250 tepat | Lolos: lompat ke 250, 17, dan 299 tepat; `visibleRange` benar |
| Popularitas | 1.995 likes | 301 likes |

Dipilih `super_sliver_list`: repositori pesaingnya sudah diarsipkan dan tidak akan menerima perbaikan, sedangkan `super_sliver_list` masih dirawat dan mendukung tinggi item bervariasi dengan taksiran tinggi yang dikoreksi saat item terbangun. Risikonya: rilis terakhir lebih dari dua tahun lalu dan komunitasnya lebih kecil. Pemakaian dibatasi di layar Baca Surah, sehingga mudah diganti bila perlu.

## Global Constraints

- Branch kerja `feat/phase-2-quran`. Selesai: `merge --no-ff` ke `main` setelah review akhir. Jangan push.
- Tidak mengubah `data-source/`, skema `content.db`, atau `lib/content_pipeline/`. `content.db` hanya dibuka read-only (AGENTS aturan 4).
- Teks Arab, terjemahan, dan tafsir ditampilkan persis seperti di database: tanpa `trim` atau perubahan lain (aturan 3). Tidak ada teks Arab yang diketik di kode atau tes produksi. Basmalah diambil dari ayat 1:1 di database.
- Tidak ada akses jaringan. Tidak ada paket selain `super_sliver_list`.
- Nilai tema bersumber dari `docs/design/tokens.json`. Kode tema di `lib/app/core/theme/`. Font Latin `Plus Jakarta Sans`; font Arab `LPMQ Isep Misbah` (belum terpasang, memakai fallback sistem sampai Q6). Material 3. Target sentuh minimal 48 × 48. Status tidak hanya dibedakan lewat warna.
- **Uji Latin 130%:** setiap layar utama punya widget test dengan `TextScaler.linear(1.3)` pada layar 360 × 640 yang gagal bila `tester.takeException()` tidak null (overflow). Arab 40 diuji pada layar baca.
- Pola AGENTS.md: view hanya menampilkan state controller; data dimuat di `onInit` atau aksi pengguna, tidak ada future di `build()`; setiap layar menangani loading, kosong, dan error; model immutable; satu class publik per file (model kecil dan hierarki sealed boleh berbagi file); tanpa `!` dan `ignore_for_file`.
- Teks yang dilihat pengguna dalam Bahasa Indonesia. Commit dalam Bahasa Inggris (Conventional Commits). `flutter analyze` bersih dan `flutter test` lulus sebelum setiap commit.
- `flutter test` butuh `assets/db/content.db` lokal (`tool/prepare_content.sh`). Tes memakai fixture (`buildFixtureDb` di `test/support/fixture_db.dart`, `fixtureDir('')` di `test/support/fixtures.dart`), bukan database penuh.
- Keputusan baru yang mengubah spec, skema, atau dependency: berhenti dan tanya pemilik proyek.

## Review Focus

1. **Surah tanpa Basmalah.** Al-Fatihah (1) dan At-Taubah (9) tidak menampilkan header Bismillah; surah lain menampilkannya, dengan teks dari ayat 1:1. Diuji di Task 6.
2. **Tafsir sangat panjang.** Tafsir terpanjang 19.245 karakter dan 4.371 tafsir berisi baris baru. Sheet harus bisa digulir sampai akhir dan baris baru dipertahankan. Diuji di Task 7.
3. **Ayat sangat panjang.** Arab terpanjang 1.218 karakter dan terjemahan terpanjang 1.670. Dengan Arab 40 dan Latin 130% pada 360 × 640 tidak boleh ada overflow. Diuji di Task 6 dan 8.
4. **Database gagal dibaca.** `ContentUnavailable` harus menjadi `ErrorState` dengan tombol "Coba lagi", bukan crash. Diuji di Task 2, 5, 6.
5. **Bookmark dan Last Read.** Ketuk bookmark berulang tetap konsisten (unik per ayat). Pada peluncuran pertama `last_read` kosong dan tidak ada `null` yang sampai ke UI. Penyimpanan berkala tidak menulis berulang untuk ayat yang sama. Bookmark ke ayat yang tidak ada di database dilewati, tidak crash. Diuji di Task 3, 9, 10.

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
assets/fonts/                                  (dari pemilik proyek: Plus Jakarta Sans)
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

### Task 2: Model, UiState, `QuranRepository`

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

### Task 3: `UserRepository` (bookmark, last read, preferensi)

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

### Task 4: Shell navigasi dan komponen keadaan

**Files:**
- Create: `lib/app/core/widgets/empty_state.dart`, `error_state.dart`, `lib/app/modules/shell/views/shell_view.dart`, `controllers/shell_controller.dart`, `widgets/coming_soon_tab.dart`
- Modify: `lib/app/routes/app_pages.dart` (route `Routes.home` memakai `ShellView`)
- Test: `test/app/modules/shell/shell_view_test.dart`, `test/app/core/widgets/state_widgets_test.dart`

**Interfaces:**
- Produces: `EmptyState({required String title, String description = '', Widget? action})`, `ErrorState({required String title, required String description, required VoidCallback onRetry})` dengan tombol "Coba lagi". `ShellView` berisi `NavigationBar` empat tujuan berlabel `Beranda`, `Al-Qur'an`, `Hadis`, `Sholat` (ikon dan label, bukan warna saja) dan `IndexedStack`: tab Beranda memakai `HomeView` yang ada, tab Hadis dan Sholat memakai `ComingSoonTab` (`EmptyState` berjudul "Segera hadir"), tab Al-Qur'an sementara `SizedBox.shrink()` (diganti di Task 5).

- [ ] **Step 1: Tulis tes yang gagal:** `NavigationBar` punya empat label; mengetuk "Hadis" menampilkan "Segera hadir"; `ErrorState` menampilkan judul dan deskripsi, dan mengetuk "Coba lagi" memanggil `onRetry`; `EmptyState` tanpa deskripsi tidak merender teks kosong; **uji Latin 130%:** `ShellView` pada `TextScaler.linear(1.3)` di 360 × 640 tanpa exception.
- [ ] **Step 2: Jalankan** kedua tes. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. Target sentuh ≥ 48. Warna dan jarak dari tema dan `NuraSpace`.
- [ ] **Step 4: Jalankan** `flutter test` penuh (tes Fase 1 yang menunggu `HomeView` harus tetap lulus atau disesuaikan ke `ShellView`).
- [ ] **Step 5: Commit** `feat: add bottom navigation shell and state widgets`.

### Task 5: Daftar Al-Qur'an (tab Surah dan Juz)

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
  - `QuranListView`: `TabBar` dengan tab "Surah" dan "Juz" (tab "Bookmark" ditambah di Task 10). Tidak ada kolom cari (Keputusan 3). Mengetuk surah memanggil `Get.toNamed(Routes.surah, arguments: SurahArgs(number))`.
  - `FakeQuranRepository` dan `FakeUserRepository` di `test/support/fake_repositories.dart` (data dan kegagalan dapat diatur per tes).

- [ ] **Step 1: Tulis tes yang gagal** (repository palsu): daftar menampilkan nama Latin, arti (`nameId`), `7 ayat`, dan nama Arab; `revelation == ''` tidak menampilkan label tempat turun; `makkiyah` tampil "Makkiyah", `madaniyah` tampil "Madaniyah", nilai lain disembunyikan; item surah terakhir dibaca menampilkan teks "Terakhir dibaca" dan ikon; item bookmarked menampilkan ikon bookmark dengan label semantik; repository melempar `ContentUnavailable` → `ErrorState` dan "Coba lagi" memuat ulang; tab Juz dengan `listJuz() == []` menampilkan `EmptyState` "Daftar juz belum tersedia"; baris juz menampilkan nomor dan rentang `1:1 – 1:7` untuk `Juz(1, 1, 1, 1, 7)`; mengetuk surah membuka route `Routes.surah` dengan `SurahArgs` berisi nomor yang benar; tidak ada `TextField` di layar; **uji Latin 130%:** tab Surah dan tab Juz pada `TextScaler.linear(1.3)` di 360 × 640 tanpa exception.
- [ ] **Step 2: Jalankan** `flutter test test/app/modules/quran_list`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. `SurahListItem`: nomor di bingkai ornamen, nama Latin, arti, jumlah ayat, tempat turun (bila ada), nama Arab (gaya `arabicTitle`); teks keterangan wrap, tinggi mengikuti isi dengan `minHeight`.
- [ ] **Step 4: Jalankan tes** sampai lulus, termasuk keadaan loading yang terlihat sebelum data.
- [ ] **Step 5: Commit** `feat: list surah and juz in quran tab`.

### Task 6: Baca Surah

**Files:**
- Create: `lib/app/modules/quran_detail/bindings/quran_detail_binding.dart`, `controllers/quran_detail_controller.dart`, `views/quran_detail_view.dart`, `widgets/surah_header_card.dart`, `bismillah_header.dart`, `ayah_card.dart`, `ayah_number_badge.dart`, `ayah_action_bar.dart`
- Modify: `pubspec.yaml` (tambah `super_sliver_list: ^0.4.1`), `lib/app/routes/app_pages.dart` (daftarkan `Routes.surah`), `test/support/fake_repositories.dart`
- Test: `test/app/modules/quran_detail/quran_detail_test.dart`

**Interfaces:**
- Consumes: `QuranRepository`, `UserRepository`, `SurahArgs`, `NuraTextStyles`, `NuraColors`.
- Produces:
  - `class SurahContent { final Surah surah; final String basmalah; final List<Ayah> ayahs; }`.
  - `QuranDetailController(SurahArgs args)`: `Rx<UiState<SurahContent>> state`, `RxSet<int> bookmarked`, `Rx<ReadingPrefs> prefs`, `final ListController listController` (dari `super_sliver_list`), `void load()`, `void toggleBookmark(int ayahNumber)`, `Future<void> copyAyah(Ayah ayah)`. `basmalah` = `getAyah(AyahRef(1, 1)).arab`.
  - `SurahHeaderCard({required Surah surah, required String basmalah, required bool showBismillah})` dengan `showBismillah = surah.number != 1 && surah.number != 9`; `BismillahHeader({required String text})`; `AyahNumberBadge({required int number})`; `AyahActionBar({required bool bookmarked, required VoidCallback onBookmark, required VoidCallback onCopy})`; `AyahCard({required Ayah ayah, required bool bookmarked, required bool lastRead, required ReadingPrefs prefs, required VoidCallback onBookmark, required VoidCallback onCopy})`.
  - App bar: nama surah dan subjudul `<Nama Latin> · <n> ayat`. Daftar memakai `SuperListView.builder` (header surah di indeks 0, ayat di indeks 1..n). Teks Arab `textDirection: TextDirection.rtl` dengan gaya `arabicReading` berukuran `prefs.arabicFontSize`; terjemahan hanya bila `prefs.showTranslation`.

- [ ] **Step 1: Tulis tes yang gagal:** surah 1 dan surah 9 tidak punya `BismillahHeader`; surah 2 punya tepat satu dengan teks sama persis dengan Arab ayat 1:1 dari repository; `AyahCard` merender `ayah.arab` dan `ayah.translation` persis (entri sintetis berisi spasi di akhir dan karakter U+200C, dicari dengan `find.text` string utuh); `showTranslation == false` menyembunyikan terjemahan; mengetuk ikon bookmark memanggil `toggleBookmark` dan ikon berubah terisi dengan label semantik "Hapus bookmark" atau "Tambah bookmark"; ayat sintetis Arab 1.218 karakter dan terjemahan 1.670 karakter pada `arabicFontSize == 40` dan `TextScaler.linear(1.3)` di 360 × 640 tidak menimbulkan exception layout; `copyAyah` menaruh teks format Keputusan 9 ke clipboard dan menampilkan snackbar "Ayat disalin"; `ContentUnavailable` → `ErrorState` dan "Coba lagi" memuat ulang; urutan ayat mengikuti repository.
- [ ] **Step 2: Jalankan** `flutter test test/app/modules/quran_detail`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. Tata letak `AyahCard`: baris badge kiri dan `AyahActionBar` kanan, lalu Arab, lalu terjemahan. Tanpa bayangan, jarak antarkartu 12, padding horizontal 20.
- [ ] **Step 4: Jalankan tes** sampai lulus.
- [ ] **Step 5: Commit** `feat: read surah with ayah cards and bookmark`.

### Task 7: Tafsir (bottom sheet)

**Files:**
- Create: `lib/app/modules/quran_detail/widgets/tafsir_sheet.dart`
- Modify: `widgets/ayah_action_bar.dart` (tambah `onTafsir`), `widgets/ayah_card.dart`, `views/quran_detail_view.dart`
- Test: `test/app/modules/quran_detail/tafsir_sheet_test.dart`

**Interfaces:**
- Produces: `Future<void> showTafsirSheet(BuildContext context, {required List<Ayah> ayahs, required int initialIndex, required String surahName})`. Sheet: pegangan, judul "Tafsir Kemenag", subjudul `<surahName> · ayat <n>`, isi tafsir yang bisa digulir, dan dua tombol teks berikon "Sebelumnya" dan "Berikutnya" (wrap bila tidak muat). Tinggi maksimum 90% layar, `barrierColor` = `colorScheme.scrim` dengan alpha 0,32.

- [ ] **Step 1: Tulis tes yang gagal:** sheet menampilkan `ayah.tafsir` persis; tafsir sintetis 19.245 karakter berisi `\n` dapat digulir sampai teks terakhir terlihat dan tidak overflow, dan `\n` dipertahankan; "Sebelumnya" nonaktif pada ayat pertama dan "Berikutnya" nonaktif pada ayat terakhir; "Berikutnya" menampilkan tafsir ayat berikutnya dan subjudul berubah; tafsir kosong (`''`) menampilkan "Tafsir belum tersedia untuk ayat ini"; tinggi sheet ≤ 0,9 × tinggi layar (576 pada 640); mengetuk ikon tafsir pada `AyahCard` membuka sheet untuk ayat yang benar; **uji Latin 130%:** sheet pada `TextScaler.linear(1.3)` di 360 × 640 tanpa exception.
- [ ] **Step 2: Jalankan** tes itu. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. `isScrollControlled: true`.
- [ ] **Step 4: Jalankan tes** sampai lulus.
- [ ] **Step 5: Commit** `feat: show tafsir kemenag in bottom sheet`.

### Task 8: Pengaturan tampilan baca dan tema reaktif

**Files:**
- Create: `lib/app/modules/quran_detail/widgets/reading_settings_sheet.dart`, `lib/app/core/theme/theme_controller.dart`
- Modify: `lib/app/nura_app.dart` (tema dibaca dari `ThemeController`), `lib/app/app_bootstrap.dart` (daftarkan `ThemeController`), `controllers/quran_detail_controller.dart`, `views/quran_detail_view.dart` (aksi di app bar)
- Test: `test/app/modules/quran_detail/reading_settings_test.dart`, `test/app/core/theme/theme_controller_test.dart`

**Interfaces:**
- Produces:
  - `class ThemeController extends GetxController { Rx<ThemeMode> mode; void setMode(ThemeMode mode); }` — membaca `UserRepository.getThemeMode()` di `onInit`, menyimpan lewat `setThemeMode`, dan memanggil `Get.changeThemeMode`.
  - `QuranDetailController.setArabicFontSize(double)` dan `setShowTranslation(bool)`: memperbarui `prefs` dan menyimpan lewat `UserRepository`.
  - `showReadingSettingsSheet(BuildContext context, {required QuranDetailController controller, required ThemeController theme})`: slider ukuran Arab 20–40 (`divisions: 10`) dengan pratinjau langsung memakai Basmalah dari `SurahContent`, sakelar "Tampilkan terjemahan", dan pilihan tema "Sistem", "Terang", "Gelap" (`SegmentedButton`). Tinggi maksimum 90%, isi bisa digulir.

- [ ] **Step 1: Tulis tes yang gagal:** menggeser slider ke 36 mengubah `fontSize` teks Arab pada `AyahCard` menjadi 36 dan tersimpan di repository; sakelar menyembunyikan dan menampilkan terjemahan; memilih "Gelap" mengubah `GetMaterialApp.themeMode` menjadi `ThemeMode.dark` dan tersimpan; `ThemeController` baru yang dibuat setelah itu membaca `dark`; **uji Latin 130%:** sheet pada `TextScaler.linear(1.3)` di 360 × 640 tanpa exception dan tinggi ≤ 90%.
- [ ] **Step 2: Jalankan** tes itu. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. Pilihan tema yang aktif ditandai dengan ikon centang, bukan warna saja.
- [ ] **Step 4: Jalankan tes** sampai lulus, termasuk `bootstrap_test`.
- [ ] **Step 5: Commit** `feat: add reading settings sheet and reactive theme`.

### Task 9: Last Read

**Files:**
- Modify: `controllers/quran_detail_controller.dart`, `views/quran_detail_view.dart`, `widgets/ayah_card.dart`
- Test: `test/app/modules/quran_detail/last_read_test.dart`

**Interfaces:**
- Produces: `QuranDetailController({Duration lastReadDebounce = const Duration(seconds: 3)})`, `lastReadAyah` (`RxInt`, 0 = tidak ada di surah ini), `void onVisibleAyahChanged(int ayahNumber)`, `void flushLastRead()`.
  - `onVisibleAyahChanged` mencatat ayat terlihat dan memulai ulang timer debounce; saat timer habis (scroll berhenti selama `lastReadDebounce`), ayat itu disimpan lewat `UserRepository.setLastRead(AyahRef(surah, ayat))`.
  - `flushLastRead()` menyimpan segera ayat terakhir yang dilaporkan bila belum tersimpan, lalu membatalkan timer. Dipanggil di `onClose` dan saat `AppLifecycleState.paused`.
  - Tidak ada tulisan ulang untuk ayat yang sama, dan tidak ada tulisan sama sekali bila belum pernah ada laporan.
  - Layar membaca `listController.visibleRange` (listener pada `ListController`) untuk melaporkan ayat terlihat: indeks daftar 0 (header) dihitung ayat 1, indeks `i ≥ 1` = ayat `i`.
  - Membuka surah menggulir dengan `listController.jumpToItem(index, scrollController, alignment: 0.0)` ke `args.ayah` bila > 0, atau ke ayat last read bila ada di surah ini.
  - `AyahCard(lastRead: true)`: latar `lastReadHighlight`, label "Terakhir dibaca", ikon `Icons.history_rounded`.

- [ ] **Step 1: Tulis tes yang gagal** (waktu dikendalikan dengan `fakeAsync` atau `tester.pump(Duration)`, repository palsu mencatat panggilan): tanpa laporan, `flushLastRead()` tidak menulis; `onVisibleAyahChanged(5)` lalu maju 2 detik tidak menulis, maju sampai 3 detik menulis tepat sekali `AyahRef(1, 5)`; laporan 6 lalu 7 dalam jendela debounce menulis hanya 7; setelah timer menulis 5, `flushLastRead()` tidak menulis ulang; `onVisibleAyahChanged(8)` lalu `flushLastRead()` menulis 8 segera dan timer tidak menulis lagi; membuka surah 1 dengan last read 1:5 menampilkan tepat satu label "Terakhir dibaca" pada ayat 5; `SurahArgs(1, 3)` membuat ayat 3 terlihat; last read di surah lain tidak menandai ayat mana pun; peluncuran pertama (`getLastRead() == null`) tidak melempar; **uji Latin 130%:** layar baca dengan ayat last read pada `TextScaler.linear(1.3)` di 360 × 640 tanpa exception.
- [ ] **Step 2: Jalankan** tes itu. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces.
- [ ] **Step 4: Jalankan** `flutter test` penuh sampai lulus.
- [ ] **Step 5: Commit** `feat: track and highlight last read ayah`.

### Task 10: Tab Bookmark

**Files:**
- Create: `lib/app/modules/bookmarks/controllers/bookmarks_controller.dart`, `views/bookmarks_tab.dart`, `widgets/bookmark_tile.dart`
- Modify: `lib/app/modules/quran_list/views/quran_list_view.dart` (tab ketiga "Bookmark")
- Test: `test/app/modules/bookmarks/bookmarks_test.dart`

**Interfaces:**
- Produces: `BookmarksController`: `Rx<UiState<List<BookmarkItem>>> items`, `void load()`. `class BookmarkItem { final Bookmark bookmark; final Surah surah; final Ayah ayah; }`. `BookmarkTile({required BookmarkItem item, required VoidCallback onTap})`: `<Nama Latin> · ayat <n>` dan terjemahan maksimal dua baris dengan elipsis. Mengetuk membuka `Routes.surah` dengan `SurahArgs(surah, ayat)`. Daftar dimuat ulang saat kembali dari layar baca. `EmptyState` berjudul "Belum ada bookmark".

- [ ] **Step 1: Tulis tes yang gagal:** tiga bookmark tampil terbaru dulu; daftar kosong menampilkan "Belum ada bookmark"; bookmark ke ayat yang tidak ada di repository (`getAyah` melempar `ContentUnavailable`) dilewati dan yang lain tetap tampil; mengetuk tile membuka route dengan `SurahArgs` yang benar; setelah `toggleBookmark` dari layar baca lalu kembali, daftar diperbarui; kegagalan membaca menghasilkan `ErrorState`; **uji Latin 130%:** tab Bookmark berisi tiga bookmark pada `TextScaler.linear(1.3)` di 360 × 640 tanpa exception.
- [ ] **Step 2: Jalankan** tes itu. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces.
- [ ] **Step 4: Jalankan** `flutter test` penuh dan `flutter analyze`.
- [ ] **Step 5: Commit** `feat: list saved ayah in bookmark tab`.

### Task 11: Aset font Plus Jakarta Sans (tidak memblokir task lain)

**Files:**
- Modify: `pubspec.yaml` (bagian `flutter.fonts`)
- Create (oleh pemilik proyek): `assets/fonts/` berisi file Plus Jakarta Sans (bobot 400, 500, 600) dan teks lisensi OFL
- Test: `test/app/core/theme/font_assets_test.dart`

**Interfaces:**
- Produces: family `Plus Jakarta Sans` terdaftar di `pubspec.yaml`. Family `LPMQ Isep Misbah` sengaja belum terdaftar (menunggu Q6).

- [ ] **Step 1: Periksa prasyarat.** Jika `assets/fonts/` belum berisi file Plus Jakarta Sans dan lisensinya, LEWATI task ini, catat di `docs/STATUS.md` bahwa font Latin belum terpasang, dan lanjut ke Task 12. Jangan mengunduh font sendiri.
- [ ] **Step 2: Tulis tes yang gagal.** Tes membaca `pubspec.yaml` dan memastikan family `Plus Jakarta Sans` terdaftar dengan bobot 400, 500, 600, setiap file yang dideklarasikan ada di disk, dan `LPMQ Isep Misbah` tidak terdaftar.
- [ ] **Step 3: Daftarkan font** di `pubspec.yaml`.
- [ ] **Step 4: Jalankan** `flutter test` penuh, lalu catat sumber dan tanggal unduh font di `docs/STATUS.md` bagian Catatan Teknis.
- [ ] **Step 5: Commit** `build: bundle plus jakarta sans font`.

### Task 12: Dokumen dan uji perangkat

**Files:**
- Modify: `docs/STATUS.md`, `docs/PRD.md` (Keputusan 8), `docs/specs/2026-11-09-nura-v1-design.md` (bila ada keputusan yang mengubah spec)

- [ ] **Step 1: Perbarui `docs/STATUS.md`:** baris fitur Al-Qur'an offline (yang selesai dan yang menunggu Q4), baris Desain UI (tema dari token, font Latin, font Arab masih fallback sampai Q6), dan Langkah Berikutnya. Rapikan PRD 5.1: ukuran font terjemahan tidak diatur pengguna.
- [ ] **Step 2: Jalankan** `flutter analyze` dan `flutter test`; catat jumlah tes di STATUS.
- [ ] **Step 3: Commit** `docs: update status after phase 2`.
- [ ] **Step 4: Uji perangkat oleh pemilik proyek** (AGENTS: fitur UI selesai hanya setelah dijalankan di perangkat). Daftar periksa: daftar 114 surah tampil dan bisa digulir; baca Al-Baqarah sampai akhir tanpa jank; tafsir panjang bisa digulir; Arab 40 dan teks sistem besar tidak terpotong; **tanda waqaf dan tanda baca Al-Qur'an tampil lengkap pada font fallback sistem** (catat bila ada kotak atau tanda hilang, itu bahan keputusan Q6); tema gelap bertahan setelah aplikasi ditutup; bookmark dan last read bertahan setelah restart; last read tersimpan setelah berhenti menggulir beberapa detik; mode pesawat tidak memengaruhi apa pun. Catat hasilnya di STATUS.

---

## Di Luar Rencana Ini

- Pencarian Al-Qur'an (SearchField, layar 10, cuplikan hasil): Fase 4. Aturan cuplikan sudah ada di spec bagian 5.5.
- Mendaftarkan font LPMQ Isep Misbah: setelah Q6 selesai. Nama family sudah dipakai di tema, jadi cukup menambah file dan deklarasi `pubspec.yaml`.
- Isi Beranda (kartu waktu sholat, kartu harian, LastReadCard): Fase 5 dan 6.
- Audio, bagikan ayat, dan layar hadis: Fase 7, tertunda, dan Fase 3.
- Data meta (`surah_info.json`, `juz.json`): menunggu Q4. Kode Fase 2 sudah menangani ketiadaannya.
