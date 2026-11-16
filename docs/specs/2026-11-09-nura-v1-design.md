# Spec Desain: Nura v1

Status: Disetujui
Tanggal: 2026-11-09 (diperbarui 2026-11-11 dengan keputusan produk putaran desain 1)
Dokumen terkait: `docs/PRD.md`, `AGENTS.md`, `docs/STATUS.md`, `docs/design/` (brief desain UI dan handoff ke Flutter)
Cabang: `main` (Fase 1 dikerjakan di `rebuild/nura` dan sudah di-merge). Fase berikutnya di `feat/phase-N-<nama>`.

## 1. Konteks dan Keputusan

Nura adalah rebuild bersih dari aplikasi Quran lama menjadi aplikasi Islami offline-first. Spec ini menjelaskan *bagaimana* v1 dibangun. Apa yang dibangun ada di PRD.

Keputusan yang sudah disepakati dan menjadi dasar spec ini:

| # | Keputusan |
|---|---|
| D1 | Konten Al-Qur'an dan hadis dibundel sebagai SQLite read-only (`content.db`), dibuat saat build dari JSON di `data-source/`. |
| D2 | Teks asli disalin byte demi byte. Normalisasi hanya di kolom pencarian terpisah. Verifikasi baris demi baris wajib lulus. |
| D3 | Data pengguna di `user.db` yang terpisah. |
| D4 | Fitur online (audio) opsional, mati secara default, lewat satu `OnlineService`. Audio hanya streaming (tanpa unduhan, keputusan 2026-11-16); sakelar mati menyembunyikan semua kontrol audio. |
| D5 | Audio diambil per ayat dari satu penyedia API. |
| D6 | Jadwal sholat diambil dari API per bulan dan disimpan. Izin unduh jadwal terpisah dari sakelar audio dan ditanyakan saat onboarding. |
| D7 | Jika belum ada jadwal tersimpan dan offline, jadwal dihitung offline (paket `adhan`, parameter Kemenag) dan diberi label "perkiraan". |
| D8 | 1 Hari 1 Ayat memakai daftar kurasi dari pemilik proyek. 1 Hari 1 Hadis dipilih otomatis dan yang ditampilkan adalah matan hasil ekstraksi (Arab dan terjemahan, substring persis). Aturan seleksi lengkap ditetapkan di Fase 6 (bagian 8.1); sampai itu dipakai filter panjang sementara. |
| D9 | Widget Android: AppWidgetProvider native yang menampilkan gambar. Gambar dirender dari Flutter karena font LPMQ tidak bisa dipakai di RemoteViews. Strategi awal: gambar untuk 7 hari ke depan ditulis saat aplikasi dibuka (detail di Fase 6). |
| D10 | Nama paket Dart `nura`, Application ID `com.technowstack.nura`. |
| D11 | GetX untuk state, DI, dan routing. |
| D12 | Notifikasi harian ayat/hadis: satu per hari, jam bisa diatur atau dimatikan, default 06.00 dan bisa diubah pengguna. Isi terjemahan dan rujukan, tanpa teks Arab. |
| D13 | Desain UI mengikuti `docs/design/` (brief putaran 1 dan `HANDOFF-flutter.md`). Nilai token bersumber dari `docs/design/tokens.json`. Jalur kode tema tetap `lib/app/core/theme/`. |
| D14 | Hadis harian secara default hanya dari Shahih Bukhari dan Shahih Muslim. Pengguna bisa memperluasnya ke 9 kitab di Pengaturan. |
| D15 | `main` adalah cabang utama. Setiap fase dikerjakan di `feat/phase-N-<nama>`, lalu `merge --no-ff` ke `main` setelah review akhir. |

## 2. Tujuan dan Batasan

**Tujuan teknis**
- Semua fitur inti jalan tanpa internet sejak instalasi pertama.
- Integritas teks dapat dibuktikan secara otomatis di setiap build.
- Lapisan yang jelas: view, controller, repository, source. Setiap lapisan bisa diuji sendiri.
- Tidak ada pemanggilan future di `build()` dan tidak ada `null` yang sampai ke UI.

**Bukan tujuan v1**
- Rilis iOS dan widget iOS.
- Transliterasi Latin, doa-doa, akun, dan sinkronisasi cloud.
- Suara adzan penuh pada notifikasi.

## 3. Pipeline Data

### 3.1 Struktur

```
data-source/
  quran/1.json … 114.json        (sudah ada)
  hadith/*.json                  (sudah ada, 9 kitab)
  meta/
    surah_info.json              arti nama dan tempat turun per surah
    juz.json                     batas 30 juz
    cities.json                  kota: nama, provinsi, lat, lng, id kota di API jadwal
    daily_ayah.json              daftar kurasi ayat harian (disusun pemilik proyek)
  patches/                       (rencana, Q12) teks lengkap untuk entri yang terpotong di sumber, dengan sumber dan lisensi tiap teks (bagian 3.6)
  CHECKSUMS.sha256               mencakup semua file di atas
  README.md

tool/
  build_content_db.dart
  verify_content_db.dart

lib/content_pipeline/            kode bersama (Dart murni): parser JSON, normalisasi pencarian, builder

assets/db/content.db
assets/db/content.version        sidecar versi, dihasilkan bersama content.db
```

File `meta/` ditambahkan bertahap. Sumber dan lisensi setiap file dicatat di `data-source/README.md` sebelum di-commit.

### 3.2 Skema `content.db`

