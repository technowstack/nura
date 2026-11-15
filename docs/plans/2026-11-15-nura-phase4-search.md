# Nura Fase 4 (Pencarian): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pencarian ayat (Arab dan terjemahan) dan hadis (Arab dan terjemahan, semua kitab atau satu kitab) lewat indeks FTS5 contentless yang sudah ada, dengan hasil berupa cuplikan bersorotan sesuai spec 5.5, dan pencarian di semua hadis di bawah 1 detik.

**Architecture:** Satu `SearchRepository` (antarmuka) dengan `SqliteSearchRepository` (acuan kontrak, dipakai tes) dan `IsolateSearchRepository` (produksi, isolate pekerja sendiri dengan koneksi read-only, pola Fase 3). Input pengguna diurai oleh fungsi murni (`parseSearchQuery`) yang memakai normalizer builder yang sama. Cuplikan dibangun di sisi pekerja oleh fungsi murni, sehingga teks hadis sampai 16 KB tidak melintasi batas isolate. Controller GetX dengan `UiState<T>` dan satu layar "Cari" (UI sementara untuk hadis dan Arab).

**Tech Stack:** Flutter, GetX, `sqlite3` (FTS5), `dart:isolate`. Tidak ada paket baru. Tidak ada perubahan skema `content.db`.

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (3.2, 3.3, 5.5, 9, 10, 11 Fase 4). Desain: `docs/design/HANDOFF-flutter.md` dan brief (bagian 5, layar 10). Baca juga `AGENTS.md` dan `docs/STATUS.md`.

## Fakta yang diukur (`assets/db/content.db`, 2026-11-15, desktop)

| Hal | Nilai |
|---|---|
| FTS memakai token | `unicode61`, contentless: hanya `MATCH`, `rowid`, urut `rowid`. Tanpa `snippet()`/`highlight()`. `rowid` = `id` tabel utama, dan urutan `id` = urutan baca (ayat global; hadis menurut `sort_order` kitab lalu nomor) |
| Awalan, bukan substring | `sabar*` di terjemahan hadis cocok dengan 91 hadis; `LIKE '%sabar%'` pada kolom asli cocok dengan 256. Kata di tengah ("bersabar") tidak ditemukan FTS. Ini berbeda dari spec 5.5 ("kata cocok = substring"): lihat D1 |
| Kecepatan FTS | `translation : ("sabar"*)` 0 ms; awalan dua huruf sampai 16 ms; **satu huruf `a*` cocok 38.038 dari 38.102 hadis (51 ms hanya untuk menghitung)**; halaman 31 baris dengan `rowid > ?` 0,1 ms |
| Kecepatan `LIKE` (pembanding) | 74 ms (hadis, `%sabar%`), 12 ms (ayat). Tidak dipakai kecuali D1 diputuskan lain |
| Sintaks FTS | Token tanpa tanda kutip yang berisi `*`, `-`, `(` memicu `fts5: syntax error`. Token dalam `"..."` aman, tanda kutip di dalam token ditulis `""`. Penyaring kolom `translation : (...)` dan `arab : (...)` bekerja dengan kurung |
| Empat kasus uji cuplikan | Semuanya kata **"sabar"**: Al-Baqarah 45 (133 karakter, kata di indeks 47), Al-Baqarah 153 (138, indeks 75 dan 134), Ali 'Imran 146 (280, indeks 274), An-Nahl 42 (66, indeks 19). Bentuk yang diminta spec (elipsis belakang; depan dan belakang; hanya depan; tanpa elipsis) cocok dengan data ini |
| Hadis terpotong | 19 hadis berhenti di tengah kata pada 16.384 byte; indeks hanya berisi teks yang tersimpan |

## Keputusan terbuka dan asumsi plan

Asumsi dipakai kecuali pemilik proyek memutuskan lain. **D1 mengubah perilaku yang dijanjikan spec dan butuh jawaban sebelum Task 4.**

