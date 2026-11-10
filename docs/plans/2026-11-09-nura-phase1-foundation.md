# Nura Fase 1 (Fondasi): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kode lama diganti fondasi bersih: paket `nura`, pipeline JSON → `content.db` yang terverifikasi, `user.db` dengan migrasi, dan aplikasi yang terbuka ke Beranda kosong.

**Architecture:** Logika pipeline ditulis sebagai Dart murni di `lib/content_pipeline/` (tanpa Flutter) agar bisa dipakai oleh skrip `tool/` dan diuji dengan `flutter test`. Aplikasi menyalin `content.db` dari assets ke folder aplikasi lalu membukanya read-only; `user.db` dibuka read-write dengan migrasi `user_version`. GetX mendaftarkan source sebagai singleton dan memilih route awal.

**Tech Stack:** Flutter (SDK ^3.9.0), GetX, `sqlite3` + `sqlite3_flutter_libs`, `path_provider`, `path`, `crypto`.

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (bagian 3, 4, 5.4, 9, 10, 11 Fase 1). Baca juga `AGENTS.md`.

## Global Constraints

- Nama paket Dart: `nura`. Application ID Android: `com.technowstack.nura`. Namespace Kotlin: `com.technowstack.nura`.
- Dependency yang boleh ditambahkan di fase ini: `get`, `sqlite3`, `sqlite3_flutter_libs`, `path_provider`, `path`, `crypto`. Paket `http` dan `lottie` dihapus.
- `data-source/` tidak boleh diubah. Semua tulisan hanya ke `assets/db/`, `lib/`, `test/`, `tool/`, dan file konfigurasi.
- Kolom teks asli (`arab`, `translation_id`, `tafsir_kemenag`) diisi string hasil `jsonDecode` apa adanya: tanpa `trim`, normalisasi Unicode, atau penggantian karakter.
- `lib/content_pipeline/` tidak boleh mengimpor `package:flutter`.
- Tidak boleh `ignore_for_file`. `flutter analyze` bersih dan `flutter test` lulus sebelum setiap commit.
- Pesan commit Bahasa Inggris, Conventional Commits. Jangan push.
- Teks yang dilihat pengguna dalam Bahasa Indonesia.

## Review Focus

1. **Urutan kunci ayat di JSON Quran.** Kunci `text` berupa string `"1"`, `"2"`, … `"10"`. Ayat harus diurutkan secara numerik, bukan urutan map atau urutan string ("10" sebelum "2"). Diuji di Task 3.
2. **Whitespace dan karakter tak terlihat di teks.** Spasi di akhir, spasi ganda, dan karakter seperti ZWNJ (U+200C) harus tersimpan persis. Diuji di Task 5 dan Task 6 lewat entri sintetis di fixture.
3. **Salinan `content.db` yang usang setelah update aplikasi.** Kalau `content.version` di assets berbeda dengan salinan, salinan harus diganti. Diuji di Task 8.
4. **Penyalinan yang terputus.** Kalau aplikasi mati di tengah penyalinan, file setengah jadi tidak boleh dianggap valid. Salin ke file sementara lalu `rename`. Diuji di Task 8.
5. **Peluncuran kedua.** Membuka `user.db` yang sudah ada tidak boleh menjalankan ulang migrasi atau menghapus data. Diuji di Task 9.

---

## Struktur File

```
lib/
  main.dart                                   (ganti total)
  content_pipeline/                           Dart murni, dipakai tool/ dan test/
    text_normalizer.dart                      normalisasi teks untuk indeks FTS
    source_models.dart                        SourceSurah, SourceAyah, SourceHadithBook, SourceHadith
    quran_source_parser.dart
    hadith_source_parser.dart
    checksum_manifest.dart
    seeded_shuffle.dart
    content_schema.dart                       DDL content.db + konstanta
    content_db_builder.dart
    content_db_verifier.dart
  app/
    core/
      theme/app_theme.dart
      init_failure_view.dart
    data/sources/
      content_db_installer.dart
      content_database.dart
      user_database.dart
    modules/
      home/home_view.dart                     placeholder "Beranda"
      onboarding/onboarding_view.dart         placeholder "Selamat datang"
    routes/app_routes.dart
    routes/app_pages.dart
    app_bootstrap.dart
tool/
  build_content_db.dart
  verify_content_db.dart
test/
  fixtures/data-source/                       subset data + CHECKSUMS.sha256
  content_pipeline/…_test.dart
  app/…_test.dart
assets/db/content.db
```

## Fixture Uji

`test/fixtures/data-source/` dipakai oleh Task 3–7. Dibuat sekali di Task 3:

- `quran/1.json`: salinan persis `data-source/quran/1.json` (7 ayat).
- `quran/112.json`: salinan persis `data-source/quran/112.json` (4 ayat).
- `quran/100.json`: salinan persis `data-source/quran/100.json` (11 ayat), untuk menguji urutan kunci "10" vs "2".
- `hadith/malik.json`: 5 entri pertama dari `data-source/hadith/malik.json`, ditambah satu entri sintetis `{"number": 99999, "arab": "نص تجريبي  ", "id": "teks‌ uji  dengan  spasi  "}` (perhatikan dua spasi di akhir dan ZWNJ).
- `hadith/darimi.json`: 3 entri pertama dari `data-source/hadith/darimi.json`.
- `meta/surah_info.json`: hanya untuk surah yang ada di fixture, format `[{"number": 1, "revelation": "makkiyah"}, …]`. Tidak ada entri untuk satu surah (sengaja) untuk menguji peringatan.
- `CHECKSUMS.sha256`: dibuat dengan `sha256sum` dari dalam folder fixture, format sama dengan `data-source/CHECKSUMS.sha256`.

---

### Task 1: Bersihkan kode lama dan siapkan paket `nura`

**Files:**
- Delete: seluruh isi `lib/` lama, `test/widget_test.dart`, `assets/lotties/`, `assets/images/` (gambar lama tidak dipakai di v1)
- Modify: `pubspec.yaml`, `analysis_options.yaml`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/…/MainActivity.kt` (pindah ke `com/technowstack/nura/`)
- Create: `lib/main.dart`, `lib/app/modules/home/home_view.dart`, `test/app/smoke_test.dart`

**Interfaces:**
- Produces: `class NuraApp extends StatelessWidget` di `lib/main.dart`, sementara langsung menampilkan `HomeView`.

- [ ] **Step 1: Tulis test smoke yang gagal**

```dart
// test/app/smoke_test.dart
testWidgets('app boots and shows Beranda', (tester) async {
  await tester.pumpWidget(const NuraApp());
  expect(find.text('Beranda'), findsOneWidget);
});
```

- [ ] **Step 2: Hapus kode dan aset lama, perbarui `pubspec.yaml`**

`name: nura`, `description: Aplikasi Islami offline-first.`, `version: 0.1.0+1`, SDK `^3.9.0`. Dependencies: `get`, `sqlite3`, `sqlite3_flutter_libs`, `path_provider`, `path`, `crypto`. Dev: `flutter_test`, `flutter_lints`. Hapus `http`, `lottie`, dan entri assets lama. Belum mendaftarkan `assets/db/` (dilakukan di Task 7).

- [ ] **Step 3: Ganti Application ID dan namespace Android**

Di `build.gradle.kts`: `namespace = "com.technowstack.nura"` dan `applicationId = "com.technowstack.nura"`. Pindahkan `MainActivity.kt` ke `kotlin/com/technowstack/nura/` dengan `package com.technowstack.nura`. `android:label="Nura"` di manifest.

- [ ] **Step 4: Implementasi `NuraApp` minimal dan `HomeView` placeholder**

`GetMaterialApp(title: 'Nura', home: HomeView())`. `HomeView` menampilkan `Scaffold` dengan teks `Beranda`.

- [ ] **Step 5: Jalankan verifikasi**

Run: `flutter pub get && flutter analyze && flutter test`
Expected: analyze tanpa issue, 1 test PASS.

Run: `flutter build apk --debug`
Expected: build sukses. Cek `grep -r "com.example" android/` tidak mengembalikan hasil.

- [ ] **Step 6: Commit**

```bash
git add -A lib test pubspec.yaml pubspec.lock analysis_options.yaml android assets
git commit -m "refactor: remove legacy app and rename package to nura"
```

---

### Task 2: Normalisasi teks pencarian

**Files:**
- Create: `lib/content_pipeline/text_normalizer.dart`
- Test: `test/content_pipeline/text_normalizer_test.dart`

**Interfaces:**
- Produces: `String normalizeArabicForSearch(String input)` dan `String normalizeIndonesianForSearch(String input)`.

- [ ] **Step 1: Tulis test yang gagal**

```dart
test('arabic: strips harakat, quranic marks and tatweel', () {
  expect(normalizeArabicForSearch('بِسْمِ ٱللَّهِ'), 'بسم الله');
  expect(normalizeArabicForSearch('الْحَمْدُ لِلَّهِ ۖ'), 'الحمد لله');
  expect(normalizeArabicForSearch('قـــال'), 'قال');
});
test('arabic: normalizes alif, ya and ta marbuta', () {
  expect(normalizeArabicForSearch('أإآٱ'), 'اااا');
  expect(normalizeArabicForSearch('هدى'), 'هدي');
  expect(normalizeArabicForSearch('رحمة'), 'رحمه');
});
test('arabic: collapses whitespace and trims', () {
  expect(normalizeArabicForSearch('  قال   رسول  '), 'قال رسول');
});
test('indonesian: lowercases, replaces punctuation, collapses spaces', () {
  expect(normalizeIndonesianForSearch('Dengan nama Allah, Yang Maha Pengasih.'),
      'dengan nama allah yang maha pengasih');
  expect(normalizeIndonesianForSearch('"(Yaitu)"  orang-orang'), 'yaitu orang orang');
});
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/content_pipeline/text_normalizer_test.dart`
Expected: FAIL, fungsi belum ada.

- [ ] **Step 3: Implementasi**

Arab: hapus rentang U+064B–U+065F, U+0670, U+06D6–U+06ED, U+0640; ganti أ إ آ ٱ → ا, ى → ي, ة → ه; padatkan whitespace; trim. Indonesia: `toLowerCase()`, ganti karakter yang bukan huruf/angka/spasi dengan spasi (pakai `RegExp(r'[^\p{L}\p{N}\s]', unicode: true)`), padatkan, trim. Normalisasi ini hanya untuk indeks FTS (`ayah_fts`, `hadith_fts`).

- [ ] **Step 4: Jalankan, pastikan lulus**

Run: `flutter test test/content_pipeline/text_normalizer_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/content_pipeline/text_normalizer.dart test/content_pipeline/text_normalizer_test.dart
git commit -m "feat: add search text normalization for arabic and indonesian"
```

---

### Task 3: Parser sumber Quran dan hadis, beserta fixture

**Files:**
- Create: `lib/content_pipeline/source_models.dart`, `lib/content_pipeline/quran_source_parser.dart`, `lib/content_pipeline/hadith_source_parser.dart`, seluruh `test/fixtures/data-source/` (lihat bagian Fixture Uji)
- Test: `test/content_pipeline/source_parser_test.dart`

**Interfaces:**
- Produces:
  - `class SourceAyah { final int number; final String arab; final String translation; final String tafsir; }`
  - `class SourceSurah { final int number; final String nameArab; final String nameLatin; final String nameId; final int ayahCount; final List<SourceAyah> ayahs; }`
  - `class SourceHadith { final int number; final String arab; final String translation; }`
  - `class SourceHadithBook { final String slug; final List<SourceHadith> hadiths; }`
  - `SourceSurah parseQuranFile(String jsonText)`; `List<SourceSurah> readQuranDir(Directory dir)` (urut berdasarkan `number`)
  - `SourceHadithBook parseHadithFile(String slug, String jsonText)`; `List<SourceHadithBook> readHadithDir(Directory dir)` (slug = nama file tanpa `.json`)
  - `class SourceFormatException implements Exception { final String file; final String message; }`

- [ ] **Step 1: Buat fixture** sesuai bagian Fixture Uji, salin byte demi byte (`cp`), lalu buat `CHECKSUMS.sha256`.

- [ ] **Step 2: Tulis test yang gagal**

```dart
test('parses surah 1 with 7 ayahs in numeric order', () {
  final s = readQuranDir(fixtureDir('quran')).firstWhere((s) => s.number == 1);
  expect(s.ayahCount, 7);
  expect(s.ayahs.map((a) => a.number), [1, 2, 3, 4, 5, 6, 7]);
  expect(s.nameLatin, isNotEmpty);
});
test('orders ayah keys numerically for surahs with 10+ ayahs', () {
  final s = readQuranDir(fixtureDir('quran')).firstWhere((s) => s.ayahCount >= 10);
  expect(s.ayahs.map((a) => a.number), List.generate(s.ayahCount, (i) => i + 1));
});
test('ayah text equals raw JSON value exactly', () {
  final raw = jsonDecode(File(fixturePath('quran/1.json')).readAsStringSync());
  final s = parseQuranFile(File(fixturePath('quran/1.json')).readAsStringSync());
  expect(s.ayahs.first.arab, raw['1']['text']['1']);
  expect(s.ayahs.first.translation, raw['1']['translations']['id']['text']['1']);
  expect(s.ayahs.first.tafsir, raw['1']['tafsir']['id']['kemenag']['text']['1']);
});
test('hadith keeps trailing spaces and ZWNJ', () {
  final b = readHadithDir(fixtureDir('hadith')).firstWhere((b) => b.slug == 'malik');
  final h = b.hadiths.firstWhere((h) => h.number == 99999);
  expect(h.arab, 'نص تجريبي  ');
  expect(h.translation, 'teks‌ uji  dengan  spasi  ');
});
test('throws SourceFormatException when ayah count mismatches number_of_ayah', () {
  // salin quran/1.json ke temp, hapus satu kunci ayat, lalu parse
  expect(() => parseQuranFile(brokenJson), throwsA(isA<SourceFormatException>()));
});
```

Helper `fixtureDir`/`fixturePath` ditaruh di `test/support/fixtures.dart`.

- [ ] **Step 3: Jalankan, pastikan gagal**

Run: `flutter test test/content_pipeline/source_parser_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implementasi parser**