```sql
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- kunci: schema_version, data_version, built_at, source_checksums (JSON)
-- data_version: 16 hex pertama sha256 dari byte data-source/CHECKSUMS.sha256 (turunan, tidak diisi tangan)
-- built_at: tetap 1970-01-01T00:00:00.000Z agar build deterministik

CREATE TABLE surah (
  number       INTEGER PRIMARY KEY,      -- 1..114
  name_arab    TEXT NOT NULL,            -- quran/N.json: name
  name_latin   TEXT NOT NULL,            -- name_latin
  name_id      TEXT NOT NULL,            -- translations.id.name
  ayah_count   INTEGER NOT NULL,         -- number_of_ayah
  revelation   TEXT NOT NULL             -- meta/surah_info.json: 'makkiyah' | 'madaniyah'
);

CREATE TABLE ayah (
  id                  INTEGER PRIMARY KEY,   -- urutan global 1..6236
  surah_number        INTEGER NOT NULL REFERENCES surah(number),
  ayah_number         INTEGER NOT NULL,
  arab                TEXT NOT NULL,         -- text[ayat], apa adanya
  translation_id      TEXT NOT NULL,         -- translations.id.text[ayat], apa adanya
  tafsir_kemenag      TEXT NOT NULL,         -- tafsir.id.kemenag.text[ayat], apa adanya
  UNIQUE (surah_number, ayah_number)
);

CREATE TABLE juz (
  number        INTEGER PRIMARY KEY,   -- 1..30
  start_surah   INTEGER NOT NULL,
  start_ayah    INTEGER NOT NULL,
  end_surah     INTEGER NOT NULL,
  end_ayah      INTEGER NOT NULL
);

CREATE TABLE hadith_book (
  slug          TEXT PRIMARY KEY,      -- nama file tanpa .json, mis. 'bukhari'
  name          TEXT NOT NULL,         -- nama tampilan, mis. 'Shahih Bukhari'
  hadith_count  INTEGER NOT NULL,
  sort_order    INTEGER NOT NULL
);

CREATE TABLE hadith (
  id                  INTEGER PRIMARY KEY,
  book_slug           TEXT NOT NULL REFERENCES hadith_book(slug),
  number              INTEGER NOT NULL,      -- field number
  arab                TEXT NOT NULL,         -- field arab, apa adanya
  translation_id      TEXT NOT NULL,         -- field id, apa adanya
  translation_length  INTEGER NOT NULL,      -- panjang translation_id dalam UTF-16 code unit (String.length Dart)
  UNIQUE (book_slug, number)
);

-- FTS5 contentless: hanya berisi teks hasil normalisasi, rowid = id tabel utama.
-- Kolom tidak bisa di-SELECT; cari lewat MATCH, ambil rowid, lalu baca tabel utama.
CREATE VIRTUAL TABLE ayah_fts USING fts5(
  arab, translation,
  content='', tokenize='unicode61'
);

CREATE VIRTUAL TABLE hadith_fts USING fts5(
  arab, translation,
  content='', tokenize='unicode61'
);

CREATE TABLE daily_ayah (
  seq      INTEGER PRIMARY KEY,        -- 0..n-1, urutan sudah diacak saat build
  ayah_id  INTEGER NOT NULL REFERENCES ayah(id)
);

-- Keputusan 2026-11-15 (Fase 6): dua daftar deterministik, offset matan dalam UTF-16 code unit
-- (indeks String Dart) pada kolom asli hadith.arab dan hadith.translation_id; teks tidak disalin.
CREATE TABLE daily_hadith (
  list        TEXT    NOT NULL CHECK (list IN ('default','all')),  -- default = Bukhari + Muslim, all = 9 kitab
  seq         INTEGER NOT NULL,        -- 0..n-1 per daftar, urutan sudah diacak saat build
  hadith_id   INTEGER NOT NULL REFERENCES hadith(id),
  arab_start  INTEGER NOT NULL,
  arab_end    INTEGER NOT NULL,
  tr_start    INTEGER NOT NULL,
  tr_end      INTEGER NOT NULL,
  PRIMARY KEY (list, seq)
);
```

Nama tampilan kitab hadis ditulis di skrip build sebagai konstanta, karena tidak ada di JSON.

### 3.3 Aturan konversi

- Kolom teks asli diisi dengan string hasil decode JSON tanpa trim, normalisasi Unicode, atau penggantian karakter.
- Field angka bertipe string di JSON Quran (`number`, `number_of_ayah`, kunci ayat) diubah ke `INTEGER`. Verifikasi membandingkan `toString()` hasilnya dengan string asli.
- Teks Arab untuk indeks `*_fts`: hapus harakat (U+064B–U+065F, U+0670), tanda waqaf dan tanda Al-Qur'an (U+06D6–U+06ED), dan tatweel (U+0640). Normalisasi alif (أ إ آ ٱ → ا), ى → ي, ة → ه.
- Teks terjemahan untuk indeks `*_fts`: huruf kecil, tanda baca diganti spasi, spasi beruntun dipadatkan.
- `daily_ayah`: dibaca dari `meta/daily_ayah.json` (daftar pasangan surah dan ayat), diacak dengan seed tetap `20261109`. Jika file belum ada, tabel kosong dan fitur disembunyikan di aplikasi. Langkah pemilik: (1) simpan file di `data-source/meta/daily_ayah.json`; (2) dari folder `data-source/` jalankan `sha256sum meta/daily_ayah.json >> CHECKSUMS.sha256` (manifes dipelihara manual dengan `sha256sum`, lihat `data-source/README.md`; tanpa barisnya builder gagal dengan 'unlisted file'); (3) jalankan `tool/prepare_content.sh`.
- `daily_hadith` (diputuskan 2026-11-15, menggantikan filter sementara 400 code unit): hanya hadis yang lolos aturan matan bagian 8.1 (termasuk syarat (e): tanpa tanda kutip di dalam isi matan), dalam dua daftar, `default` (Bukhari dan Muslim) dan `all` (9 kitab); tiap daftar diurutkan berdasarkan `(sort_order kitab, number)` lalu diacak dengan seed tetap `20261109`. Offset disimpan dalam UTF-16 code unit; pemotongan teks dilakukan di Dart, bukan `substr` SQLite. `data-source/meta/daily_hadith_exclude.json` (format `[{"book": "bukhari", "number": 34}]`, boleh kosong atau tidak ada) mengecualikan hadis secara manual; builder gagal bila entrinya tidak ada di sumber, dan `verify --full` memastikan tidak ada hadis yang dikecualikan atau terpotong (19 hadis, Q12) di `daily_hadith`, setiap offset berada di dalam teks, `seq` rapat dari 0, dan potongan dari kolom asli sama persis dengan matan hasil aturan yang dijalankan ulang oleh verifier. Format `daily_ayah.json`: `[{"surah": 94, "ayah": 6}]`; builder menolak pasangan yang tidak ada, duplikat, atau berformat salah.
- Builder mengisi `ayah_fts` dan `hadith_fts` baris demi baris dengan `rowid` = `id` tabel utama, dan memasang `PRAGMA page_size = 16384` sebelum membuat tabel (file terkecil dari 4096/8192/16384).
- `content.db` dihasilkan lokal oleh `tool/prepare_content.sh` dan tidak di-commit.
- `meta.data_version` diturunkan dari `data-source/CHECKSUMS.sha256` (16 hex pertama sha256 byte manifest). Builder gagal jika manifest tidak ada. Tidak ada flag `--data-version`.
- `meta.built_at` bernilai tetap `1970-01-01T00:00:00.000Z`, sehingga dua build dari input sama menghasilkan file yang identik byte demi byte.
- Setelah `VACUUM`, builder menulis `assets/db/content.version` di samping db dengan isi `<schema_version>:<16 hex pertama sha256 file db final>` (tanpa newline akhir). File ini terdaftar sebagai asset dan di-`.gitignore` seperti `content.db`.
- Header file SQLite mencatat versi libsqlite3 yang menulisnya, jadi build di host dengan versi libsqlite3 berbeda menghasilkan hash berbeda untuk input yang sama. Dampaknya hanya satu kali salin ulang di perangkat, tidak pernah hasil yang salah.
- Build bersifat deterministik: input yang sama (dengan libsqlite3 yang sama) menghasilkan file yang sama.