| ID | Pertanyaan | Asumsi |
|---|---|---|
| D1 | Spec 5.5 dan brief: "kata cocok = substring". FTS5 `unicode61` hanya cocok awalan token. Pilihan: (a) awalan lewat FTS (sesuai instruksi "lewat FTS yang sudah ada", tanpa perubahan skema); (b) terjemahan lewat `LIKE '%kata%'` pada kolom asli (substring sungguhan, tanpa perubahan skema, terukur 74 ms hadis; Arab tetap awalan karena kolom asli berharakat); (c) tokenizer `trigram` (perubahan skema dan ukuran, butuh persetujuan AGENTS.md) | (a). Sorotan tetap substring di dalam cuplikan, jadi "sabar" di "bersabar" disorot bila ada di cuplikan tetapi dokumen yang hanya memuat "bersabar" tidak ditemukan. Spec 5.5 perlu dikoreksi menjadi "awalan kata" bila (a) dipilih |
| D2 | Panjang minimum kueri | Setelah normalisasi, kurang dari 2 karakter: tidak mencari, tampil keterangan "Ketik minimal 2 huruf". Kosong: tampil keterangan awal. Batas 8 token dan 100 karakter input (sisanya dibuang) |
| D3 | Pilihan kolom | Ada huruf Arab di input: cari kolom `arab` dengan token berhuruf Arab saja (token lain dibuang). Selain itu: kolom `translation` |
| D4 | Letak UI | Satu layar `Routes.search` dengan chip cakupan "Al-Qur'an" dan "Hadis" (+ pilihan kitab untuk Hadis, PRD 5.3). Dibuka dari ikon cari di app bar tab Al-Qur'an dan tab Hadis; cakupan awal mengikuti asalnya. Layar Hadis dan hasil Arab adalah **UI sementara** (belum didesain); hasil terjemahan ayat mengikuti layar 10 |
| D5 | Urutan dan paging | Urut `rowid` (urutan baca), tanpa peringkat relevansi, 30 hasil per halaman dengan keyset `rowid > ?`, gulir tak terbatas, tanpa total hasil. Dikelompokkan per surah (ayat) atau per kitab (hadis) lewat bagian di controller |
| D6 | Sorotan teks Arab | Cuplikan Arab dibuat dengan aturan jendela yang sama pada teks asli; sorotan memakai pemetaan posisi dari teks ternormalisasi ke teks asli (rentang sorotan mencakup harakat yang menempel) |
| D7 | Jeda ketik | 300 ms, hasil usang dibuang dengan token generasi (pola Fase 3) |
| D8 | Isolate | Pekerja pencarian terpisah dari pekerja hadis (supaya pencarian lama tidak menunda paging hadis), dimulai di bootstrap setelah pekerja hadis |
| D9 | Tindak lanjut Fase 3 | Tidak dikerjakan di sini (pekerja mati tidak dihidupkan ulang, `getHadithPreview`). Pekerja pencarian memakai pola yang sama dan mewarisi batasannya |

## Global Constraints

- AGENTS.md: kode dan komentar Inggris, teks pengguna Indonesia; tanpa `ignore_for_file`; hindari `!` (bila terpaksa, beri komentar alasan); data dimuat di `onInit`/aksi pengguna, bukan di `build()`; setiap layar menangani loading, kosong, dan error; `null` tidak sampai ke UI; satu class publik per file (model kecil kohesif dan hierarki sealed boleh bersama).
- `content.db` read-only; tidak ada perubahan skema atau kolom teks; normalisasi hanya di indeks. Normalisasi kueri memakai `normalizeArabicForSearch` dan `normalizeIndonesianForSearch` dari `lib/content_pipeline/text_normalizer.dart`, tidak ada salinan.
- Tidak ada pemanggilan jaringan, tidak ada paket baru.
- Setiap token kueri dikirim ke FTS dalam tanda kutip (`"token"*`, tanda kutip di dalam token ditulis `""`); tidak pernah menyusun `MATCH` dari input mentah.
- View tipis (UI sementara): format teks dan logika di controller atau fungsi murni yang dites; widget hanya merender.
- Layar baru punya widget test pada 360×640 dengan `TextScaler.linear(1.3)` tanpa overflow (pola Fase 2/3).
- Pesan commit Inggris, Conventional Commits, satu topik per commit. `flutter analyze` bersih dan `flutter test` lulus di akhir tiap task. Jangan push.