Quran: objek tingkat atas punya satu kunci (nomor surah). `number` dan `number_of_ayah` di-`int.parse`. Ayat diambil dari kunci `text`, diurutkan dengan `int.parse(key)`; terjemahan dan tafsir diambil dengan kunci yang sama. Lempar `SourceFormatException` jika jumlah kunci ≠ `number_of_ayah`, atau kunci ayat tidak ada di terjemahan/tafsir. Hadis: list objek `{number, arab, id}`; `id` dipetakan ke `translation`.

- [ ] **Step 5: Jalankan, pastikan lulus**

Run: `flutter test test/content_pipeline/source_parser_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/content_pipeline test/content_pipeline test/support test/fixtures
git commit -m "feat: parse quran and hadith source json"
```

---

### Task 4: Manifest checksum dan acak deterministik

**Files:**
- Create: `lib/content_pipeline/checksum_manifest.dart`, `lib/content_pipeline/seeded_shuffle.dart`
- Test: `test/content_pipeline/checksum_manifest_test.dart`, `test/content_pipeline/seeded_shuffle_test.dart`

**Interfaces:**
- Produces:
  - `class ChecksumManifest { final Map<String, String> entries; static ChecksumManifest parse(String text); List<String> verify(Directory root); String toJson(); }`. `verify` mengembalikan daftar pesan masalah (file hilang, hash beda, file tak terdaftar di `quran/`, `hadith/`, `meta/`); list kosong berarti cocok.
  - `List<T> seededShuffle<T>(List<T> items, int seed)` (tidak mengubah input).
  - `const int dailySeed = 20261109;`