### 3.4 Verifikasi (`verify_content_db.dart`)

Gagal (exit code bukan 0) jika salah satu syarat tidak terpenuhi:

1. Checksum setiap file di `data-source/` cocok dengan `CHECKSUMS.sha256`.
2. Jumlah baris: 114 surah, 6.236 ayat, 30 juz (jika `juz.json` ada), 9 kitab, 38.102 hadis, dan jumlah per kitab sama dengan panjang array JSON-nya.
3. Setiap ayat: `arab`, `translation_id`, dan `tafsir_kemenag` identik (perbandingan string penuh) dengan JSON sumber. Hal yang sama untuk setiap hadis.
4. `ayah_count` setiap surah sama dengan jumlah baris `ayah`-nya.
5. FTS: jumlah baris indeks (`ayah_fts_docsize`, `hadith_fts_docsize`) sama dengan tabel utama, dan query `MATCH` dengan kata hasil normalisasi dari baris sampel nyata menemukan `rowid` baris tersebut. (`integrity-check` tidak membandingkan isi untuk tabel contentless, jadi tidak dipakai.)
6. `meta.source_checksums` sama dengan isi `CHECKSUMS.sha256`.
7. (`--full`) `content.version` konsisten: `schema_version` sesuai `meta`, dan hash sesuai file db yang ada.

Test `test/tool/` menjalankan verifikasi pada subset data sebagai fixture, termasuk kasus yang harus gagal (satu karakter diubah).

### 3.5 Paket SQLite

Pakai `sqlite3` dan `sqlite3_flutter_libs`. Library SQLite dibundel bersama aplikasi, jadi FTS5 pasti tersedia di semua versi Android. SQLite bawaan Android tidak menjamin FTS5. Skrip di `tool/` juga memakai paket `sqlite3`, jadi pembuat dan pembaca database memakai mesin yang sama.

Paket `sqlite3` bersifat sinkron. Query yang berat (pencarian, daftar panjang) dijalankan di isolate terpisah.

### 3.6 Patch teks sumber (rencana, belum dikerjakan; Q12)

Sebagian teks hadis terpotong di JSON sumber pada batas 16.384 byte UTF-8 (19 hadis; daftar dan aturan deteksi di `docs/plans/2026-11-15-nura-phase3-hadith.md`). Rencana perbaikan, dikerjakan **sebelum rilis** dan bergantung pada Q7 (lisensi teks hadis):

- Teks lengkap disimpan di file patch terpisah di `data-source/patches/`, lengkap dengan sumber dan lisensi tiap teks. JSON asli di `data-source/` tidak diubah dan checksumnya tetap.
- Builder menerapkan patch saat membuat `content.db`, hanya untuk entri yang disebut patch. Kolom dan entri lain tidak berubah.
- Verifier memeriksa JSON asli dan patch masing-masing: teks di `content.db` sama dengan patch untuk entri yang dipatch dan sama dengan JSON asli untuk semua entri lain; patch ikut `CHECKSUMS.sha256`; patch tanpa sumber atau lisensi menggagalkan verifikasi.
- Sampai itu selesai, UI menampilkan catatan bahwa teks terpotong di sumber (Fase 3) dan teks tidak diubah. Teks lengkap tidak boleh diambil dari sumber mana pun sebelum Q7 jelas.
- Pekerjaan ini menyentuh sumber data, builder, dan verifier, jadi butuh persetujuan pemilik proyek saat dikerjakan (AGENTS.md).

## 4. Database Pengguna (`user.db`)

```sql
CREATE TABLE setting (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- theme_mode, online_enabled, prayer_sync_enabled, onboarding_done,
-- arabic_font_scale, translation_font_scale, qari_id,
-- notify_fajr … notify_isha, prayer_adjust_fajr … prayer_adjust_isha,
-- notifikasi harian ayat/hadis: sakelar dan jam (default 06:00), dan sumber hadis harian
-- (default Bukhari dan Muslim, bisa diperluas ke 9 kitab); nama kunci ditetapkan di Fase 6

CREATE TABLE bookmark (
  id          INTEGER PRIMARY KEY,
  kind        TEXT NOT NULL CHECK (kind IN ('ayah','hadith')),
  ref_a       TEXT NOT NULL,     -- surah_number atau book_slug
  ref_b       INTEGER NOT NULL,  -- ayah_number atau number hadis
  created_at  INTEGER NOT NULL,
  UNIQUE (kind, ref_a, ref_b)
);

CREATE TABLE last_read (
  kind        TEXT PRIMARY KEY CHECK (kind IN ('ayah','hadith')),
  ref_a       TEXT NOT NULL,
  ref_b       INTEGER NOT NULL,
  updated_at  INTEGER NOT NULL
);

CREATE TABLE prayer_location (
  id        INTEGER PRIMARY KEY CHECK (id = 1),
  provinsi  TEXT NOT NULL,         -- nama persis dari API equran.id; zona waktu diturunkan dari provinsi
  kabkota   TEXT NOT NULL,
  source    TEXT NOT NULL CHECK (source IN ('city','gps'))
);

CREATE TABLE prayer_day (
  date      TEXT NOT NULL,          -- yyyy-MM-dd
  provinsi  TEXT NOT NULL,
  kabkota   TEXT NOT NULL,
  imsak TEXT, subuh TEXT, terbit TEXT, dhuha TEXT,
  dzuhur TEXT, ashar TEXT, maghrib TEXT, isya TEXT,   -- HH:mm waktu lokal wilayah
  source    TEXT NOT NULL CHECK (source IN ('api','calc')),
  fetched_at INTEGER NOT NULL,      -- epoch ms
  PRIMARY KEY (date, provinsi, kabkota)
);

CREATE TABLE prayer_month (
  provinsi  TEXT NOT NULL,
  kabkota   TEXT NOT NULL,
  year      INTEGER NOT NULL,
  month     INTEGER NOT NULL,
  status    TEXT NOT NULL CHECK (status IN ('ok','none')),   -- none = API tidak punya data bulan itu
  fetched_at INTEGER NOT NULL,
  PRIMARY KEY (provinsi, kabkota, year, month)
);

-- TIDAK DIPAKAI (keputusan 2026-11-16: audio hanya streaming). Tabel dibiarkan dari v1, tanpa migrasi.
CREATE TABLE audio_download (
  qari_id      TEXT NOT NULL,
  surah_number INTEGER NOT NULL,
  status       TEXT NOT NULL CHECK (status IN ('partial','complete')),
  ayah_done    INTEGER NOT NULL,
  bytes        INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  PRIMARY KEY (qari_id, surah_number)
);
```