## Review Focus

1. Input yang bisa merusak sintaks FTS (`"`, `*`, `-`, `OR`, `AND`, `NEAR(`, `(`, `)`, `:`, `^`, hanya tanda baca) tidak boleh melempar galat atau berubah makna; hasilnya aman dan masuk akal (kosong atau keterangan). Dites di Task 1 (tanpa DB) dan Task 8 (FTS asli).
2. Kata sangat umum ("a", "yang", "di": 24.000–38.000 hadis) tidak boleh memuat semua hasil; hanya satu halaman per permintaan, tetap cepat. Dites di Task 4 dan Task 8.
3. Mengetik cepat: jawaban lama yang tiba terlambat tidak boleh menimpa hasil kueri baru, dan menghapus kueri membersihkan hasil. Dites di Task 6.
4. Teks Arab berharakat: kueri berharakat dan tanpa harakat menghasilkan hasil sama, dan rentang sorotan jatuh pada huruf yang benar di teks asli (termasuk harakat di dalam kata cocok). Dites di Task 3 dan Task 8.
5. Hadis terpotong di sumber (19 hadis, berhenti di tengah kata): kata di bagian yang hilang tidak ditemukan (benar adanya), fragmen kata terakhir yang tersimpan ditemukan, cuplikan di dekat akhir teks tersimpan tidak error dan tidak memberi elipsis belakang karena teks memang berakhir di sana. Dites di Task 2 dan Task 8.

## Struktur File

| File | Tanggung jawab |
|---|---|
| `lib/app/core/search_query.dart` (baru) | `parseSearchQuery`, `ParsedQuery`, `QueryStatus`: normalisasi, token, string `MATCH` |
| `lib/app/core/search_snippet.dart` (baru) | `buildSnippet`, `Snippet`: jendela 100 karakter, batas kata, elipsis, rentang sorotan (Latin dan Arab) |
| `lib/app/data/models/search_hit.dart` (baru) | `SearchHit` sealed → `AyahSearchHit`, `HadithSearchHit`; `SearchPage` |
| `lib/app/data/repositories/search_repository.dart` (baru) | antarmuka |
| `lib/app/data/repositories/sqlite_search_repository.dart` (baru) | query FTS dan pembentukan cuplikan |
| `lib/app/data/repositories/isolate_search_repository.dart`, `lib/app/data/sources/search_query_worker.dart` (baru) | pekerja dan klien (pola `isolate_hadith_repository.dart`) |
| `lib/app/app_bootstrap.dart` (ubah) | mulai pekerja, daftarkan `SearchRepository` |
| `lib/app/modules/search/{bindings,controllers,views,widgets}` (baru) | layar Cari |
| `lib/app/routes/{app_routes,app_pages}.dart`, tab Al-Qur'an dan Hadis (ubah) | rute dan ikon cari |
| `test/support/search_db.dart` (baru) | DB uji dengan baris FTS yang diisi lewat normalizer builder |

---

### Task 1: Uraian kueri pengguna

**Files:** Create `lib/app/core/search_query.dart`; Test `test/app/core/search_query_test.dart`

**Interfaces:**
- Produces: `enum QueryStatus { empty, tooShort, ok }`; `class ParsedQuery { final QueryStatus status; final bool isArabic; final List<String> tokens; final String match; }` (`match` kosong bila status bukan `ok`); `ParsedQuery parseSearchQuery(String raw)`. `match` berbentuk `translation : ("a"* "b"*)` atau `arab : (...)`.