- [ ] **Step 1: Tulis test yang gagal**

```dart
test('fixture manifest verifies clean', () {
  final m = ChecksumManifest.parse(File(fixturePath('CHECKSUMS.sha256')).readAsStringSync());
  expect(m.verify(fixtureDir('')), isEmpty);
});
test('detects modified file', () {
  // salin fixture ke temp, tambahkan satu spasi ke hadith/darimi.json
  expect(m.verify(tempRoot), contains(contains('hadith/darimi.json')));
});
test('detects missing and unlisted files', () { /* hapus satu, tambah satu */ });
test('seededShuffle is deterministic and a permutation', () {
  final a = seededShuffle(List.generate(100, (i) => i), dailySeed);
  final b = seededShuffle(List.generate(100, (i) => i), dailySeed);
  expect(a, b);
  expect(a.toSet(), Set.of(List.generate(100, (i) => i)));
  expect(a, isNot(List.generate(100, (i) => i)));
});
test('seededShuffle golden prefix', () {
  expect(seededShuffle(List.generate(10, (i) => i), dailySeed), <int>[/* isi dari run pertama */]);
});
```

Untuk test golden: jalankan sekali, salin hasilnya ke ekspektasi. Tujuannya mengunci algoritma agar build ulang menghasilkan urutan yang sama.

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/content_pipeline/checksum_manifest_test.dart test/content_pipeline/seeded_shuffle_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementasi**

SHA-256 dengan `package:crypto`. Format baris manifest: `<hash>  <path relatif>` (dua spasi, sama dengan `sha256sum`). Acak memakai PRNG sendiri (jangan `dart:math Random`, karena implementasinya tidak dijamin stabil antar versi Dart), yaitu mulberry32 dengan Fisher–Yates:

```dart
int _next(List<int> state) {
  state[0] = (state[0] + 0x6D2B79F5) & 0xFFFFFFFF;
  var t = state[0];
  t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF;
  t = (t ^ (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF;
  return (t ^ (t >> 14)) & 0xFFFFFFFF;
}
// Fisher–Yates: for i = n-1 downto 1: j = _next(state) % (i + 1); swap(i, j)
```