Migrasi memakai `PRAGMA user_version`, dengan satu fungsi migrasi per versi. Skema di atas adalah `user_version` 2 (migrasi v2 menghapus dan membuat ulang `prayer_location` dan `prayer_day`, yang belum pernah dipakai, dan menambah `prayer_month`).

## 5. Arsitektur Aplikasi

### 5.1 Lapisan

```
View  →  Controller  →  Repository  →  Source (SQLite / HTTP / platform)
                    ↘  Service (lintas fitur)
```

- **View**: hanya membaca state reaktif dari controller dan meneruskan aksi pengguna.
- **Controller** (GetxController): memegang state layar dalam bentuk `UiState<T>` (`loading`, `empty`, `data`, `error`). Memanggil repository di `onInit` atau saat ada aksi.
- **Repository**: antarmuka abstrak plus implementasi. Mengembalikan model domain dan tidak pernah mengembalikan baris mentah atau JSON.
- **Source**: satu-satunya lapisan yang menyentuh SQLite, HTTP, atau API platform.

### 5.2 Komponen

```
lib/
  main.dart                      inisialisasi: pasang content.db (installer), buka DB, register service, runApp
  app/
    core/
      theme/                     tema terang dan gelap, tipografi Arab, token (lihat 5.6)
      ui_state.dart
      errors.dart                tipe error domain (ContentUnavailable, NetworkUnavailable, …)
      date_utils.dart
    data/
      sources/
        content_database.dart    membuka content.db read-only, menjalankan query di isolate
        user_database.dart       membuka user.db, migrasi
        audio_api_client.dart    klien HTTP penyedia audio
        prayer_api_client.dart   klien HTTP penyedia jadwal
      models/
        surah.dart, ayah.dart, juz.dart, hadith_book.dart, hadith.dart,
        bookmark.dart, last_read.dart, prayer_location.dart, prayer_day.dart,
        daily_content.dart, search_result.dart
      repositories/
        quran_repository.dart
        hadith_repository.dart
        search_repository.dart
        user_repository.dart          setting, bookmark, last read
        prayer_repository.dart        API + cache + fallback perhitungan
        daily_content_repository.dart
        audio_repository.dart         URL audio per surah (cache sesi), tanpa unduhan
    services/
      online_service.dart        sakelar dan cek koneksi; gerbang semua request
      audio_player_service.dart  just_audio, antrian per ayat
      notification_service.dart  penjadwalan pengingat sholat dan notifikasi harian
      home_widget_service.dart   merender gambar widget (Flutter) untuk 7 hari ke depan dan menulisnya ke widget
    modules/
      onboarding/  home/  quran_list/  quran_detail/  juz/
      hadith_books/  hadith_list/  hadith_detail/
      search/  bookmarks/  prayer/  settings/  about/
    routes/
      app_routes.dart, app_pages.dart
android/app/src/main/kotlin/com/technowstack/nura/
  DailyAyahWidgetProvider.kt     menampilkan gambar widget
  DailyHadithWidgetProvider.kt   menampilkan gambar widget
```

### 5.3 Navigasi

- Bottom navigation dengan 4 tab: **Beranda**, **Al-Qur'an**, **Hadis**, **Sholat**.
- **Beranda** (urutan sesuai desain putaran 1): header salam dengan tanggal Hijriah dan Masehi serta ikon cari, kartu waktu sholat berikutnya beserta hitung mundur, kartu Last Read (satu baris, tombol Lanjutkan), kartu Ayat Hari Ini (menonjol), dan kartu Hadis Hari Ini (lebih sederhana). Menu cepat yang menduplikasi navigasi bawah dihapus dari desain. Pintu masuk ke Pengaturan belum didesain (putaran 2).
- **Al-Qur'an**: tab Surah, Juz, dan Bookmark beserta kolom cari, lalu Detail Surah. Tafsir dan pengaturan tampilan baca berupa bottom sheet.
- **Hadis**: daftar kitab, lalu daftar hadis (paging 30 per halaman), lalu Detail Hadis.
- **Sholat**: jadwal hari ini, pilihan lokasi, pengaturan notifikasi, label "perkiraan" jika sumbernya `calc`.
- **Pengaturan**: tema, ukuran font, Fitur Online, qari, sinkron jadwal, sumber hadis harian (default Bukhari dan Muslim, bisa diperluas ke 9 kitab), Sumber & Atribusi.
- Route awal: Onboarding jika `onboarding_done` belum `true`, selain itu Beranda.

### 5.4 Inisialisasi aplikasi

1. Pasang `content.db` lewat installer. Pada start normal installer hanya membaca asset kecil `content.version` dan membandingkannya dengan file `content.version` terpasang di samping `content.db`. Asset besar disalin hanya jika versi berbeda, `content.db` terpasang tidak ada atau tidak bisa dibuka, atau file versi terpasang tidak ada.
   - Penyalinan memakai fungsi `AssetCopier`. Di Android, MethodChannel `com.technowstack.nura/asset_copy` (`MainActivity.kt`) mengalirkan `flutter_assets/<assetKey>` lewat AssetManager ke tujuan (buffer 1 MiB, di luar main thread) tanpa memuat 112 MB ke RAM. Platform lain dan test memakai `rootBundle`.
   - Urutan: tulis ke `content.db.tmp`, `rename` ke `content.db`, dan tulis file versi terpasang paling akhir (tmp lalu rename). Jika proses terhenti di tengah, versi tidak cocok dan start berikutnya menyalin ulang.
