# Nura Fase 3 (Hadis): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sembilan kitab hadis bisa dibaca penuh secara offline: daftar kitab, daftar hadis dengan paging 30 per halaman, detail hadis (Arab dan terjemahan, termasuk hadis yang sangat panjang), dan bookmark hadis di tab Bookmark yang sudah ada.

**Architecture:** `HadithRepository` membaca `content.db` read-only. Implementasi produksi menjalankan query di satu isolate pekerja berumur panjang dengan koneksi read-only sendiri (`sqlite3` tidak bisa berbagi handle antar isolate); implementasi di proses yang sama dipakai tes dan sebagai acuan kontrak. Controller GetX dengan `UiState<T>` mengikuti pola Fase 2. Bookmark hadis memakai tabel `bookmark` yang sudah ada (`kind = 'hadith'`).

**Tech Stack:** Flutter, GetX, `sqlite3` (sudah ada), `dart:isolate`. Tidak ada paket baru.

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (bagian 3.5, 4, 5.1–5.3, 5.6, 9, 10, 11 Fase 3). Desain: `docs/design/HANDOFF-flutter.md` dan brief (bagian 4). Baca juga `AGENTS.md` dan `docs/STATUS.md` (Langkah Berikutnya, Q7, Q8).

## Fakta data (diukur pada `assets/db/content.db`, 2026-11-15)