- [ ] **Step 4: Jalankan, pastikan lulus** (lalu isi golden, jalankan lagi)

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/content_pipeline test/content_pipeline
git commit -m "feat: add checksum manifest and deterministic shuffle"
```

---

### Task 5: Skema dan builder `content.db`

**Files:**
- Create: `lib/content_pipeline/content_schema.dart`, `lib/content_pipeline/content_db_builder.dart`
- Test: `test/content_pipeline/content_db_builder_test.dart`

**Interfaces:**
- Consumes: Task 2, 3, 4.
- Produces:
  - `content_schema.dart`: `const int contentSchemaVersion = 1;`, `const List<String> contentSchemaDdl` (DDL spec 3.2 apa adanya), `const Map<String, String> hadithBookNames` dan urutannya: `bukhari` Shahih Bukhari, `muslim` Shahih Muslim, `abu-daud` Sunan Abu Daud, `tirmidzi` Sunan Tirmidzi, `nasai` Sunan Nasa'i, `ibnu-majah` Sunan Ibnu Majah, `ahmad` Musnad Ahmad, `malik` Muwatha' Malik, `darimi` Sunan Darimi. `const int dailyHadithMaxLength = 400;`
  - `class BuildResult { final int surahCount; final int ayahCount; final int hadithCount; final List<String> warnings; }`
  - `BuildResult buildContentDb({required Directory sourceRoot, required File output, required String dataVersion, DateTime? builtAt})`

- [ ] **Step 1: Tulis test yang gagal**

```dart
late Database db;
setUp(() {
  final out = File('${tempDir.path}/content.db');
  buildContentDb(sourceRoot: fixtureDir(''), output: out, dataVersion: 'test-1',
      builtAt: DateTime.utc(2026, 11, 9));
  db = sqlite3.open(out.path, mode: OpenMode.readOnly);
});
test('row counts match fixture', () { /* 3 surah, ayah = jumlah ayat fixture, 2 kitab, 9 hadis */ });
test('ayah ids are global and ordered by surah then ayah', () {
  final rows = db.select('SELECT surah_number, ayah_number FROM ayah ORDER BY id');
  // pasangan (surah, ayah) naik secara leksikografis, id dimulai dari 1
});
test('raw text stored byte-identical, including trailing spaces and ZWNJ', () {
  final r = db.select("SELECT arab, translation_id FROM hadith WHERE book_slug='malik' AND number=99999").single;
  expect(r['arab'], 'نص تجريبي  ');
  expect(r['translation_id'], 'teks‌ uji  dengan  spasi  ');
});
test('FTS finds rows by normalized words, rowid equals table id', () { /* kata Arab tanpa harakat dan kata Indonesia huruf kecil menemukan baris yang benar */ });
test('FTS finds an ayah by indonesian word', () {
  expect(db.select("SELECT rowid FROM ayah_fts WHERE ayah_fts MATCH 'translation:pengasih'"), isNotEmpty);
});
test('meta has schema_version, data_version, built_at, source_checksums', () {});
test('missing surah_info entry yields empty revelation and a warning', () {});
test('daily_hadith contains only hadith with translation_length <= 400', () {});
test('daily_ayah is empty when meta/daily_ayah.json is absent', () {});
test('unknown hadith slug throws', () { /* tambah hadith/unknown.json di salinan temp */ });
test('build is deterministic', () { /* build dua kali, isi tabel ayah dan daily_hadith sama */ });
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/content_pipeline/content_db_builder_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementasi `buildContentDb`**

Tulis ke `output.path + '.tmp'` lalu `rename`. Satu transaksi untuk semua insert. `id` ayat dihitung berurutan saat iterasi surah (urut nomor) lalu ayat. `hadith.id` berurutan per kitab menurut `sort_order` lalu urutan array. `juz.json` dan `daily_ayah.json` opsional; jika ada, format `juz.json`: `[{"number":1,"start_surah":1,"start_ayah":1,"end_surah":2,"end_ayah":141}, …]`, format `daily_ayah.json`: `[{"surah":2,"ayah":255}, …]` (lempar error jika pasangan tidak ada). Isi FTS dengan `INSERT INTO ayah_fts(ayah_fts) VALUES('rebuild')`. `daily_hadith`: ambil id yang lolos filter, urut `id`, `seededShuffle(..., dailySeed)`, simpan dengan `seq` 0..n-1. `source_checksums` = `ChecksumManifest.toJson()` dari `CHECKSUMS.sha256` sumber. Akhiri dengan `VACUUM`.

- [ ] **Step 4: Jalankan, pastikan lulus**

Run: `flutter test test/content_pipeline/content_db_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/content_pipeline test/content_pipeline
git commit -m "feat: build content.db from source json"
```

---

### Task 6: Verifier `content.db`

**Files:**
- Create: `lib/content_pipeline/content_db_verifier.dart`
- Test: `test/content_pipeline/content_db_verifier_test.dart`

**Interfaces:**
- Consumes: Task 3, 4, 5.
- Produces:
  - `class VerificationReport { final List<String> errors; final List<String> warnings; bool get ok => errors.isEmpty; }`
  - `VerificationReport verifyContentDb({required Directory sourceRoot, required File database, ExpectedTotals? expected})`
  - `class ExpectedTotals { final int surahs; final int ayahs; final int books; final int hadiths; }` dan `const ExpectedTotals fullDatasetTotals = ExpectedTotals(surahs: 114, ayahs: 6236, books: 9, hadiths: 38102);`

- [ ] **Step 1: Tulis test yang gagal**