2. Buka `content.db` dengan mode read-only dan `user.db` dengan mode read-write (jalankan migrasi).
3. Daftarkan source, repository, dan service sebagai singleton GetX.
4. Render gambar widget untuk 7 hari ke depan dan jadwalkan ulang notifikasi, sholat dan harian (tanpa menahan tampilan pertama).

### 5.5 Pencarian: cuplikan hasil

Aturan ini juga menjadi spesifikasi implementasi (dari desain putaran 1, layar 10).

- Pencarian tidak peka huruf besar/kecil. **Terjemahan**: kata cocok = substring, lewat `LIKE '%kata%' ESCAPE '\\'` pada kolom teks asli (satu `LIKE` per kata, digabung AND; `%`, `_`, dan `\\` di input di-escape; keputusan 2026-11-15). **Teks Arab**: kata cocok = awalan token, lewat indeks FTS yang dinormalisasi. Keterbatasan v1: kata Arab berawalan seperti ال atau ب tidak ditemukan dari bentuk dasarnya (dan sebaliknya tidak ada pencocokan di tengah kata). Hasil dikelompokkan per surah. Keadaan kosong menampilkan "Tidak ada hasil". `ayah.arab` memakai rasm Utsmani (alif kecil U+0670), jadi `ayah_fts.arab` menyimpan dua bentuk ternormalisasi per ayat (Q13, keputusan 2026-11-15): bentuk biasa (alif kecil dibuang) dan bentuk varian (alif kecil dibaca alif; U+0670 diikuti waw yang bukan diikuti U+0670 lagi menjadi satu alif, mis. ٱلصَّلَٰوة → الصلاه, ٱلسَّمَٰوَٰت → السماوات). Kueri pengguna dinormalisasi seperti biasa (tanpa perluasan kueri) dan cocok dengan salah satu bentuk, sehingga الصلاة, الزكاة, الحياة, السماوات, إبراهيم, الكتاب menemukan ayatnya. Indeks hadis tidak berubah. Sorotan cuplikan mencocokkan kedua bentuk pada teks asli. Batas yang tersisa: kata berawalan ال/ب dari bentuk dasar, dan ejaan yang berbeda selain alif kecil (mis. ya kecil).
- Terjemahan tiap hasil ditampilkan sebagai satu `Text.rich`, maksimal 3 baris.
- Cuplikan berpusat pada kemunculan pertama kata cocok: jendela maksimal 100 karakter, digeser agar tidak melewati awal atau akhir teks, lalu dipotong ke batas kata (spasi terdekat) tanpa memotong kata cocok. Tanda baca tetap menempel pada kata.
- Elipsis "…" ditambahkan di depan jika awal teks dipotong dan di belakang jika akhir dipotong. Isi cuplikan (tanpa elipsis) harus berupa substring persis dari terjemahan. Teks yang lebih pendek dari 100 karakter tampil utuh.
- Semua kemunculan kata cocok di dalam cuplikan disorot dengan `TextSpan(backgroundColor: searchHighlight)`.
- Kasus uji: Al-Baqarah 45 (kata di tengah, elipsis belakang), Al-Baqarah 153 (elipsis depan dan belakang), Ali 'Imran 146 (kata di akhir ayat, elipsis depan), An-Nahl 42 (ayat pendek, tanpa elipsis).

### 5.6 Tema dan tipografi

- Material 3. Nilai token (warna Light dan Dark, tipografi, jarak, radius) bersumber dari `docs/design/tokens.json`. Pemetaan ke Flutter dan aturan komponen ada di `docs/design/HANDOFF-flutter.md`.
- Lokasi kode di `lib/app/core/theme/`: `ColorScheme` untuk peran Material, `NuraColors` (ThemeExtension) untuk warna tambahan (teks Arab, sorotan terakhir dibaca, sorotan pencarian, ornamen, lencana offline), `TextTheme` untuk teks Latin, `NuraTextStyles` (ThemeExtension) untuk gaya Arab dan terjemahan, serta konstanta jarak dan radius di `tokens.dart`.
- Font Latin: Plus Jakarta Sans (OFL). Font Arab: LPMQ Isep Misbah, cadangan KFGQPC Uthmanic Script Hafs. Lisensi font Arab dicek sebelum rilis (Q6). Ukuran teks Arab diatur pengguna 20–40, default 28.
- Aksesibilitas: kontras teks minimal 4.5:1 dan ikon minimal 3:1 di kedua mode, target sentuh minimal 48 × 48, status tidak hanya dibedakan dengan warna, dan tata letak tetap utuh pada teks Arab 36 dan Latin 130%.

## 6. Fitur Online

### 6.1 `OnlineService`

- `bool get audioEnabled` dari setting `online_enabled` (default `false`).
- `bool get prayerSyncEnabled` dari setting `prayer_sync_enabled` (ditanyakan saat onboarding).
- `Future<bool> canReach()` mengecek koneksi lewat `connectivity_plus`. Hasil ini hanya petunjuk awal. Kegagalan request tetap ditangani.
- Klien HTTP hanya bisa dipanggil lewat repository yang terlebih dulu bertanya ke `OnlineService`.

### 6.2 Audio

Keputusan 2026-11-16: audio **hanya streaming**, tanpa unduhan.

- Penyedia: equran.id v2 (diputuskan 2026-11-16, Q3 audio). URL audio per ayat diambil dari respons `GET https://equran.id/api/v2/surat/{id}` (`data.ayat[].audio`, peta id qari `01`–`06` ke URL), satu permintaan per surah per sesi dan disimpan di memori selama sesi. URL hanya diterima bila `https` dan berhost `cdn.equran.id` (`audio_api_client.dart`). Konfirmasi tertulis ke equran.id dianjurkan sebelum rilis, tidak wajib.
- Streaming saja: aplikasi tidak menulis berkas audio ke penyimpanan perangkat (cache buffer bawaan pemutar boleh). Tidak ada unduhan, tidak ada layar kelola unduhan. Tabel `audio_download` (bagian 4) tidak dipakai.
- Sakelar "Fitur Online" mati (default): nol permintaan jaringan audio dan semua kontrol audio tersembunyi. Sakelar nyala tetapi tidak ada koneksi: kontrol audio tampil nonaktif dengan keterangan "Butuh internet".
- Putar ayat: streaming dari URL ayat qari terpilih (default `05` Misyari Rasyid Al-Afasi, disimpan di `qari_id`).
- Putar surah: antrian berurutan dari ayat yang dipilih sampai akhir surah. Ayat yang sedang diputar di-highlight dan daftar menggulir mengikutinya. Tidak ada berkas Basmalah terpisah, jadi Basmalah tidak disisipkan.
- Pemutaran hanya saat aplikasi terlihat dan dijeda saat aplikasi ke latar belakang (v1; tanpa `just_audio_background` dan tanpa izin foreground service).
- Kegagalan streaming (koneksi putus, URL 404, respons janggal): pemutaran berhenti dengan snackbar, tidak ada layar error.
- Atribusi di layar Sumber & Atribusi (Fase 8): "Audio: EQuran.id (sumber: Verse By Verse Quran)".