- [ ] **Step 1: Tulis tes gagal.** Nama dan asersi: `empty and whitespace-only input → empty`; `one letter → tooShort` (juga satu huruf Arab); `"Sabar!" → tokens [sabar], match 'translation : ("sabar"*)'`; `special chars never leak`: untuk `'"', '*', '-', 'OR', 'AND', 'NEAR(', '(a)', 'a:b', '^x', 'a"b'` hasilnya `match` hanya berisi `"token"*` dan kata kunci menjadi token biasa huruf kecil (`or`, `and`); input hanya tanda baca → `tooShort`/`empty`; `harakat-insensitive`: `parseSearchQuery('الصَّلَاةَ').match == parseSearchQuery('الصلاه').match` dan `isArabic` true; `mixed input` ("sabar الصلاة") → mode Arab, token Latin dibuang; batas: 9 token dan input 150 karakter menghasilkan paling banyak 8 token dan 100 karakter diproses; dan satu tes yang menjalankan setiap `match` dari daftar di atas pada FTS5 in-memory (`CREATE VIRTUAL TABLE t USING fts5(arab, translation, content='', tokenize='unicode61')`) tanpa galat (sekaligus bukti FTS5 tersedia di paket `sqlite3`).
- [ ] **Step 2: Jalankan, pastikan gagal** (`flutter test test/app/core/search_query_test.dart`; "parseSearchQuery tidak ada").
- [ ] **Step 3: Implementasi `parseSearchQuery`** di `lib/app/core/search_query.dart`. Pendekatan: potong input ke 100 karakter; Arab bila ada huruf di U+0600–U+06FF; normalisasi dengan fungsi builder yang sesuai; buang karakter selain huruf/angka/spasi (`\p{L}\p{N}`) agar tanda baca Arab ikut hilang; pecah spasi, ambil 8 token pertama (untuk mode Arab hanya token yang berisi huruf Arab); status menurut D2; susun `match` dengan tiap token dalam tanda kutip (ganda `"` → `""`) dan akhiran `*`.
- [ ] **Step 4: Jalankan tes sampai lulus**, lalu `flutter analyze`.
- [ ] **Step 5: Commit** `feat: parse search input into a safe fts query`

### Task 2: Cuplikan terjemahan (spec 5.5)

**Files:** Create `lib/app/core/search_snippet.dart`; Test `test/app/core/search_snippet_test.dart`

**Interfaces:**
- Produces: `class Snippet { final String text; final List<TextRange> highlights; final bool cutStart; final bool cutEnd; }` (rentang relatif terhadap `text`, tanpa elipsis; elipsis ditambahkan oleh tampilan menurut `cutStart`/`cutEnd`); `Snippet buildSnippet(String text, List<String> tokens)`.

- [ ] **Step 1: Tulis tes gagal** dengan teks asli keempat ayat (salin persis dari `content.db`: dibaca lewat `test/support` DB nyata atau literal yang dicocokkan ke DB), token `['sabar']`. Untuk tiap kasus: `text.contains(snippet.text)` (substring persis), `snippet.text.length <= 100`, `highlights` mencakup **setiap** kemunculan "sabar" (tak peka huruf) di dalam `snippet.text` dan tidak ada yang lain, kata cocok tidak terpotong, dan bendera: Al-Baqarah 45 `cutStart=false, cutEnd=true`; Al-Baqarah 153 `true, true`; Ali 'Imran 146 `true, false` (cuplikan berakhir pada "…sabar."); An-Nahl 42 `false, false` dan `snippet.text == teks utuh`. Tambahan: teks pendek (<100) tampil utuh; kata cocok huruf besar ("Sabar") tetap disorot; teks tanpa kemunculan token (normalisasi berbeda) → awal teks tanpa sorotan; teks 16.384 karakter dengan kata di indeks 9.000 dan di akhir teks (tanpa spasi akhir, berhenti di tengah kata) tidak melempar galat dan `cutEnd=false` di akhir teks; tanda baca tetap menempel ("sabar." di cuplikan).
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi `buildSnippet`.** Aturan (spec 5.5): cari kemunculan pertama (paling awal) dari semua token, tak peka huruf, di teks asli; jendela 100 karakter berpusat pada kemunculan itu, digeser agar tidak melewati awal/akhir; bila awal terpotong majukan awal ke setelah spasi terdekat, bila akhir terpotong mundurkan akhir ke spasi terdekat, keduanya dibatasi agar kemunculan pertama tidak terpotong; tanpa trim tambahan di dalam teks.
- [ ] **Step 4: Jalankan tes sampai lulus**, `flutter analyze`.
- [ ] **Step 5: Commit** `feat: build search snippets with highlight ranges`