```dart
test('freshly built fixture db verifies ok', () {
  expect(verifyContentDb(sourceRoot: fixtureDir(''), database: built).ok, isTrue);
});
test('one changed character in ayah.arab is an error', () {
  // salin db, lalu UPDATE ayah SET arab = arab || 'x' WHERE id = 1
  final r = verifyContentDb(sourceRoot: fixtureDir(''), database: tampered);
  expect(r.ok, isFalse);
  expect(r.errors.single, contains('ayah 1:1'));
});
test('trimmed trailing space in hadith is an error', () { /* UPDATE … SET arab = rtrim(arab) WHERE number=99999 */ });
test('missing row is an error', () { /* DELETE satu hadis */ });
test('source checksum mismatch is an error', () { /* ubah satu file di salinan sumber */ });
test('meta.source_checksums mismatch is an error', () {});
test('empty revelation is a warning, not an error', () {});
test('expected totals mismatch is an error', () {
  final r = verifyContentDb(sourceRoot: fixtureDir(''), database: built, expected: fullDatasetTotals);
  expect(r.ok, isFalse);
});
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/content_pipeline/content_db_verifier_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementasi**

Urutan cek sesuai spec 3.4 (1–6). Parse ulang sumber dengan parser Task 3, bandingkan setiap baris dengan `==` pada string penuh. Format pesan error: `ayah <surah>:<ayah> <kolom> differs`, `hadith <slug>:<number> <kolom> differs`, `missing ayah <surah>:<ayah>`, dst. Cek FTS dengan `INSERT INTO ayah_fts(ayah_fts) VALUES('integrity-check')` dan hal yang sama untuk `hadith_fts`; tangkap exception sebagai error. Buka database dengan `OpenMode.readOnly`.

- [ ] **Step 4: Jalankan, pastikan lulus**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/content_pipeline test/content_pipeline
git commit -m "feat: verify content.db row by row against source"
```

---

### Task 7: Skrip CLI dan `content.db` dari data penuh

**Files:**
- Create: `tool/build_content_db.dart`, `tool/verify_content_db.dart`, `tool/prepare_content.sh`
- Modify: `pubspec.yaml` (daftarkan `assets/db/content.db`), `.gitignore` (`assets/db/content.db`), `docs/STATUS.md`
- Test: `test/tool/cli_test.dart`

**Interfaces:**
- Consumes: `buildContentDb`, `verifyContentDb`, `fullDatasetTotals`.
- Produces: perintah `dart run tool/build_content_db.dart [--source data-source] [--out assets/db/content.db]` dan `dart run tool/verify_content_db.dart [--source data-source] [--db assets/db/content.db] [--full]`. Exit code 0 jika sukses, 1 jika ada error. Warning dicetak tetapi tidak menggagalkan.

- [ ] **Step 1: Tulis test yang gagal**

```dart
test('build then verify on fixture exits 0', () async {
  final b = await Process.run('dart', ['run', 'tool/build_content_db.dart',
      '--source', fixtureDir('').path, '--out', out]);
  expect(b.exitCode, 0, reason: b.stderr);
  final v = await Process.run('dart', ['run', 'tool/verify_content_db.dart',
      '--source', fixtureDir('').path, '--db', out]);
  expect(v.exitCode, 0, reason: v.stdout);
});
test('verify --full on fixture exits 1', () async { /* totals tidak cocok */ });
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/tool/cli_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementasi kedua skrip** (parsing argumen dengan `dart:io` sederhana atau `package:args` sebagai dev dependency; jika menambah `args`, catat di commit). Cetak ringkasan: jumlah baris, warning, waktu build, ukuran file.

- [ ] **Step 4: Jalankan pada data penuh**

Run: `dart run tool/build_content_db.dart`
Run: `dart run tool/verify_content_db.dart --full`
Expected: verify exit 0. Warning `revelation empty` untuk 114 surah diperbolehkan (surah_info belum ada). Catat ukuran `assets/db/content.db`.

`content.db` TIDAK di-commit (ada di `.gitignore`); `tool/prepare_content.sh` membuatnya dari `data-source/` dan menjalankan `verify --full`. Catat ukuran file.

- [ ] **Step 5: Daftarkan aset dan jalankan semua test**

Tambahkan `assets/db/content.db` ke `flutter.assets` dan ke `.gitignore`. Jalankan `tool/prepare_content.sh`, lalu `flutter analyze && flutter test`. Expected: bersih dan PASS. Test memakai fixture, bukan `content.db` penuh, tetapi `flutter test` butuh file aset ada (lihat STATUS).

- [ ] **Step 6: Perbarui STATUS.md** (ukuran content.db, data_version, hasil verifikasi, jumlah warning).

- [ ] **Step 7: Commit (dua commit)**

```bash
git add tool test/tool
git commit -m "feat: add build and verify scripts for content.db"
git add tool/prepare_content.sh .gitignore pubspec.yaml
git commit -m "build: add prepare_content script and register content.db asset"
git add docs
git commit -m "docs: update docs for generated content.db"
```

---

### Task 8: Instalasi dan pembukaan `content.db` di aplikasi

**Files:**
- Create: `lib/app/data/sources/content_db_installer.dart`, `lib/app/data/sources/content_database.dart`
- Test: `test/app/content_db_installer_test.dart`, `test/app/content_database_test.dart`

**Interfaces:**
- Produces:
  - `typedef AssetBytesLoader = Future<Uint8List> Function(String assetKey);`
  - `class ContentDbInstaller { ContentDbInstaller({required AssetBytesLoader loadAsset, required Directory targetDir}); Future<File> ensureInstalled(); }`. Mengembalikan file `content.db` di `targetDir`.
  - `class ContentDatabase { static ContentDatabase open(File file); String get dataVersion; Database get raw; void close(); }`. `raw` dipakai repository di fase berikutnya; database dibuka `OpenMode.readOnly`.
  - `const String contentDbAssetKey = 'assets/db/content.db';`

- [ ] **Step 1: Tulis test yang gagal**

Gunakan `content.db` hasil build fixture (Task 5) sebagai byte aset palsu.

```dart
test('installs when target missing', () async {});
test('does not recopy when content.version matches', () async {
  // install, catat lastModified, install lagi, lastModified sama, loader dipanggil 1x untuk cek versi
});
test('recopies when asset content.version differs', () async {
  // install versi test-1, lalu asset berisi versi test-2, hasil content.version terpasang == test-2
});
test('leftover .tmp from interrupted copy is ignored and replaced', () async {
  // buat content.db.tmp berisi sampah, tanpa content.db; ensureInstalled sukses
});
test('corrupt existing content.db is replaced', () async {
  // tulis sampah ke content.db; ensureInstalled menggantinya
});
test('ContentDatabase rejects writes', () {
  final db = ContentDatabase.open(installed);
  expect(() => db.raw.execute('DELETE FROM ayah'), throwsA(isA<SqliteException>()));
});
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/app/content_db_installer_test.dart test/app/content_database_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementasi**