## 7. Jadwal Sholat

### 7.1 Sumber

- **API** (diputuskan 2026-11-15: equran.id v2, `https://equran.id/api/v2/shalat`, dokumentasi `https://equran.id/apidev/shalat`; syarat layanan belum dibaca, wajib dibaca sebelum rilis): ambil sekali per bulan per wilayah (bulan berjalan, bulan berikutnya bila perlu) lalu simpan ke `prayer_day` dengan `source = 'api'`. Rate limit tidak didokumentasikan: batasi permintaan, jangan polling.
- **Perhitungan offline** (`adhan`): Subuh 20°, Isya 18°, Asar mazhab Syafi'i. Ihtiyat bawaan (keputusan 2026-11-15, Q5): +3 menit untuk subuh, dzuhur, ashar, maghrib, isya dan -3 menit untuk terbit, diukur terhadap API pada November 2026 untuk Jakarta dan Bontang (selisih akhir maksimal 1 menit). Catatan: metode Singapore di `adhan` sudah menambah +1 menit pada dzuhur, jadi ihtiyat efektif dzuhur terhadap waktu astronomis adalah +4 (konstanta kita +3 di atas metode). Penyesuaian dari setting (`prayer_adjust_*`) ditambahkan di atasnya. Imsak = subuh (setelah ihtiyat) - 10 menit. Dhuha tidak dihitung (aturan belum ditetapkan). Kalkulator hanya aktif bila koordinat wilayah ada. Simpan dengan `source = 'calc'`.

### 7.2 Alur

1. Saat jadwal dibutuhkan untuk tanggal D di kota K: cek `prayer_day(D, K)`.
2. Jika ada dan `source = 'api'`, pakai.
3. Jika tidak ada atau `source = 'calc'`, dan `prayerSyncEnabled` serta ada koneksi: ambil dari API untuk bulan D, simpan, lalu pakai.
4. Jika API gagal atau tidak diizinkan: hitung offline bila koordinat wilayah tersedia (Q4), simpan sebagai `calc`, dan tampilkan label "perkiraan". Bila koordinat tidak tersedia (keadaan v1), tampilkan "Butuh internet untuk jadwal pertama".
5. Saat aplikasi dibuka (dan saat wilayah berganti): ambil bulan berjalan bila belum ada, dan bulan berikutnya bila belum ada. Tidak ada sinkron di latar belakang di v1.

### 7.3 Lokasi

- Model lokasi (keputusan 2026-11-15): provinsi + kabupaten/kota dengan nama persis dari API, bukan koordinat. Skema `prayer_location` disesuaikan lewat migrasi `user.db` baru saat Fase 5. Dokumentasi API menyebut 34 provinsi, Indonesia kini 38: cek saat Fase 5.
- Notifikasi dijadwalkan dalam zona waktu wilayah (WIB/WITA/WIT), bukan zona perangkat.
- Pilihan wilayah: daftar dari snapshot `data-source/meta/prayer_regions.json` (keputusan 2026-11-15), dibuat skrip `tool/fetch_prayer_regions.dart` dari API (berisi `fetched_at`) dan dijalankan ulang sebelum rilis; dengan pencarian nama. Snapshot dipakai agar pemilih jalan offline.
- Zona waktu: dipetakan per provinsi ke WIB/WITA/WIT dengan offset tetap (Indonesia tanpa DST); respons API tidak memuat zona waktu.
- Bila wilayah tersimpan dijawab 404 oleh API (mis. API berubah ke 38 provinsi), pengguna diminta memilih ulang wilayah dan jadwal serta notifikasi lama dihentikan; tidak gagal diam-diam.
- Tidak ada GPS dan tidak ada izin lokasi di v1 (keputusan 2026-11-15; paket `geolocator` ditunda). Cadangan `adhan` memakai koordinat wilayah dan baru aktif bila koordinat per kab/kota tersedia (Q4).

### 7.4 Notifikasi

- `flutter_local_notifications`, dijadwalkan dari `prayer_day` sampai akhir data tersimpan, maksimal 30 hari dari hari ini. Pada hari terakhir data tersimpan dikirim satu notifikasi "Buka Nura untuk memperbarui jadwal sholat.".
- Penjadwalan ulang terjadi saat aplikasi dibuka, setelah HP restart (receiver `BOOT_COMPLETED`), dan saat lokasi atau setting notifikasi berubah.
- Setiap waktu sholat punya sakelar sendiri. Suara pakai bunyi notifikasi bawaan.
- Android 12 ke atas: minta izin alarm tepat waktu dengan penjelasan. Jika ditolak, pakai alarm tidak tepat waktu dan tampilkan keterangan di layar Sholat.
- Android 13 ke atas: izin notifikasi diminta di onboarding langkah c (bisa dilewati) atau saat pengguna pertama kali menyalakan pengingat.

## 8. 1 Hari 1 Ayat/Hadis dan Widget

### 8.1 Pemilihan