### Task 3: Sorotan teks Arab berharakat

**Files:** Modify `lib/app/core/search_snippet.dart`; Test `test/app/core/search_snippet_arabic_test.dart`

**Interfaces:**
- Consumes: `Snippet`, `buildSnippet` (Task 2), `normalizeArabicForSearch`.
- Produces: `Snippet buildArabicSnippet(String text, List<String> tokens)` (token sudah ternormalisasi; rentang dan jendela dihitung pada teks asli).

- [ ] **Step 1: Tulis tes gagal.** (a) Teks berharakat (mis. basmalah Al-Fatihah:1 dari DB) dengan token ternormalisasi `الرحمن`: rentang sorotan menutup tepat kata "ٱلرَّحْمَٰنِ" termasuk harakat di dalamnya, dan `text.substring(start,end)` setelah dinormalisasi sama dengan token; (b) token yang terbelah harakat dan alif khanjariyah (ٰ); (c) normalisasi alif (أ إ آ ٱ → ا), ى → ي, ة → ه menghasilkan sorotan pada huruf asli; (d) tanda waqaf/tatweel di dalam kata ikut dalam rentang; (e) hadis Arab panjang (sampai 8.700 karakter): jendela 100 karakter pada teks asli, `text.length <= 100`; (f) tanpa kemunculan → awal teks tanpa sorotan.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi `buildArabicSnippet`.** Pendekatan: telusuri teks asli sekali, bangun teks ternormalisasi karakter demi karakter (karakter yang dihapus normalizer tidak menambah indeks) dengan peta indeks ternormalisasi → indeks asli; cari token di teks ternormalisasi, ubah ke rentang asli (akhir rentang diperluas melewati harakat yang menempel); lalu pakai jendela dan pemotongan batas kata yang sama dengan Task 2 (satu fungsi bersama, bukan salinan).
- [ ] **Step 4: Jalankan tes sampai lulus**, `flutter analyze`.
- [ ] **Step 5: Commit** `feat: highlight search matches in vocalized arabic text`

### Task 4: Model dan `SearchRepository` (SQLite)

**Files:** Create `lib/app/data/models/search_hit.dart`, `lib/app/data/repositories/search_repository.dart`, `lib/app/data/repositories/sqlite_search_repository.dart`, `test/support/search_db.dart`; Test `test/app/data/sqlite_search_repository_test.dart`

**Interfaces:**
- Consumes: `ParsedQuery` (Task 1), `buildSnippet`/`buildArabicSnippet` (Task 2, 3), `ContentDatabase`, `ContentUnavailable`.
- Produces: `sealed class SearchHit { final int rowId; final Snippet snippet; }`; `AyahSearchHit { int surahNumber; int ayahNumber; String surahName; }` (`surahName` = `surah.name_latin`); `HadithSearchHit { HadithRef ref; String bookName; }`; `class SearchPage { final List<SearchHit> hits; final bool hasMore; }`;
  ```dart
  abstract interface class SearchRepository {
    Future<SearchPage> searchAyah(ParsedQuery q, {int afterRowId = 0, int limit = 30});
    Future<SearchPage> searchHadith(ParsedQuery q, {String? bookSlug, int afterRowId = 0, int limit = 30});
  }
  ```
  `limit < 1` → `ArgumentError`; `q.status != ok` → halaman kosong tanpa query; galat SQLite → `ContentUnavailable`. Hasil hadis untuk satu kitab memakai `hadith.book_slug` (gabung dengan `hadith_fts` lewat `rowid`).