`ensureInstalled`: (1) baca asset kecil `content.version` dan bandingkan dengan file `content.version` terpasang di samping `content.db`; (2) jika sama dan `content.db` terpasang bisa dibuka, kembalikan tanpa menyentuhnya; (3) selain itu (versi beda, `content.db` hilang atau korup, atau file versi terpasang hilang) salin asset lewat `AssetCopier` ke `content.db.tmp` (menimpa sisa `.tmp` lama), `rename` menjadi `content.db`, lalu tulis file versi terpasang paling akhir (tmp lalu rename). Sesuai spesifikasi bagian 5.4.

- [ ] **Step 4: Jalankan, pastikan lulus**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/app/data/sources test/app
git commit -m "feat: install and open content.db read-only"
```

---

### Task 9: `user.db` dengan migrasi

**Files:**
- Create: `lib/app/data/sources/user_database.dart`
- Test: `test/app/user_database_test.dart`

**Interfaces:**
- Produces:
  - `class UserDatabase { static UserDatabase open(File file); int get schemaVersion; String? getSetting(String key); void setSetting(String key, String value); Database get raw; void close(); }`
  - `const int userSchemaVersion = 1;`
  - Kunci setting sebagai konstanta di `class SettingKeys`: `themeMode = 'theme_mode'`, `onlineEnabled = 'online_enabled'`, `prayerSyncEnabled = 'prayer_sync_enabled'`, `onboardingDone = 'onboarding_done'`, `arabicFontScale = 'arabic_font_scale'`, `translationFontScale = 'translation_font_scale'`, `qariId = 'qari_id'`.

- [ ] **Step 1: Tulis test yang gagal**

```dart
test('fresh open creates all v1 tables and sets user_version 1', () {
  final db = UserDatabase.open(File('${tmp.path}/user.db'));
  final tables = db.raw.select("SELECT name FROM sqlite_master WHERE type='table'")
      .map((r) => r['name']).toSet();
  expect(tables, containsAll(['setting','bookmark','last_read','prayer_location','prayer_day','audio_download']));
  expect(db.schemaVersion, 1);
});
test('reopen keeps data and does not re-run migration', () {
  // open, setSetting('theme_mode','dark'), close, open lagi, getSetting == 'dark'
});
test('creates parent directory if missing', () {});
test('bookmark unique constraint rejects duplicates', () {});
test('database newer than app throws a clear error', () {
  // set PRAGMA user_version = 99, open -> throws StateError berisi 'newer'
});
```

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/app/user_database_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementasi**

DDL sesuai spec bagian 4. Migrasi dalam `List<void Function(Database)> _migrations`, indeks ke-0 membuat skema v1. Jalankan migrasi dari `user_version` saat ini sampai `userSchemaVersion` dalam satu transaksi, lalu set `PRAGMA user_version`. `PRAGMA foreign_keys = ON`.

- [ ] **Step 4: Jalankan, pastikan lulus**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/app/data/sources/user_database.dart test/app/user_database_test.dart
git commit -m "feat: add user.db with versioned migrations"
```