- `dayIndex = jumlah hari sejak 2026-01-01 (tanggal lokal)`.
- Ayat hari ini: `daily_ayah` dengan `seq = dayIndex mod count`. Jika tabel kosong, kartu dan widget ayat disembunyikan atau menampilkan keterangan.
- Hadis hari ini: `daily_hadith` dengan `seq = dayIndex mod count`.
- Yang ditampilkan adalah **matan** hasil ekstraksi, bukan hadis lengkap. Data tidak punya field matan terpisah, jadi: matan Arab adalah substring persis dari teks Arab (contoh Shahih Bukhari No. 34: dari "مَنْ يَقُمْ" sampai akhir), dan matan terjemahan adalah substring persis dari terjemahan (teks di dalam tanda kutip setelah "bersabda:", tanpa sanad). Keduanya harus bisa diekstrak bersih agar hadis lolos seleksi, dan ekstraksinya wajib diuji terhadap teks sumber.
- Aturan seleksi (diputuskan 2026-11-15; N = 300): hadis bukan salah satu dari 19 yang terpotong, tidak ada di `daily_hadith_exclude.json`, dan lolos semuanya: (a) terjemahan: `shallallahu 'alaihi wasallam` pertama diikuti dalam ≤ 14 karakter oleh `bersabda: "` (atau tanda kutip lengkung), matan = isi antara tanda kutip pembuka itu dan tanda kutip terakhir, sesudah tanda kutip penutup hanya boleh spasi dan tanda baca penutup, tanpa `[` `]`, tanpa tanda kutip di dalamnya dan tanpa "bersabda:" kedua di dalamnya, minimal 10 karakter; (b) Arab: pada bentuk ternormalisasi matan dimulai tepat setelah `صلى الله عليه وسلم` pertama (melewati satu kata kerja ucap opsional) sampai akhir teks, minimal 10 karakter, offset dipetakan ke teks asli bervokal; (c) terjemahan matan ≤ 300 UTF-16 code unit dan Arab ≤ 300 karakter; (d) rasio panjang terjemahan/Arab antara 0,8 dan 3,0; (e) tidak ada tanda kutip (`"`, `“`, `”`) di dalam isi matan terjemahan, karena matan adalah satu kutipan utuh dan tanda kutip di dalamnya berarti dialog atau komentar (tanda kutip tunggal `'` tidak dihitung). Pada data: 1.141 hadis untuk `default` dan 4.544 untuk 9 kitab. Skrip `tool/` menghasilkan 50 sampel acak deterministik dari daftar `default` ke berkas markdown untuk diperiksa pemilik; pemeriksaan itu adalah syarat rilis.
- Sumber hadis harian: secara default hanya Shahih Bukhari dan Shahih Muslim (daftar `default`); pengguna bisa memperluasnya ke 9 kitab (daftar `all`) di pengaturan harian, dengan keterangan "Kitab selain Bukhari dan Muslim memuat hadis dengan derajat yang beragam." saat memilih 9 kitab.
- Rujukan: ayat `QS. <Nama Latin>: <ayat>` (mis. "QS. Asy-Syarh: 6") dan hadis `HR. <Kitab> No. <nomor>` (mis. "HR. Shahih Bukhari No. 34"). Nama kitab dari `hadithBookNames` di `lib/content_pipeline/content_schema.dart`.
- Kartu Hadis di Beranda lebih sederhana daripada kartu Ayat. Kartu dan widget selalu menampilkan rujukan (`HR. <Kitab> No. <nomor>` atau `QS. <Nama Latin>: <ayat>`); mengetuk rujukan atau "Baca selengkapnya" membuka hadis lengkap dengan sanad (layar detail masuk putaran desain 2), dan pada widget seluruh gambar adalah satu area ketuk menuju detail yang sama.
- Hasilnya sama untuk semua pengguna di tanggal yang sama, selama isi `content.db` dan setelan sumber hadis sama (`content.version` sama). Pengguna yang memperluas sumber ke 9 kitab bisa melihat hadis yang berbeda dari setelan default.

### 8.2 Widget Android

- Dua widget, "Ayat hari ini" dan "Hadis hari ini", lewat `DailyAyahWidgetProvider` dan `DailyHadithWidgetProvider`. Ukuran 4×2 dan 4×3 cell, dengan varian terang dan gelap. Provider native hanya menampilkan gambar.
- Gambar dirender oleh Flutter karena font Arab LPMQ tidak bisa dipakai di RemoteViews. Flutter merender sesuai ukuran widget yang diminta Android (ukuran sebenarnya bergantung launcher).
- Karena berupa gambar, widget statis: tanpa tombol di dalamnya, dan seluruh widget adalah satu area ketuk. Isinya label, matan Arab, terjemahan, dan rujukan. Teks yang melebihi ruang dipotong dengan elipsis (Arab 1 baris di 4×2 dan 2 baris di 4×3, terjemahan 1 dan 3 baris). Radius ±24 (widget Android 12+).
- Strategi awal: saat aplikasi dibuka, `HomeWidgetService` merender dan menulis gambar untuk 7 tanggal ke depan ke penyimpanan `home_widget`. Setiap entri berisi tanggal, gambar, deep link, dan teks TalkBack (`description`, opsional). Penyegaran (`DailyRefresher`) berjalan setelah frame pertama, saat aplikasi dilanjutkan, saat tanggal lokal berganti (timer tengah malam Beranda), dan saat sumber hadis berubah (dipaksa). Perubahan setelan notifikasi menjadwalkan ulang notifikasi langsung; dilewati bila tanggal sama dengan penyegaran sukses terakhir. Detail kontrak penyimpanan ada di plan Fase 6.
- Provider native memilih entri sesuai tanggal hari ini setiap kali di-update: `updatePeriodMillis` sekitar 3 jam, alarm tengah malam dari `home_widget` (`HomeWidgetScheduler`), serta siaran ubah ukuran, waktu, dan zona waktu. Setelah menulis gambar baru, aplikasi meminta provider menggambar ulang lewat `HomeWidget.updateWidget`.
- Jika entri untuk hari ini tidak ada (aplikasi tidak dibuka lebih dari 7 hari), widget menampilkan "Buka Nura untuk memperbarui".
- Ketuk widget membuka aplikasi di Detail Surah atau Detail Hadis lewat deep link `nura://ayah/<surah>/<ayat>` atau `nura://hadith/<slug>/<nomor>`.

### 8.3 Notifikasi harian

- Satu notifikasi per hari pada jam yang bisa diatur atau dimatikan pengguna. Default 06.00, bisa diubah pengguna.
- Notifikasi tidak bisa memakai font khusus, jadi isinya terjemahan dan rujukan saja, tanpa teks Arab. Tampilan collapsed dan expanded (BigText) memakai gaya notifikasi Android standar dan ikon kecil aplikasi.
- Memakai `flutter_local_notifications`. Mekanisme penjadwalannya mengikuti bagian 7.4 (dijadwalkan ulang saat aplikasi dibuka, setelah HP restart, dan saat pengaturan berubah).
- Ketuk notifikasi membuka Beranda dengan kartu harian.
- Sakelar "Ayat & hadis harian" ada di onboarding langkah c, bersama "Pengingat adzan". Pengaturan lengkapnya didesain di putaran 2.