- [ ] **Step 1: Tulis tes gagal** dengan `test/support/search_db.dart` (DB kecil dengan skema produksi, `ayah`, `hadith`, kitab, dan baris FTS diisi lewat normalizer builder): kecocokan kolom `translation` dan `arab` berharakat; awalan ("sabar" menemukan "sabarlah", tidak menemukan "bersabar" sesuai D1); `AND` antar token; paging keyset tanpa duplikat dan tanpa celah (`afterRowId`) dengan `limit` 2 pada 7 hasil, `hasMore` tepat; urutan menurut `rowid`; filter `bookSlug`; `limit: 0` → `ArgumentError`; status `tooShort`/`empty` → kosong; galat: DB tertutup → `ContentUnavailable`; snippet hadis panjang tidak membawa teks penuh (panjang `snippet.text <= 100`); kata sangat umum pada 500 baris hanya mengembalikan `limit` hit.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi** `SqliteSearchRepository` (`SELECT rowid FROM <x>_fts WHERE <x>_fts MATCH ? AND rowid > ? ORDER BY rowid LIMIT ?+1`, lalu baca baris tabel utama untuk ID yang didapat dan bangun cuplikan; `hasMore` dari baris ke `limit+1`). Model dalam satu file (hierarki sealed).
- [ ] **Step 4: Jalankan tes sampai lulus**, `flutter analyze`.
- [ ] **Step 5: Commit** `feat: add search repository over the fts index`

### Task 5: Isolate pencarian dan registrasi

**Files:** Create `lib/app/data/repositories/isolate_search_repository.dart`, `lib/app/data/sources/search_query_worker.dart`; Modify `lib/app/app_bootstrap.dart`; Test `test/app/data/isolate_search_repository_test.dart`, `test/app/app_bootstrap_test.dart`

**Interfaces:**
- Consumes: `SqliteSearchRepository`, pola `IsolateHadithRepository.start(File)`/`close()` dan `hadith_query_worker.dart`.
- Produces: `IsolateSearchRepository implements SearchRepository` dengan `static Future<IsolateSearchRepository> start(File contentFile)` dan `Future<void> close()`; hanya data polos melintasi isolate (`ParsedQuery` dikirim sebagai map).

- [ ] **Step 1: Tulis tes gagal.** Tes paritas: untuk daftar kueri (Latin, Arab berharakat, umum, kosong) hasil `IsolateSearchRepository` sama persis dengan `SqliteSearchRepository` (snippet, rentang, `hasMore`); `close()` membuat panggilan berikutnya `ContentUnavailable`; panggilan setelah pekerja mati gagal bersih; tiap tes menutup pekerja di `tearDown`; bootstrap: pekerja pencarian dimulai setelah pekerja hadis, kegagalan di langkah mana pun menutup semua yang sudah terbuka dan tidak mendaftarkan apa pun (tes bootstrap yang ada diperluas, parameter `@visibleForTesting startSearch`, tes widget memakai `tester.runAsync`/fake).
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi** klien, pekerja, dan perubahan bootstrap (urutan: content db → pekerja hadis → pekerja pencarian → user db → registrasi `Get.put<SearchRepository>`).
- [ ] **Step 4: Jalankan seluruh `flutter test`**, `flutter analyze`.
- [ ] **Step 5: Commit** `feat: run search queries in a worker isolate`

### Task 6: `SearchResultsController`

**Files:** Create `lib/app/modules/search/controllers/search_results_controller.dart`, `lib/app/modules/search/bindings/search_binding.dart`, `lib/app/modules/search/search_args.dart`; Modify `test/support/fake_repositories.dart` (`FakeSearchRepository`); Test `test/app/modules/search/search_results_controller_test.dart`