---

### Task 10: Bootstrap aplikasi, DI, tema, dan route awal

**Files:**
- Create: `lib/app/app_bootstrap.dart`, `lib/app/core/theme/app_theme.dart`, `lib/app/core/init_failure_view.dart`, `lib/app/modules/onboarding/onboarding_view.dart`, `lib/app/routes/app_routes.dart`, `lib/app/routes/app_pages.dart`
- Modify: `lib/main.dart`, `lib/app/modules/home/home_view.dart`, `test/app/smoke_test.dart`
- Test: `test/app/bootstrap_test.dart`

**Interfaces:**
- Consumes: `ContentDbInstaller`, `ContentDatabase`, `UserDatabase`, `SettingKeys`.
- Produces:
  - `sealed class BootstrapResult`, dengan `BootstrapSuccess { ContentDatabase content; UserDatabase user; }` dan `BootstrapFailure { Object error; }`
  - `Future<BootstrapResult> bootstrap({required ContentDbInstaller installer, required Directory dataDir})`. Mendaftarkan `ContentDatabase` dan `UserDatabase` lewat `Get.put(..., permanent: true)` jika sukses.
  - `class NuraApp extends StatelessWidget { const NuraApp({required this.result, required this.onRetry}); }`
  - `abstract class Routes { static const home = '/home'; static const onboarding = '/onboarding'; }`
  - `ThemeMode themeModeFromSetting(String? value)`: `'light'` → light, `'dark'` → dark, lainnya → system.
  - `AppTheme.light` dan `AppTheme.dark` (`ThemeData`, Material 3, warna dasar bebas tetapi konsisten).

- [ ] **Step 1: Tulis test yang gagal**

```dart
testWidgets('failure shows error screen with retry', (tester) async {
  var retried = false;
  await tester.pumpWidget(NuraApp(result: BootstrapFailure(Exception('x')), onRetry: () => retried = true));
  expect(find.text('Nura tidak bisa dibuka'), findsOneWidget);
  await tester.tap(find.text('Coba lagi'));
  expect(retried, isTrue);
});
testWidgets('first launch goes to onboarding', (tester) async { /* onboarding_done kosong */ });
testWidgets('onboarding_done=true goes to Beranda', (tester) async {});
test('themeModeFromSetting maps values', () {
  expect(themeModeFromSetting('dark'), ThemeMode.dark);
  expect(themeModeFromSetting('light'), ThemeMode.light);
  expect(themeModeFromSetting(null), ThemeMode.system);
  expect(themeModeFromSetting('garbage'), ThemeMode.system);
});
test('bootstrap returns failure when installer throws', () async {});
```

Tes widget memakai `BootstrapSuccess` dengan database dari fixture dan `user.db` di temp dir.

- [ ] **Step 2: Jalankan, pastikan gagal**

Run: `flutter test test/app/bootstrap_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementasi**

`main()`: `WidgetsFlutterBinding.ensureInitialized()`, ambil `getApplicationSupportDirectory()`, buat installer dengan `rootBundle.load`, panggil `bootstrap`, lalu `runApp`. Retry memanggil ulang `bootstrap` dan `runApp`. `InitFailureView`: judul `Nura tidak bisa dibuka`, teks `Terjadi masalah saat menyiapkan data. Coba buka ulang aplikasi.`, tombol `Coba lagi`. `OnboardingView` placeholder: teks `Selamat datang di Nura` dan tombol `Mulai` yang menyimpan `onboarding_done=true` lalu `Get.offAllNamed(Routes.home)`. `HomeView` tetap placeholder `Beranda`, sekarang juga menampilkan `data_version` content.db di teks kecil (berguna untuk uji manual).

- [ ] **Step 4: Jalankan semua test**

Run: `flutter analyze && flutter test`
Expected: bersih dan PASS.

- [ ] **Step 5: Uji manual di emulator atau perangkat**

Run: `flutter run`
Expected: instalasi bersih membuka Onboarding; tekan Mulai menuju Beranda dengan `content.version` terpasang; tutup dan buka lagi langsung ke Beranda; mode pesawat tidak berpengaruh.

- [ ] **Step 6: Perbarui STATUS.md** (Fase 1 selesai, ukuran APK debug, hasil uji manual).

- [ ] **Step 7: Commit**

```bash
git add lib test docs/STATUS.md
git commit -m "feat: bootstrap app with content and user databases"
```

---

## Di Luar Rencana Ini (Fase Berikutnya)

- Menjalankan query berat di isolate (`ContentDatabase` dibuka di isolate pekerja) dikerjakan di Fase 2–4 saat repository pertama dibuat.
- `meta/surah_info.json`, `juz.json`, `cities.json`, `daily_ayah.json` ditambahkan saat sumbernya diputuskan (Q4, Q9). Builder dan verifier sudah menangani ketiadaannya.