## 9. Penanganan Error

| Kondisi | Perilaku |
|---|---|
| Gagal menyalin atau membuka `content.db` | Layar error penuh dengan tombol "Coba lagi". Penyebab dicatat di log. |
| Query konten gagal | `UiState.error` dengan pesan singkat dan tombol coba lagi. Tidak crash. |
| Hasil kosong (pencarian, bookmark) | `UiState.empty` dengan teks penjelas. |
| Tidak ada koneksi atau sakelar mati | Kontrol online dinonaktifkan dengan keterangan. Tidak ada dialog error. |
| Request API gagal | Audio: berhenti dan tampilkan snackbar. Jadwal: pakai fallback perhitungan. |
| Izin notifikasi atau alarm tepat ditolak | Tampilkan keterangan (tanpa tautan di v1; tautan ke pengaturan sistem direncanakan kemudian). |
| `user.db` gagal migrasi | Cadangkan file lama, buat baru, dan beri tahu pengguna bahwa bookmark mungkin hilang. |

## 10. Pengujian

- **Tool**: test build dan verifikasi pada fixture kecil, termasuk kasus gagal.
- **Repository**: test dengan database in-memory dari fixture. Contohnya daftar surah, ayat per surah, paging hadis, pencarian, bookmark, dan last read.
- **Normalisasi pencarian**: test unit untuk contoh teks Arab dan Indonesia.
- **Jadwal sholat**: test perhitungan offline terhadap jadwal resmi Kemenag untuk Bontang dan Jakarta pada beberapa tanggal, toleransi ±2 menit. Test alur cache, API, dan fallback dengan klien API tiruan.
- **Konten harian**: test bahwa `dayIndex` yang sama selalu menghasilkan konten yang sama, dan berganti antar hari.
- **Matan harian** (Fase 6): test bahwa matan Arab dan matan terjemahan adalah substring persis dari sumber, dan seleksi menolak hadis yang tidak bisa diekstrak bersih.
- **Cuplikan pencarian**: test unit untuk aturan bagian 5.5 pada empat kasus uji (isi cuplikan tanpa elipsis adalah substring persis, jendela maksimal 100 karakter, elipsis sesuai sisi yang terpotong, semua kata cocok disorot).
- **Controller**: test transisi `UiState` dengan repository tiruan.
- **Manual di perangkat**: widget, notifikasi, audio, alur offline (mode pesawat), dan instalasi bersih.
- `flutter analyze` bersih dan `flutter test` lulus sebelum setiap commit.

## 11. Fase Implementasi

| Fase | Isi | Selesai jika |
|---|---|---|
| 1. Fondasi | Hapus kode lama di `lib/`, ganti nama paket dan Application ID, struktur folder, `sqlite3`, skrip build dan verifikasi, `content.db` dari data Quran dan hadis, `user.db`, inisialisasi, tema | `verify_content_db` lulus. Aplikasi terbuka ke Beranda kosong. Test lulus. |
| 2. Al-Qur'an | Daftar surah, detail, tafsir, juz (setelah `juz.json`), bookmark, last read, ukuran font | Bisa dibaca penuh secara offline |
| 3. Hadis | Daftar kitab, daftar dengan paging, detail, bookmark | Semua 9 kitab bisa dibaca offline |
| 4. Pencarian | FTS ayat dan hadis, layar pencarian, cuplikan hasil dan sorotan (bagian 5.5) | Pencarian di semua hadis di bawah 1 detik di perangkat uji |
| 5. Jadwal sholat | Lokasi, API dan cache, fallback, layar Sholat, notifikasi | Jadwal tampil offline dan online, notifikasi berbunyi |
| 6. Konten harian | Kartu di Beranda, aturan seleksi hadis (matan), widget Android (gambar dari Flutter), notifikasi harian | Widget berganti setiap hari tanpa membuka aplikasi, dan notifikasi harian muncul pada jam yang diatur |
| 7. Fitur online | Sakelar, audio streaming per ayat dan per surah | Audio jalan online; offline menampilkan "Butuh internet"; sakelar mati = nol permintaan |
| 8. Polish | Onboarding, Sumber & Atribusi, ikon, uji perangkat, persiapan Play Store | Siap rilis, terblokir oleh Q6 dan Q7 |

Fase 2 dan seterusnya membutuhkan Fase 1. Fase 5 membutuhkan snapshot `meta/prayer_regions.json` (dibuat `tool/fetch_prayer_regions.dart`). Fase 6 untuk ayat membutuhkan `daily_ayah.json`.

## 12. Pertanyaan Terbuka yang Memengaruhi Spec

| ID | Pertanyaan | Memengaruhi |
|---|---|---|
| Q2 | Nama aplikasi Nura (Play Store, DJKI) | Fase 8 |
| Q3 | Penyedia API audio dan jadwal, beserta syarat penggunaannya. Jadwal: diputuskan equran.id v2 (2026-11-15), syarat layanan belum dibaca (wajib sebelum rilis). Audio: diputuskan equran.id v2 (2026-11-16); konfirmasi tertulis ke equran.id dianjurkan sebelum rilis, tidak wajib | Fase 7, rilis |
| Q4 | Sumber `surah_info.json`, `juz.json`, dan koordinat per kab/kota (pengganti `cities.json`; hanya untuk cadangan offline) | Fase 1 (revelation), 2 (juz), 5 |
| Q5 | Nilai ihtiyat dan parameter perhitungan offline. Diputuskan 2026-11-15: +3 menit prayer, -3 menit terbit | Fase 5 |
| Q6 | Ketentuan tashih LPMQ dan lisensi font Arab (LPMQ Isep Misbah; cadangan KFGQPC Uthmanic Script Hafs) | Rilis |
| Q7 | Lisensi teks terjemahan hadis | Rilis |
| Q8 | Verifikasi data ke sumber asli | Sebelum rilis |
| Q9 | Daftar kurasi `daily_ayah.json` (disusun pemilik proyek) | Fase 6 |
| Q12 | Patch teks hadis yang terpotong di sumber (bagian 3.6); bergantung pada Q7 | Sebelum rilis |

Jika `surah_info.json` belum tersedia di Fase 1, kolom `revelation` diizinkan sementara bernilai `''` dan UI tidak menampilkannya. Verifikasi menandainya sebagai peringatan, bukan kegagalan, sampai file tersedia.