**Interfaces:**
- Consumes: `SearchRepository`, `parseSearchQuery`, `UiState`.
- Produces: `enum SearchScope { quran, hadith }`; `class SearchArgs { const SearchArgs(this.scope); final SearchScope scope; }`; `SearchResultsController` dengan `Rx` `scope`, `bookSlug` (String?), `state` (`UiState<List<SearchSection>>`), `hint` (String?: keterangan "Ketik minimal 2 huruf" atau keterangan awal), `loadingMore`, `moreError`; metode `onQueryChanged(String)`, `setScope(SearchScope)`, `setBook(String?)`, `loadMore()`, `retry()`; `SearchSection { String title; List<SearchItem> items; }`, `SearchItem { SearchHit hit; String label; }` (label "Ayat 5" atau "No. 4.066" lewat `formatThousands`).

- [ ] **Step 1: Tulis tes gagal** dengan `FakeSearchRepository` yang bisa ditahan (Completer): jeda 300 ms (`fakeAsync`) dan hanya kueri terakhir yang dikirim; kueri kosong membersihkan hasil dan menampilkan `hint` tanpa memanggil repository; satu huruf → `hint` "Ketik minimal 2 huruf", tanpa panggilan; hasil kosong → `UiEmpty` ("Tidak ada hasil"); balasan kueri lama yang tiba setelah kueri baru dibuang (token generasi); ganti cakupan atau kitab mengulang kueri; pengelompokan menurut surah/kitab yang berdekatan menjadi satu bagian, dan bagian berlanjut saat `loadMore` (tidak menduplikasi judul); `loadMore` tidak dobel saat sedang jalan dan berhenti saat `hasMore=false`; galat repository → `UiError` dan `retry()`; galat saat `loadMore` tidak menghapus hasil yang ada (`moreError`); controller ditutup saat balasan tiba tidak melempar.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi** controller dan binding (`on Object` pada penangkap galat, pola `HadithListController`).
- [ ] **Step 4: Jalankan tes sampai lulus**, `flutter analyze`.
- [ ] **Step 5: Commit** `feat: add search results controller`

### Task 7: Layar Cari, rute, dan pintu masuk (UI sementara)

**Files:** Create `lib/app/modules/search/views/search_view.dart`, `lib/app/modules/search/widgets/search_result_tile.dart`; Modify `lib/app/routes/app_routes.dart` (`Routes.search = '/search'`), `lib/app/routes/app_pages.dart`, `quran_list_view.dart`, `hadith_books_view.dart` (ikon cari di app bar); Test `test/app/modules/search/search_view_test.dart`

**Interfaces:**
- Consumes: `SearchResultsController` (Task 6), `NuraColors.searchHighlight`, `EmptyState`/`ErrorState`, `SurahArgs(surah, ayah)`, `HadithDetailArgs(slug, number)`.
- Produces: `SearchResultTile({required SearchItem item, required VoidCallback onTap})`; fungsi murni `InlineSpan snippetSpan(Snippet s, TextStyle base, Color highlight)` (elipsis "…" di depan/belakang menurut `cutStart`/`cutEnd`; rentang sorotan `TextSpan(backgroundColor: highlight)`).

- [ ] **Step 1: Tulis tes gagal.** `snippetSpan` untuk empat kasus (elipsis di tempat yang benar, rentang sorotan, teks tanpa elipsis sama dengan `snippet.text`); widget test: `Text.rich` hasil maksimal 3 baris; sorotan memakai `searchHighlight` pada tema Light dan Dark; keadaan awal, "Ketik minimal 2 huruf", memuat, "Tidak ada hasil", galat dengan tombol coba lagi; kepala bagian per surah/kitab; ketuk hasil ayat membuka `Routes.surah` dengan `SurahArgs(surah, ayah)`, hasil hadis membuka `Routes.hadithDetail`; chip cakupan dan pilihan kitab; **tes 360×640 dengan `TextScaler.linear(1.3)` tanpa overflow** untuk keadaan berisi hasil; hasil Arab dirender RTL dengan font Arab yang ada.
- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi** tampilan (tipis, `Obx` hanya di dalam body), rute dengan `SearchBinding`, dan ikon cari di dua tab; field cari bertipe `SearchField` komponen yang ada atau `TextField` bergaya sama (cek `lib/app/core/widgets`), `onChanged` memanggil `onQueryChanged`.
- [ ] **Step 4: Jalankan seluruh `flutter test`**, `flutter analyze`.
- [ ] **Step 5: Commit** `feat: add search screen with highlighted snippets`