| Hal | Nilai |
|---|---|
| Kitab dan jumlah hadis | Bukhari 6.638, Muslim 4.930, Abu Daud 4.419, Tirmidzi 3.625, Nasa'i 5.364, Ibnu Majah 4.285, Ahmad 4.305, Malik 1.587, Darimi 2.949 (total 38.102) |
| Teks Arab terpanjang | 8.724 karakter (Muslim No. 4973); berikutnya 8.720 (Bukhari No. 4066) dan 8.719 (Ahmad No. 18152) |
| Terjemahan terpanjang | 16.384 karakter; median 580, persentil 99 sekitar 3.077 |
| Teks terpotong di sumber | **19 hadis terpotong di JSON sumber pada batas 16.384 byte UTF-8, dan putus di tengah kata**: 19 teks Arab (16.374–16.384 byte; terpendek yang terdampak 16.374, tidak ada yang berada di 16.300–16.373 byte) dan 7 terjemahan (tepat 16.384 byte; semuanya termasuk di antara 19 hadis itu). Terjemahan terdampak: Bukhari 2529, 4066, 3826; Muslim 3372, 4973, 4974; Ahmad 18152. Arab terdampak antara lain Darimi 1778 (hanya Arab), Ahmad 1649, 17165, 21460, Bukhari 2467, 4381, 3616, Muslim 2137, 5235, 5328, Abu Daud 1628, Ibnu Majah 3065. Panjang dalam karakter tidak bisa dipakai untuk mendeteksinya (Muslim 4974: 16.382 karakter, Bukhari 3826: 16.378 karakter). Terjemahan Bukhari 4381 dan 3616 (16.092 dan 16.018 byte) berakhir wajar, tetapi Arab keduanya terpotong (Q12) |
| Baris kosong | Tidak ada terjemahan atau Arab kosong |
| Baris baru | 4 terjemahan berisi `\n`; tidak ada Arab |
| Nomor tidak berurutan | Ada celah di semua kitab (Bukhari 370, Muslim 432, Abu Daud 171, Tirmidzi 266, Nasa'i 298, Ibnu Majah 46, Malik 7, Darimi 418). **Ahmad: nomor sampai 26.363 dengan hanya 4.305 baris** |
| Indeks | `UNIQUE (book_slug, number)` pada tabel `hadith` |

## Keputusan terbuka dan asumsi plan

Desain belum memuat layar hadis (putaran desain 2). Plan memakai asumsi di kolom kanan. Koreksi sebelum eksekusi bila berbeda.

| # | Hal | Asumsi plan |
|---|---|---|
| 1 | Layar hadis belum didesain | Bangun dengan komponen dan bahasa visual yang ada (token, `ListTile`, kartu, bottom sheet). Hasilnya **sementara**: dicatat di STATUS sebagai "menunggu desain putaran 2". Alternatif: tunda Task 6–9 sampai desain ada |
| 2 | Last read hadis | Tidak ada di Fase 3: desain tidak memintanya. Last read tetap hanya untuk ayat |
| 3 | Pratinjau di daftar hadis | Tiga baris pertama terjemahan (awalan 200 karakter dari SQL `substr`, dipotong elipsis oleh `maxLines`). Hanya tampilan; teks tidak diubah. Detail memuat teks penuh |
| 4 | Navigasi di detail | "Sebelumnya" dan "Berikutnya" menurut urutan baris dalam kitab (bukan nomor ± 1, karena nomor berlubang), nonaktif di ujung |
| 5 | Teks terpotong di sumber (Arab dan terjemahan) | Detail menampilkan catatan "Teks hadis ini terpotong di sumber data." bila ukuran UTF-8 teks Arab **atau** terjemahan ≥ 16.374 byte (ambang empiris dari pengukuran sumber, konstanta `sourceTruncationBytes`). Teks tidak diubah. Penyebab dan tindak lanjut (mengambil teks lengkap dari sumber asli) ditulis sebagai Q12 di STATUS dan butuh keputusan Anda karena mengubah `data-source/` |
| 6 | Pengaturan tampilan di detail hadis | Detail memakai preferensi tersimpan (ukuran Arab 20–40, sakelar terjemahan) tanpa tombol pengaturan sendiri; mengubahnya lewat layar baca Al-Qur'an. Menambah tombol pengaturan di detail butuh refactor sheet |
| 7 | Isolate | Satu pekerja berumur panjang dengan koneksi read-only sendiri; dibuka saat bootstrap, ditutup saat gagal. Tes widget memakai repository palsu; kontrak yang sama diuji pada implementasi isolate dan implementasi biasa |
| 8 | Tab Bookmark | Satu daftar gabungan ayat dan hadis, terbaru dulu. Tile hadis: `HR. <Kitab> No. <nomor>` dan terjemahan dua baris |
| 9 | Aksi di detail hadis | Bookmark dan salin. Format salin: Arab, baris kosong, terjemahan, baris kosong, `HR. <Kitab> No. <nomor>`. Tanpa bagikan dan audio |
| 10 | Rujukan | Format `HR. <Nama Kitab> No. <nomor>` (nama dari tabel `hadith_book`), seperti handoff |
| 11 | `UserDataUnavailable` | Dikerjakan di Task 2 (tindak lanjut STATUS): semua metode `SqliteUserRepository` membungkus `SqliteException` |
| 12 | Tindak lanjut Fase 2 lain | Last read separuh kartu terlihat, last read gulir scrollbar dan pembaca layar, tinggi sheet saat rotasi: **di luar** Fase 3 |

## Global Constraints

- Branch kerja `feat/phase-3-hadith`. Selesai: `merge --no-ff` ke `main` setelah review akhir. Jangan push tanpa konfirmasi.
- Tidak mengubah `data-source/`, skema `content.db`, atau `lib/content_pipeline/`. `content.db` hanya dibuka read-only (AGENTS aturan 4). Skema `user.db` tidak berubah (tabel `bookmark` sudah mendukung `kind = 'hadith'`: `ref_a` = slug kitab sebagai teks, `ref_b` = nomor hadis).
- Teks Arab dan terjemahan hadis ditampilkan persis seperti di database: tanpa `trim`, normalisasi, atau penggantian karakter (aturan 3). Awalan pratinjau dari `substr` hanya untuk tampilan daftar. Tidak ada teks Arab yang diketik di kode atau tes produksi.
- Paging: 30 baris per halaman, keyset pada `(book_slug, number)` dengan `LIMIT`, bukan `OFFSET`. Nomor hadis berlubang, jadi tidak boleh ada asumsi nomor berurutan.
- Tidak ada akses jaringan dan tidak ada paket baru. Query hadis lewat isolate pekerja (spec 3.5).
- Nilai tema dari `docs/design/tokens.json`, kode di `lib/app/core/theme/`. Material 3. Target sentuh minimal 48 × 48. Status tidak hanya lewat warna.
- **Uji Latin 130%:** setiap layar baru punya widget test dengan `TextScaler.linear(1.3)` pada 360 × 640 yang gagal bila `tester.takeException()` tidak null. Detail hadis juga diuji pada Arab 40.
- Pola AGENTS.md: view hanya menampilkan state controller; data dimuat di `onInit` atau aksi pengguna, tidak ada future di `build()`; loading, kosong, dan error di setiap layar; observable dibaca di dalam `Obx`, bukan di `itemBuilder`; galat tidak dilempar ke UI; model immutable; satu class publik per file (model kecil dan hierarki sealed boleh berbagi file); tanpa `!` dan `ignore_for_file`.
- Teks UI dalam Bahasa Indonesia. Commit Bahasa Inggris (Conventional Commits). `flutter analyze` bersih dan `flutter test` lulus sebelum setiap commit. `flutter test` butuh `assets/db/content.db` lokal (`tool/prepare_content.sh`); tes memakai fixture atau database kecil buatan tes, bukan database penuh.
- Keputusan baru yang mengubah spec, skema, atau dependency: berhenti dan tanya pemilik proyek.

## Review Focus

1. **Hadis terpanjang.** Arab sampai 8.724 karakter dan terjemahan sampai 16.384, dengan Arab 40 dan Latin 130% pada 360 × 640: tidak ada overflow, bisa digulir sampai karakter terakhir, tanpa pemotongan `maxLines`, dan kerangka pertama muncul cepat. Ukur pada database asli (skrip scratch) dan laporkan. Diuji di Task 8.
2. **Teks terpotong di sumber.** 19 hadis (Arab dan/atau terjemahan) terpotong pada 16.384 byte: teks tidak boleh diubah, catatan tampil untuk salah satu kolom yang terpotong (termasuk hadis yang hanya Arab-nya terpotong, Darimi 1778, dan terjemahan yang panjang karakternya di bawah 16.384, Muslim 4974), dan tidak tampil untuk hadis yang tidak terpotong (uji dengan hadis sintetis 16.373 byte di kedua kolom). Deteksi memakai byte UTF-8, bukan jumlah karakter. Diuji di Task 3 dan 8.
3. **Nomor berlubang.** "Sebelumnya/Berikutnya" dan paging memakai urutan baris. Bookmark ke nomor yang tidak ada dilewati tanpa crash. Ahmad (nomor sampai 26.363, 4.305 baris) diuji. Diuji di Task 3, 7, 8, 9.
4. **Batas halaman.** Tepat 30 dan 60 baris, halaman terakhir, kitab kosong, dan gulir cepat yang memicu pemuatan halaman berulang: tidak ada hadis ganda atau terlewat. Diuji di Task 7.
5. **Siklus hidup isolate.** Pekerja yang ditutup atau mati harus menjadi `ContentUnavailable` (bukan layar menggantung), dan tidak bocor setelah ditutup. Diuji di Task 4.

---

## Struktur File

```
lib/app/
  app_bootstrap.dart                           (ubah: daftarkan HadithRepository, tutup pekerja bila gagal)
  core/errors.dart                             (ubah: UserDataUnavailable)
  data/
    models/hadith_book.dart, hadith.dart (HadithRef, HadithSummary, Hadith, HadithPage), bookmark.dart (ubah)
    repositories/hadith_repository.dart, sqlite_hadith_repository.dart, isolate_hadith_repository.dart,
                 user_repository.dart, sqlite_user_repository.dart (ubah)
    sources/content_database.dart              (ubah: expose path file)
    sources/hadith_query_worker.dart           isolate pekerja
  modules/
    hadith_books/{bindings,controllers,views,widgets}   tab Hadis: daftar kitab
    hadith_list/{bindings,controllers,views,widgets}    daftar hadis per kitab
    hadith_detail/{bindings,controllers,views,widgets}  detail hadis
    bookmarks/...                              (ubah: hadis)
    shell/...                                  (ubah: tab Hadis)
  routes/app_routes.dart, app_pages.dart       (ubah)
test/support/hadith_db.dart                    database kecil buatan tes (contentSchemaDdl)
test/support/fake_repositories.dart            (ubah: FakeHadithRepository)
```

---

### Task 1: Tutup celah tes review Task 11 dan 13

**Files:**
- Modify: `test/app/core/theme/font_assets_test.dart`, `test/app/modules/quran_detail/quran_detail_test.dart`

**Interfaces:**
- Produces: tes saja, tanpa perubahan kode produksi.

- [ ] **Step 1: Perkuat tes font.** Tiap bobot terikat ke berkasnya: `PlusJakartaSans-Regular.ttf` ↔ 400, `PlusJakartaSans-Medium.ttf` ↔ 500, `PlusJakartaSans-SemiBold.ttf` ↔ 600 (cocokkan pasangan `asset:` dan `weight:` yang bersebelahan, bukan keberadaan angka di mana saja). Jaga LPMQ lebih ketat: tidak ada family `LPMQ`, tidak ada jalur `assets/fonts/LPMQ`, dan tidak ada kata `Isep` di `pubspec.yaml`. Tambah tes yang membuktikan pasangan salah gagal (mis. string pubspec sintetis dengan Medium dipetakan ke 700 ditolak oleh fungsi pemeriksa yang dipakai tes).
- [ ] **Step 2: Kunci elipsis subjudul.** Pada tes 130% app bar layar baca dengan `nameId` panjang, tegaskan `tester.widget<Text>(find.textContaining(<nameId panjang>))` memiliki `maxLines == 1` dan `overflow == TextOverflow.ellipsis`, selain tidak ada exception.
- [ ] **Step 3: Jalankan** `flutter test test/app/core/theme test/app/modules/quran_detail`. Harapan: LULUS. Buktikan kedua penjaga bekerja dengan mengubah sementara (di scratch, bukan di repo) bobot atau `maxLines` dan memastikan tes gagal; laporkan hasilnya.
- [ ] **Step 4: Commit** `test: tie font weights to files and lock subtitle ellipsis`.

### Task 2: `UserDataUnavailable` untuk `SqliteUserRepository`

**Files:**
- Modify: `lib/app/core/errors.dart`, `lib/app/data/repositories/sqlite_user_repository.dart`
- Test: `test/app/data/sqlite_user_repository_test.dart`

**Interfaces:**
- Produces: `class UserDataUnavailable implements Exception { const UserDataUnavailable(this.message); final String message; }`. Semua metode `UserRepository` yang ada melempar `UserDataUnavailable` (bukan `SqliteException` atau `StateError` dari database tertutup). `toggleBookmark` tidak lagi menutupi galat asli bila `ROLLBACK` sendiri gagal.

- [ ] **Step 1: Tulis tes yang gagal:** pada `UserDatabase` yang sudah ditutup, setiap metode publik (`toggleBookmark`, `listBookmarks`, `bookmarkedAyahNumbers`, `bookmarkedSurahNumbers`, `getLastRead`, `setLastRead`, `getReadingPrefs`, `setArabicFontSize`, `setShowTranslation`, `getThemeMode`, `setThemeMode`) melempar `UserDataUnavailable`; kegagalan di tengah `toggleBookmark` (jam yang melempar) melempar galat asli (bukan galat `ROLLBACK`) dan toggle berikutnya tetap berfungsi.
- [ ] **Step 2: Jalankan** `flutter test test/app/data/sqlite_user_repository_test.dart`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** pembungkus tunggal (seperti `_select` di `SqliteQuranRepository`) yang memetakan `SqliteException` dan `StateError` dari database tertutup; bungkus `ROLLBACK` dengan `try/catch` sebelum `rethrow`.
- [ ] **Step 4: Jalankan** `flutter test` penuh. Controller Fase 2 sudah menangkap secara umum, jadi tidak ada perubahan di sana; bila ada tes yang mengandalkan tipe galat lama, sesuaikan.
- [ ] **Step 5: Commit** `fix: wrap user database errors in UserDataUnavailable`.

### Task 3: Model hadis dan `HadithRepository`

**Files:**
- Create: `lib/app/data/models/hadith_book.dart`, `hadith.dart`, `lib/app/data/repositories/hadith_repository.dart`, `sqlite_hadith_repository.dart`, `test/support/hadith_db.dart`
- Test: `test/app/data/sqlite_hadith_repository_test.dart`

**Interfaces:**
- Consumes: `ContentDatabase` (`raw`), `ContentUnavailable`, `contentSchemaDdl` (`lib/content_pipeline/content_schema.dart`).
- Produces:
  - `class HadithBook { slug, name, hadithCount, sortOrder }`, `class HadithRef { const HadithRef(this.slug, this.number); }` (dengan `==` dan `hashCode`), `class HadithSummary { ref, preview, length }` (`preview` = awalan 200 karakter terjemahan, `length` = panjang terjemahan penuh dalam UTF-16 code unit seperti kolom `translation_length`), `class Hadith { ref, bookName, arab, translation, translationLength, arabTruncated, translationTruncated }` (kedua penanda dihitung di SQL: `length(CAST(arab AS BLOB)) >= sourceTruncationBytes`, dan sama untuk terjemahan; `const int sourceTruncationBytes = 16374` di `sqlite_hadith_repository.dart` dengan komentar bahwa ambang ini empiris dari pengukuran sumber), `class HadithPage { items, hasMore }`. Semua immutable.
  - `abstract interface class HadithRepository { Future<List<HadithBook>> listBooks(); Future<HadithPage> listPage(String slug, {int afterNumber = 0, int limit = 30}); Future<Hadith> getHadith(HadithRef ref); Future<HadithRef?> neighbor(HadithRef ref, {required bool next}); }`. Semua melempar `ContentUnavailable` bila kitab atau hadis tidak ada atau terjadi `SqliteException`/`StateError`. `neighbor` mengembalikan `null` di ujung kitab (dipakai controller, tidak sampai ke UI).
  - `class SqliteHadithRepository implements HadithRepository { SqliteHadithRepository(ContentDatabase db); }`. `listPage` memakai keyset `number > ? ORDER BY number LIMIT limit + 1` untuk menentukan `hasMore`. `neighbor` memakai `number > ?`/`number < ?` dengan `ORDER BY`, bukan nomor ± 1.
  - `test/support/hadith_db.dart`: pembuat `ContentDatabase` kecil dari `contentSchemaDdl` dengan baris hadis yang ditentukan tes.

- [ ] **Step 1: Tulis tes yang gagal** (database buatan tes): `listBooks()` urut `sort_order` dengan nama dan jumlah; `listPage` mengembalikan tepat 30 baris dan `hasMore == true` untuk kitab 65 baris, lalu halaman kedua 30 dan ketiga 5 dengan `hasMore == false`, tanpa duplikat atau terlewat saat disambung lewat `afterNumber` terakhir; kitab dengan tepat 30 baris menghasilkan `hasMore == false`; kitab kosong menghasilkan halaman kosong; nomor berlubang (1, 2, 50, 51, 26363) diurutkan numerik (bukan teks: "10" sebelum "9" tidak boleh); `preview` adalah awalan persis 200 karakter terjemahan tanpa `trim`, dan `length` sama dengan panjang penuh; `getHadith` mengembalikan `arab` dan `translation` persis (entri sintetis berisi spasi di akhir dan U+200C, serta terjemahan 16.384 karakter) dan `bookName` dari tabel kitab; penanda terpotong: Arab sintetis 16.374 byte (8.187 huruf dua byte) memberi `arabTruncated == true` sedangkan 16.373 byte `false`; terjemahan ASCII tepat 16.374 byte `true` dan 16.373 `false`; terjemahan yang panjangnya 16.382 karakter tetapi 16.384 byte (berisi tanda kutip tiga byte) `true`; terjemahan panjang 16.092 byte `false`; Arab terpotong dengan terjemahan utuh hanya menyalakan `arabTruncated`; `neighbor` dari nomor 2 ke berikutnya adalah 50 dan dari 50 ke sebelumnya adalah 2, `null` di ujung; `getHadith` dan `listPage` untuk slug atau nomor yang tidak ada melempar `ContentUnavailable`; database tertutup membuat semua metode melempar `ContentUnavailable`.
- [ ] **Step 2: Jalankan** `flutter test test/app/data/sqlite_hadith_repository_test.dart`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces, SQL berparameter.
- [ ] **Step 4: Jalankan tes** sampai lulus, lalu `flutter analyze`.
- [ ] **Step 5: Commit** `feat: add hadith repository over content db`.

### Task 4: Isolate pekerja dan registrasi

**Files:**
- Create: `lib/app/data/sources/hadith_query_worker.dart`, `lib/app/data/repositories/isolate_hadith_repository.dart`
- Modify: `lib/app/data/sources/content_database.dart` (properti `final File file`), `lib/app/app_bootstrap.dart`, `test/app/bootstrap_test.dart`
- Test: `test/app/data/isolate_hadith_repository_test.dart`

**Interfaces:**
- Consumes: `HadithRepository`, `SqliteHadithRepository`, `ContentDatabase.file`.
- Produces: `class IsolateHadithRepository implements HadithRepository { static Future<IsolateHadithRepository> start(File contentDb); Future<void> close(); }`. Pekerja membuka koneksi read-only sendiri di isolate dan menjalankan `SqliteHadithRepository` di sana; permintaan dan jawaban lewat `SendPort` (hanya data sederhana: string, angka, daftar, peta). Galat di pekerja kembali sebagai `ContentUnavailable`. `close()` menutup koneksi dan mematikan isolate; pemanggilan sesudahnya melempar `ContentUnavailable`. Bila isolate mati tiba-tiba, permintaan yang menunggu selesai dengan `ContentUnavailable` (tidak menggantung). `bootstrap()` mendaftarkan `HadithRepository` (`permanent: true`) setelah database terbuka dan menutup pekerja pada jalur gagal.

- [ ] **Step 1: Tulis tes yang gagal** (tes biasa `test()`, bukan widget test, database tulis ke berkas sementara): hasil `listBooks`, `listPage` (dua halaman berurutan), `getHadith`, dan `neighbor` identik dengan `SqliteHadithRepository` pada database yang sama (kontrak sama); 20 permintaan serentak semuanya terjawab benar; slug yang tidak ada melempar `ContentUnavailable` (bukan galat isolate mentah); setelah `close()` panggilan baru melempar `ContentUnavailable` dan tidak ada isolate tersisa (`Isolate` pekerja berakhir: tes menunggu sinyal keluar); isolate yang dimatikan paksa saat ada permintaan tertunda membuat permintaan itu selesai dengan `ContentUnavailable` dalam batas waktu; `bootstrap` sukses mendaftarkan `HadithRepository`, dan bootstrap yang gagal tidak meninggalkan pekerja hidup.
- [ ] **Step 2: Jalankan** `flutter test test/app/data/isolate_hadith_repository_test.dart`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces: satu `ReceivePort` pemulihan, peta `id → Completer`, `Isolate.spawn` dengan `onExit` dan `onError` yang menyelesaikan semua `Completer` tertunda dengan `ContentUnavailable`.
- [ ] **Step 4: Jalankan** `flutter test` penuh (tes widget memakai repository palsu, jadi tidak menyentuh isolate).
- [ ] **Step 5: Commit** `feat: run hadith queries in a worker isolate`.

### Task 5: Bookmark hadis di `UserRepository`

**Files:**
- Modify: `lib/app/data/models/hadith.dart` (bila `HadithRef` perlu dipakai), `lib/app/data/models/bookmark.dart`, `lib/app/data/repositories/user_repository.dart`, `sqlite_user_repository.dart`, `test/support/fake_repositories.dart`
- Test: `test/app/data/sqlite_user_repository_test.dart`

**Interfaces:**
- Consumes: `HadithRef`, `UserDataUnavailable` (Task 2).
- Produces: `class HadithBookmark { final HadithRef ref; final DateTime createdAt; }` dan metode baru di `UserRepository`: `bool toggleHadithBookmark(HadithRef ref); List<HadithBookmark> listHadithBookmarks(); Set<int> bookmarkedHadithNumbers(String slug);`. Metode ayat tidak berubah. Disimpan di tabel `bookmark` dengan `kind = 'hadith'`, `ref_a` = slug, `ref_b` = nomor; urutan `created_at DESC, id DESC`; transaksi `BEGIN IMMEDIATE` seperti `toggleBookmark`.

- [ ] **Step 1: Tulis tes yang gagal:** toggle dua kali memberi `true` lalu `false` tanpa menggandakan baris; ketuk toggle lima kali berturut-turut berakhir `true` dengan satu baris; slug dengan tanda hubung (`abu-daud`, `ibnu-majah`) tersimpan dan terbaca benar; bookmark ayat dan hadis dengan `ref_b` sama tidak saling mengganggu (ayat 2:5 dan `bukhari:5` berdiri sendiri); `listHadithBookmarks` terbaru dulu dengan jam menaik, dan dengan jam yang sama urut `id DESC`; `bookmarkedHadithNumbers('bukhari')` hanya memuat nomor kitab itu; nilai bertahan setelah `UserDatabase` dibuka ulang; semua metode baru melempar `UserDataUnavailable` pada database tertutup; `FakeUserRepository` mengikuti perilaku yang sama (termasuk `failure`).
- [ ] **Step 2: Jalankan** `flutter test test/app/data/sqlite_user_repository_test.dart`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces.
- [ ] **Step 4: Jalankan** `flutter test` penuh.
- [ ] **Step 5: Commit** `feat: add hadith bookmarks to user repository`.

### Task 6: Tab Hadis (daftar 9 kitab)

**Files:**
- Create: `lib/app/modules/hadith_books/bindings/hadith_books_binding.dart`, `controllers/hadith_books_controller.dart`, `views/hadith_books_view.dart`, `widgets/hadith_book_tile.dart`
- Modify: `lib/app/modules/shell/views/shell_view.dart` (tab Hadis memakai `HadithBooksView`, bukan `ComingSoonTab`), `lib/app/routes/app_routes.dart` (`Routes.hadithList = '/hadith/list'`), `test/support/fake_repositories.dart` (`FakeHadithRepository`)
- Test: `test/app/modules/hadith_books/hadith_books_test.dart`, `test/app/modules/shell/shell_view_test.dart`

**Interfaces:**
- Consumes: `HadithRepository.listBooks`, `UiState`, `EmptyState`, `ErrorState`.
- Produces: `class HadithListArgs { const HadithListArgs(this.slug, this.bookName); final String slug; final String bookName; }`. `HadithBooksController`: `Rx<UiState<List<HadithBook>>> books`, `void load()` (di `onInit`, dengan loading terlihat dulu). `HadithBookTile({required HadithBook book, required VoidCallback onTap})`: nama kitab dan `<n> hadis` (angka dengan pemisah ribuan Indonesia, mis. "6.638 hadis"). Mengetuk membuka `Routes.hadithList` dengan `HadithListArgs`. `FakeHadithRepository` di `test/support` (data dan kegagalan dapat diatur).

- [ ] **Step 1: Tulis tes yang gagal:** sembilan kitab tampil dengan nama dan jumlah ("6.638 hadis" untuk Bukhari); urutan mengikuti `sortOrder`; `ContentUnavailable` memunculkan `ErrorState` dan "Coba lagi" memuat ulang; daftar kitab kosong menampilkan `EmptyState`; mengetuk kitab membuka route dengan `HadithListArgs` yang benar; tab Hadis di shell menampilkan daftar kitab (bukan "Segera hadir"); **uji Latin 130%:** daftar kitab pada `TextScaler.linear(1.3)` di 360 × 640 tanpa exception.
- [ ] **Step 2: Jalankan** `flutter test test/app/modules/hadith_books test/app/modules/shell`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces; binding didaftarkan seperti `QuranListBinding` di shell; nilai observable dibaca di dalam `Obx`.
- [ ] **Step 4: Jalankan** `flutter test` penuh.
- [ ] **Step 5: Commit** `feat: list hadith books in hadith tab`.

### Task 7: Daftar hadis per kitab dengan paging

**Files:**
- Create: `lib/app/modules/hadith_list/bindings/hadith_list_binding.dart`, `controllers/hadith_list_controller.dart`, `views/hadith_list_view.dart`, `widgets/hadith_list_tile.dart`
- Modify: `lib/app/routes/app_pages.dart` (daftarkan `Routes.hadithList`), `lib/app/routes/app_routes.dart` (`Routes.hadithDetail = '/hadith/detail'`), `test/support/fake_repositories.dart`
- Test: `test/app/modules/hadith_list/hadith_list_test.dart`

**Interfaces:**
- Consumes: `HadithRepository.listPage`, `UserRepository.bookmarkedHadithNumbers`, `HadithListArgs`.
- Produces: `class HadithDetailArgs { const HadithDetailArgs(this.slug, this.number); final String slug; final int number; }`. `HadithListController(HadithListArgs args)`: `Rx<UiState<List<HadithSummary>>> items`, `RxBool hasMore`, `RxBool loadingMore`, `RxSet<int> bookmarked`, `void load()`, `Future<void> loadMore()`. `loadMore` abaikan bila sedang memuat atau `hasMore == false` (tidak ada pemuatan ganda); halaman berikutnya memakai `afterNumber` = nomor terakhir yang sudah dimuat. Kegagalan `loadMore` tidak membuang item yang sudah ada: tampil baris "Gagal memuat, ketuk untuk mencoba lagi". `HadithListTile`: `No. <nomor>`, tiga baris pratinjau terjemahan, ikon bookmark bila ber-bookmark. Mengetuk membuka `Routes.hadithDetail` dan menyegarkan penanda saat kembali. App bar: nama kitab. Daftar memakai `ListView.builder` dan memicu `loadMore` mendekati akhir.

- [ ] **Step 1: Tulis tes yang gagal:** halaman pertama 30 item; menggulir ke akhir memuat halaman kedua tanpa duplikat; 65 hadis menghasilkan 30, 60, lalu 65 item dan `hasMore == false`; tepat 60 hadis berakhir tanpa memuat halaman ketiga yang kosong secara berulang; pemicu `loadMore` berkali-kali berturut-turut hanya memuat satu halaman (repository palsu menghitung panggilan); kegagalan `loadMore` mempertahankan 30 item dan menampilkan baris coba lagi, yang bila diketuk memuat halaman berikutnya; kitab kosong menampilkan `EmptyState`; `ContentUnavailable` pada halaman pertama menampilkan `ErrorState` dengan "Coba lagi"; nomor berlubang (1, 2, 50) tampil sesuai nomor aslinya; pratinjau persis awalan dari repository (tanpa `trim`); penanda bookmark sesuai `bookmarkedHadithNumbers` dan menyegar setelah kembali dari detail (data diubah antara push dan pop); mengetuk item membuka route dengan `HadithDetailArgs`; **uji Latin 130%:** daftar dengan pratinjau panjang pada `TextScaler.linear(1.3)` di 360 × 640 tanpa exception.
- [ ] **Step 2: Jalankan** `flutter test test/app/modules/hadith_list`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces; observable dibaca di dalam `Obx`; galat apa pun dari `UserRepository` ditangkap secara umum dan tidak sampai ke UI.
- [ ] **Step 4: Jalankan** `flutter test` penuh.
- [ ] **Step 5: Commit** `feat: page through hadith of a book`.

### Task 8: Detail hadis

**Files:**
- Create: `lib/app/modules/hadith_detail/bindings/hadith_detail_binding.dart`, `controllers/hadith_detail_controller.dart`, `views/hadith_detail_view.dart`, `widgets/hadith_text_card.dart`
- Modify: `lib/app/routes/app_pages.dart` (daftarkan `Routes.hadithDetail`), `test/support/fake_repositories.dart`
- Test: `test/app/modules/hadith_detail/hadith_detail_test.dart`

**Interfaces:**
- Consumes: `HadithRepository.getHadith`/`neighbor`, `UserRepository` (`toggleHadithBookmark`, `bookmarkedHadithNumbers`, `getReadingPrefs`), `HadithDetailArgs`.
- Produces: `HadithDetailController(HadithDetailArgs args)`: `Rx<UiState<Hadith>> state`, `RxBool bookmarked`, `Rx<ReadingPrefs> prefs` (awal: nilai default; dibaca dari repository di `load()` di dalam `try`, seperti pelajaran Fase 2), `RxBool hasPrevious`, `RxBool hasNext`, `void load()`, `Future<void> goTo({required bool next})`, `void toggleBookmark()`, `Future<void> copy()`. App bar: judul `<bookName>`, subjudul `No. <nomor>` (maksimal satu baris, elipsis). Isi dalam satu `SingleChildScrollView`: teks Arab (`textDirection: rtl`, gaya `arabicReading` berukuran `prefs.arabicFontSize`), terjemahan bila `prefs.showTranslation`, lalu catatan "Teks hadis ini terpotong di sumber data." hanya bila `arabTruncated || translationTruncated` (penanda dari repository, bukan panjang karakter). Tombol "Sebelumnya" dan "Berikutnya" (nonaktif di ujung, bisa turun baris) memanggil `goTo`; pindah hadis mengembalikan posisi gulir ke atas. Format salin: `<arab>\n\n<terjemahan>\n\nHR. <bookName> No. <nomor>`; snackbar "Hadis disalin". Galat penyimpanan bookmark atau clipboard tidak dilempar ke UI (snackbar "Gagal menyimpan bookmark" atau "Gagal menyalin hadis"; himpunan bookmark tidak berubah bila tulis gagal).

- [ ] **Step 1: Tulis tes yang gagal:** `arab` dan `translation` tampil persis (entri sintetis dengan spasi di akhir dan U+200C, dicari dengan `find.text` string utuh); hadis sintetis Arab 8.724 karakter dan terjemahan 16.384 karakter pada `arabicFontSize == 40` dan `TextScaler.linear(1.3)` di 360 × 640: tanpa exception layout, bisa digulir sampai `maxScrollExtent`, `Text` terjemahan tidak punya `maxLines` maupun elipsis, dan teks akhir terlihat setelah menggulir; catatan terpotong tampil bila hanya `arabTruncated`, bila hanya `translationTruncated`, dan bila keduanya, dan **tidak** tampil bila keduanya `false` (termasuk terjemahan 16.092 karakter); `showTranslation == false` menyembunyikan terjemahan; "Berikutnya" menampilkan hadis berikutnya menurut urutan baris (nomor berlubang: dari 2 ke 50), posisi gulir kembali ke atas, dan tombol nonaktif di ujung kitab; ketuk bookmark dua kali kembali ke "Tambah bookmark" dengan label semantik "Hapus bookmark" di antaranya; kegagalan tulis bookmark mempertahankan himpunan dan menampilkan snackbar; `copy` menaruh format di atas ke clipboard (mock channel) dan kegagalan clipboard menampilkan snackbar; `ContentUnavailable` (termasuk nomor yang tidak ada) menampilkan `ErrorState` dengan "Coba lagi"; argumen route yang hilang menampilkan error (bukan hadis lain); `getReadingPrefs` yang gagal tidak membuat layar merah dan memakai nilai default; **uji Latin 130%** pada hadis biasa di 360 × 640 tanpa exception.
- [ ] **Step 2: Jalankan** `flutter test test/app/modules/hadith_detail`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces. Ukur pada `assets/db/content.db` asli lewat skrip scratch di luar repo (Bukhari 4066, Muslim 4973, Bukhari 2529, dan Darimi 1778 untuk kasus hanya-Arab-terpotong); pastikan juga penanda terpotong di database asli bernilai `true` tepat untuk 19 hadis yang disebut di "Fakta data" (hitung: `SELECT COUNT(*)` pada panjang byte ≥ 16.374 di kolom Arab atau terjemahan harus 19) dan `false` untuk seluruh hadis lain: waktu `getHadith` lewat isolate dan waktu layar muncul; bila satu `Text` terjemahan 16.384 karakter terlalu lambat atau tidak bisa digulir mulus, pecah per paragraf (`\n`) dan laporkan angkanya.
- [ ] **Step 4: Jalankan** `flutter test` penuh dan `flutter analyze`.
- [ ] **Step 5: Commit** `feat: read hadith detail with bookmark and navigation`.

### Task 9: Hadis di tab Bookmark

**Files:**
- Modify: `lib/app/modules/bookmarks/controllers/bookmarks_controller.dart`, `views/bookmarks_tab.dart`, `widgets/bookmark_tile.dart` (atau tile hadis baru), `test/support/fake_repositories.dart`
- Test: `test/app/modules/bookmarks/bookmarks_test.dart`

**Interfaces:**
- Consumes: `UserRepository.listBookmarks`/`listHadithBookmarks`, `QuranRepository`, `HadithRepository.getHadith`.
- Produces: `BookmarkItem` menjadi hierarki sealed `AyahBookmarkItem` dan `HadithBookmarkItem` (model kecil, satu file). `BookmarksController` menggabungkan keduanya, terbaru dulu menurut `createdAt` (seri: ayat sebelum hadis, lalu urutan sumber). Tile hadis: `HR. <Nama Kitab> No. <nomor>` dan terjemahan dua baris; mengetuk membuka `Routes.hadithDetail` dengan `HadithDetailArgs` dan menyegarkan daftar saat kembali. Aturan baca Fase 2 berlaku: baris yang gagal dibaca dilewati (`debugPrint`), semua baris gagal (N > 0) menjadi `ErrorState` "Konten tidak dapat dibaca.", kegagalan membaca daftar menjadi `ErrorState`.

- [ ] **Step 1: Tulis tes yang gagal:** bookmark ayat dan hadis bercampur tampil terbaru dulu menurut `createdAt` (stempel berbeda; satu tes dengan stempel sama memeriksa urutan seri); tile hadis menampilkan `HR. Shahih Bukhari No. 34` dan terjemahan dua baris; mengetuk tile hadis membuka route dengan `HadithDetailArgs` yang benar; bookmark hadis ke nomor yang tidak ada (`ContentUnavailable`) dilewati dan yang lain tetap tampil; hanya bookmark hadis yang gagal semua menghasilkan `ErrorState`; hapus bookmark dari detail lalu kembali memperbarui daftar (data diubah antara push dan pop); `UserDataUnavailable` pada `listHadithBookmarks` menampilkan `ErrorState` dengan coba lagi yang berfungsi; **uji Latin 130%:** tab dengan tiga ayat dan tiga hadis di 360 × 640 tanpa exception.
- [ ] **Step 2: Jalankan** `flutter test test/app/modules/bookmarks`. Harapan: GAGAL.
- [ ] **Step 3: Implementasi** sesuai Interfaces.
- [ ] **Step 4: Jalankan** `flutter test` penuh.
- [ ] **Step 5: Commit** `feat: show saved hadith in bookmark tab`.

### Task 10: Dokumen dan uji perangkat

**Files:**
- Modify: `docs/STATUS.md`, `docs/PRD.md` (bila ada perbedaan), `docs/specs/2026-11-09-nura-v1-design.md` (hanya kontradiksi nyata)

- [ ] **Step 1: Perbarui `docs/STATUS.md`:** baris fitur Hadis (yang selesai dan yang sementara menunggu desain putaran 2), keputusan bertanggal, catatan teknis (jumlah tes, isolate pekerja), dan Langkah Berikutnya. Tambah **Q12**: 19 hadis terpotong di JSON sumber pada batas 16.384 byte UTF-8 (19 teks Arab, 7 terjemahan; daftar lengkapnya di bagian "Fakta data" plan ini), sehingga isi hadis tidak lengkap; terkait Q8 (verifikasi ke sumber asli), memblokir rilis. Tindak lanjut yang diusulkan: ambil teks lengkap ke-19 hadis dari sumber asli dan tambahkan ke `data-source/` (butuh keputusan pemilik proyek karena mengubah sumber data dan checksum). Catat bahwa penomoran hadis berlubang di semua kitab (Ahmad sampai 26.363 dengan 4.305 baris) dan bahwa itu berasal dari sumber.
- [ ] **Step 2: Jalankan** `flutter analyze` dan `flutter test`; catat jumlah tes di STATUS.
- [ ] **Step 3: Commit** `docs: update status after phase 3`.
- [ ] **Step 4: Uji perangkat oleh pemilik proyek.** Daftar periksa: sembilan kitab tampil dengan jumlah benar; Bukhari bisa digulir dengan paging tanpa jank dan tanpa hadis ganda; Ahmad terbuka dan nomornya berlubang tampil apa adanya; buka Bukhari No. 4066 dan Muslim No. 4973 (hadis terpanjang) dan gulir sampai akhir pada Arab 40 dan teks sistem besar; catatan "terpotong di sumber" tampil pada Bukhari No. 2529, pada Darimi No. 1778 (hanya Arab terpotong), pada Muslim No. 4974, dan pada Bukhari No. 4381 (terjemahan utuh tetapi Arab terpotong), serta tidak pada hadis biasa; "Berikutnya/Sebelumnya" melompati nomor yang hilang; bookmark hadis muncul di tab Bookmark bersama ayat dan bertahan setelah restart; mode pesawat tidak memengaruhi apa pun. Catat hasilnya di STATUS.

---

## Di Luar Rencana Ini

- Pencarian hadis dan ayat: Fase 4 (FTS sudah ada di `content.db`).
- Seleksi matan untuk hadis harian, pembatasan Bukhari/Muslim, widget, notifikasi harian: Fase 6.
- Layar hadis final menurut desain putaran 2: setelah desain ada, Task 6–9 disesuaikan.
- Tindak lanjut Fase 2 yang belum dikerjakan: last read hanya menghitung ayat yang minimal separuh kartunya terlihat, last read untuk gulir scrollbar dan pembaca layar, tinggi sheet 90% saat rotasi.
- Tombol pengaturan tampilan di detail hadis, bagikan, dan audio.