### Task 8: Data asli, kinerja, dan dokumen

**Files:** Create `test/app/search_real_data_test.dart`; Modify `docs/STATUS.md`, `docs/specs/2026-11-09-nura-v1-design.md` (5.5 dan 3.x sesuai keputusan D1, bila awalan dipilih), `docs/PRD.md` bila perlu

**Interfaces:** Consumes: `SqliteSearchRepository` dan `IsolateSearchRepository` pada `assets/db/content.db`.

- [ ] **Step 1: Tulis tes data asli** (pola tes verifikasi yang sudah memakai `content.db`): (a) kueri "sabar": terjemahan ayat menemukan 37 ayat, hadis menemukan 91 (angka diukur 2026-11-15; bila kontrak D1 berubah, sesuaikan); (b) Review Focus 1: semua masukan khusus dari Task 1 pada FTS asli tidak melempar galat; (c) Review Focus 2: kata "a", "yang", "di" pada semua hadis mengembalikan tepat satu halaman (30) dan `hasMore=true`, dan berjalan menuruni halaman (keyset) menghasilkan `rowid` naik tanpa duplikat sampai 10 halaman; (d) Review Focus 4: `الصَّلَاةَ` dan `الصلاه` menghasilkan hasil identik, dan untuk 20 hit pertama `normalizeArabicForSearch(substring sorotan)` memuat token; (e) Review Focus 5: untuk setiap dari 19 hadis terpotong, kata terakhir yang tersimpan (token terakhir teks Arab) ditemukan lewat pencarian kitabnya dan cuplikannya tidak melempar galat; (f) kinerja: kueri terburuk (token dua huruf paling umum, token langka, dua token umum) pada semua hadis lewat jalur isolate selesai < 1000 ms per halaman (ambang tes; pengukuran di perangkat dicatat di STATUS); (g) hasil ayat Al-Baqarah 45, 153, Ali 'Imran 146, An-Nahl 42 untuk "sabar" memiliki bendera elipsis sesuai Task 2.
- [ ] **Step 2: Jalankan, perbaiki bila perlu** (perbaikan pada kode task sebelumnya dilakukan sebagai commit terpisah bergaya `fix:`).
- [ ] **Step 3: Perbarui dokumen.** `docs/STATUS.md`: baris Fase 4 (selesai di kode, UI sementara untuk hadis dan Arab), keputusan D1–D9 bertanggal, jumlah test, daftar uji perangkat pemilik: cari "sabar" (Al-Qur'an dan Hadis), kata satu huruf, kata Arab berharakat dan tanpa harakat, ketik cepat lalu hapus, mode pesawat, waktu respons di perangkat (target < 1 detik untuk semua hadis), keempat kasus cuplikan; Tindak lanjut: profil kinerja di ponsel, desain putaran 2 untuk layar Cari hadis dan Arab. Spec 5.5/3.3 dikoreksi bila D1 (a) disetujui.
- [ ] **Step 4: `flutter analyze` dan `flutter test` penuh.**
- [ ] **Step 5: Commit** `test: verify search against the real content db` dan `docs: update status after phase 4`

## Ketergantungan

T1 dan T2 mandiri. T3 butuh T2. T4 butuh T1, T2, T3 (dan keputusan D1). T5 butuh T4. T6 butuh T4 (fake repository). T7 butuh T6 dan route registrasi dari T5 saat berjalan nyata. T8 butuh semuanya.

## Di Luar Rencana Ini

Peringkat relevansi (bm25), pencarian frasa, pencarian tafsir, riwayat pencarian, saran otomatis, tokenizer trigram atau perubahan skema `content.db`, desain putaran 2 layar Cari, penghidupan ulang pekerja yang mati, dan `getHadithPreview` yang lebih ringan.
