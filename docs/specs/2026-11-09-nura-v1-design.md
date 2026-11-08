# Spec Desain: Nura v1

Status: Disetujui
Tanggal: 2026-11-09
Dokumen terkait: `docs/PRD.md`, `AGENTS.md`, `docs/STATUS.md`
Branch: `rebuild/nura`

## 1. Konteks dan Keputusan

Nura adalah rebuild bersih dari aplikasi Quran lama menjadi aplikasi Islami offline-first. Spec ini menjelaskan *bagaimana* v1 dibangun. Apa yang dibangun ada di PRD.

Keputusan yang sudah disepakati dan menjadi dasar spec ini:

| # | Keputusan |
|---|---|
| D1 | Konten Al-Qur'an dan hadis dibundel sebagai SQLite read-only (`content.db`), dibuat saat build dari JSON di `data-source/`. |
| D2 | Teks asli disalin byte demi byte. Normalisasi hanya di kolom pencarian terpisah. Verifikasi baris demi baris wajib lulus. |
| D3 | Data pengguna di `user.db` yang terpisah. |
| D4 | Fitur online (audio) opsional, mati secara default, lewat satu `OnlineService`. Audio yang sudah diunduh tetap bisa diputar saat sakelar mati. |
| D5 | Audio diambil per ayat dari satu penyedia API. |
| D6 | Jadwal sholat diambil dari API per bulan dan disimpan. Izin unduh jadwal terpisah dari sakelar audio dan ditanyakan saat onboarding. |
| D7 | Jika belum ada jadwal tersimpan dan offline, jadwal dihitung offline (paket `adhan`, parameter Kemenag) dan diberi label "perkiraan". |
| D8 | 1 Hari 1 Ayat memakai daftar kurasi dari pemilik proyek. 1 Hari 1 Hadis dipilih otomatis dengan filter panjang. |
| D9 | Widget Android native (Kotlin) lewat `home_widget`. Konten 7 hari ke depan disimpan saat aplikasi dibuka. |
| D10 | Nama paket Dart `nura`, Application ID `com.technowstack.nura`. |
| D11 | GetX untuk state, DI, dan routing. |

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
  CHECKSUMS.sha256               mencakup semua file di atas
  README.md

tool/
  build_content_db.dart
  verify_content_db.dart
  lib/                           kode bersama: parser JSON, normalisasi pencarian

assets/db/content.db
```

File `meta/` ditambahkan bertahap. Sumber dan lisensi setiap file dicatat di `data-source/README.md` sebelum di-commit.

### 3.2 Skema `content.db`

```sql
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- kunci: schema_version, data_version, built_at, source_checksums (JSON)

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
  arab_search         TEXT NOT NULL,         -- tanpa harakat dan tanda waqaf
  translation_search  TEXT NOT NULL,         -- huruf kecil, tanpa tanda baca
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
  arab_search         TEXT NOT NULL,
  translation_search  TEXT NOT NULL,
  translation_length  INTEGER NOT NULL,      -- jumlah karakter translation_id
  UNIQUE (book_slug, number)
);

CREATE VIRTUAL TABLE ayah_fts USING fts5(
  arab_search, translation_search,
  content='ayah', content_rowid='id', tokenize='unicode61'
);

CREATE VIRTUAL TABLE hadith_fts USING fts5(
  arab_search, translation_search,
  content='hadith', content_rowid='id', tokenize='unicode61'
);

CREATE TABLE daily_ayah (
  seq      INTEGER PRIMARY KEY,        -- 0..n-1, urutan sudah diacak saat build
  ayah_id  INTEGER NOT NULL REFERENCES ayah(id)
);

CREATE TABLE daily_hadith (
  seq        INTEGER PRIMARY KEY,
  hadith_id  INTEGER NOT NULL REFERENCES hadith(id)
);
```

Nama tampilan kitab hadis ditulis di skrip build sebagai konstanta, karena tidak ada di JSON.

### 3.3 Aturan konversi

- Kolom teks asli diisi dengan string hasil decode JSON tanpa trim, normalisasi Unicode, atau penggantian karakter.
- Field angka bertipe string di JSON Quran (`number`, `number_of_ayah`, kunci ayat) diubah ke `INTEGER`. Verifikasi membandingkan `toString()` hasilnya dengan string asli.
- `arab_search`: hapus harakat (U+064B–U+065F, U+0670), tanda waqaf dan tanda Al-Qur'an (U+06D6–U+06ED), dan tatweel (U+0640). Normalisasi alif (أ إ آ ٱ → ا), ى → ي, ة → ه.
- `translation_search`: huruf kecil, tanda baca diganti spasi, spasi beruntun dipadatkan.
- `daily_ayah`: dibaca dari `meta/daily_ayah.json` (daftar pasangan surah dan ayat), diacak dengan seed tetap `20261109`. Jika file belum ada, tabel kosong dan fitur disembunyikan di aplikasi.
- `daily_hadith`: semua hadis dengan `translation_length` ≤ 400 karakter, diurutkan berdasarkan `(sort_order kitab, number)`, lalu diacak dengan seed tetap yang sama. Batas 400 adalah konstanta di skrip dan bisa diubah.
- Build bersifat deterministik: input yang sama menghasilkan isi tabel yang sama.

### 3.4 Verifikasi (`verify_content_db.dart`)

Gagal (exit code bukan 0) jika salah satu syarat tidak terpenuhi:

1. Checksum setiap file di `data-source/` cocok dengan `CHECKSUMS.sha256`.
2. Jumlah baris: 114 surah, 6.236 ayat, 30 juz (jika `juz.json` ada), 9 kitab, 38.102 hadis, dan jumlah per kitab sama dengan panjang array JSON-nya.
3. Setiap ayat: `arab`, `translation_id`, dan `tafsir_kemenag` identik (perbandingan string penuh) dengan JSON sumber. Hal yang sama untuk setiap hadis.
4. `ayah_count` setiap surah sama dengan jumlah baris `ayah`-nya.
5. Isi FTS sinkron dengan tabelnya (`INSERT INTO ayah_fts(ayah_fts) VALUES('integrity-check')`).
6. `meta.source_checksums` sama dengan isi `CHECKSUMS.sha256`.

Test `test/tool/` menjalankan verifikasi pada subset data sebagai fixture, termasuk kasus yang harus gagal (satu karakter diubah).

### 3.5 Paket SQLite

Pakai `sqlite3` dan `sqlite3_flutter_libs`. Library SQLite dibundel bersama aplikasi, jadi FTS5 pasti tersedia di semua versi Android. SQLite bawaan Android tidak menjamin FTS5. Skrip di `tool/` juga memakai paket `sqlite3`, jadi pembuat dan pembaca database memakai mesin yang sama.

Paket `sqlite3` bersifat sinkron. Query yang berat (pencarian, daftar panjang) dijalankan di isolate terpisah.

## 4. Database Pengguna (`user.db`)

```sql
CREATE TABLE setting (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
-- theme_mode, online_enabled, prayer_sync_enabled, onboarding_done,
-- arabic_font_scale, translation_font_scale, qari_id,
-- notify_fajr … notify_isha, prayer_adjust_fajr … prayer_adjust_isha

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
  source    TEXT NOT NULL CHECK (source IN ('gps','city')),
  label     TEXT NOT NULL,
  lat       REAL NOT NULL,
  lng       REAL NOT NULL,
  city_key  TEXT NOT NULL          -- kunci kota di cities.json (kota terdekat jika GPS)
);

CREATE TABLE prayer_day (
  date      TEXT NOT NULL,          -- yyyy-MM-dd
  city_key  TEXT NOT NULL,
  imsak TEXT, subuh TEXT, terbit TEXT, dhuha TEXT,
  dzuhur TEXT, ashar TEXT, maghrib TEXT, isya TEXT,   -- HH:mm waktu lokal
  source    TEXT NOT NULL CHECK (source IN ('api','calc')),
  fetched_at INTEGER NOT NULL,
  PRIMARY KEY (date, city_key)
);

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

Migrasi memakai `PRAGMA user_version`, dengan satu fungsi migrasi per versi.

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
  main.dart                      inisialisasi: salin content.db, buka DB, register service, runApp
  app/
    core/
      theme/                     tema terang dan gelap, tipografi Arab
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
        audio_repository.dart         URL, unduhan, status
    services/
      online_service.dart        sakelar dan cek koneksi; gerbang semua request
      audio_player_service.dart  just_audio, antrian per ayat
      notification_service.dart  penjadwalan pengingat sholat
      location_service.dart      GPS sekali ambil, cari kota terdekat
      home_widget_service.dart   menulis konten 7 hari ke widget
    modules/
      onboarding/  home/  quran_list/  quran_detail/  juz/
      hadith_books/  hadith_list/  hadith_detail/
      search/  bookmarks/  prayer/  settings/  about/
    routes/
      app_routes.dart, app_pages.dart
android/app/src/main/kotlin/com/technowstack/nura/
  DailyAyahWidgetProvider.kt
  DailyHadithWidgetProvider.kt
```

### 5.3 Navigasi

- Bottom navigation dengan 4 tab: **Beranda**, **Al-Qur'an**, **Hadis**, **Sholat**.
- **Beranda**: kartu waktu sholat berikutnya beserta hitung mundur, kartu Ayat Hari Ini, kartu Hadis Hari Ini, kartu Last Read, dan ikon ke Pencarian, Bookmark, dan Pengaturan.
- **Al-Qur'an**: tab Surah dan Juz, lalu Detail Surah.
- **Hadis**: daftar kitab, lalu daftar hadis (paging 30 per halaman), lalu Detail Hadis.
- **Sholat**: jadwal hari ini, pilihan lokasi, pengaturan notifikasi, label "perkiraan" jika sumbernya `calc`.
- **Pengaturan**: tema, ukuran font, Fitur Online, qari, kelola unduhan audio, sinkron jadwal, Sumber & Atribusi.
- Route awal: Onboarding jika `onboarding_done` belum `true`, selain itu Beranda.

### 5.4 Inisialisasi aplikasi

1. Salin `assets/db/content.db` ke folder data aplikasi jika belum ada, atau jika `meta.data_version` di assets berbeda dengan salinan.
2. Buka `content.db` dengan mode read-only dan `user.db` dengan mode read-write (jalankan migrasi).
3. Daftarkan source, repository, dan service sebagai singleton GetX.
4. Tulis konten widget untuk 7 hari ke depan dan jadwalkan ulang notifikasi (tanpa menahan tampilan pertama).

## 6. Fitur Online

### 6.1 `OnlineService`

- `bool get audioEnabled` dari setting `online_enabled` (default `false`).
- `bool get prayerSyncEnabled` dari setting `prayer_sync_enabled` (ditanyakan saat onboarding).
- `Future<bool> canReach()` mengecek koneksi lewat `connectivity_plus`. Hasil ini hanya petunjuk awal. Kegagalan request tetap ditangani.
- Klien HTTP hanya bisa dipanggil lewat repository yang terlebih dulu bertanya ke `OnlineService`.

### 6.2 Audio

- Penyedia: satu API (kandidat equran.id, menunggu Q3). URL per ayat dibentuk di `audio_api_client.dart`.
- Putar ayat: kalau file lokal ada, putar file lokal. Kalau tidak ada dan `audioEnabled` serta ada koneksi, streaming. Kalau tidak keduanya, tombol play tidak aktif dengan keterangan "Butuh internet".
- Putar surah: antrian berurutan dari ayat yang dipilih sampai akhir surah. Ayat yang sedang diputar di-highlight dan daftar menggulir mengikutinya.
- Unduh surah: unduh semua ayat secara berurutan ke `audio/<qari_id>/<surah>/<ayah>.mp3`, perbarui `audio_download` setelah setiap file, dan bisa dilanjutkan jika terputus. Unduhan hanya berjalan saat aplikasi terbuka (tanpa background download di v1).
- Hapus unduhan: per surah atau semua, dari Pengaturan.

## 7. Jadwal Sholat

### 7.1 Sumber

- **API** (kandidat myquran.com, memakai data Kemenag, menunggu Q3): ambil satu bulan berjalan dan bulan berikutnya per kota. Simpan ke `prayer_day` dengan `source = 'api'`.
- **Perhitungan offline** (`adhan`): Subuh 20°, Isya 18°, Asar mazhab Syafi'i, plus penyesuaian dari setting. Simpan dengan `source = 'calc'`.

### 7.2 Alur

1. Saat jadwal dibutuhkan untuk tanggal D di kota K: cek `prayer_day(D, K)`.
2. Jika ada dan `source = 'api'`, pakai.
3. Jika tidak ada atau `source = 'calc'`, dan `prayerSyncEnabled` serta ada koneksi: ambil dari API untuk bulan D, simpan, lalu pakai.
4. Jika API gagal atau tidak diizinkan: hitung offline, simpan sebagai `calc`, dan tampilkan label "perkiraan".
5. Sinkron ulang otomatis saat aplikasi dibuka jika sisa jadwal `api` kurang dari 7 hari.

### 7.3 Lokasi

- Pilihan kota: daftar dari `meta/cities.json`, dengan pencarian nama.
- GPS: ambil posisi sekali, lalu cari kota terdekat di `cities.json` (jarak haversine). Kota itu dipakai untuk API, sedangkan koordinat GPS dipakai untuk perhitungan offline.

### 7.4 Notifikasi

- `flutter_local_notifications`, dijadwalkan untuk 7 hari ke depan dari `prayer_day`.
- Penjadwalan ulang terjadi saat aplikasi dibuka, setelah HP restart (receiver `BOOT_COMPLETED`), dan saat lokasi atau setting notifikasi berubah.
- Setiap waktu sholat punya sakelar sendiri. Suara pakai bunyi notifikasi bawaan.
- Android 12 ke atas: minta izin alarm tepat waktu dengan penjelasan. Jika ditolak, pakai alarm tidak tepat waktu dan tampilkan keterangan di layar Sholat.
- Android 13 ke atas: minta izin notifikasi saat pengguna pertama kali menyalakan pengingat.

## 8. 1 Hari 1 Ayat/Hadis dan Widget

### 8.1 Pemilihan

- `dayIndex = jumlah hari sejak 2026-01-01 (tanggal lokal)`.
- Ayat hari ini: `daily_ayah` dengan `seq = dayIndex mod count`. Jika tabel kosong, kartu dan widget ayat disembunyikan atau menampilkan keterangan.
- Hadis hari ini: `daily_hadith` dengan `seq = dayIndex mod count`.
- Hasilnya sama untuk semua pengguna di tanggal yang sama, selama `data_version` sama.

### 8.2 Widget Android

- Dua provider: `DailyAyahWidgetProvider` dan `DailyHadithWidgetProvider`, ukuran default 4×2, bisa diubah ukurannya.
- Saat aplikasi dibuka, `HomeWidgetService` menulis konten untuk 7 tanggal ke depan ke penyimpanan `home_widget`. Setiap entri berisi tanggal, teks Arab (dipotong), terjemahan (dipotong), label referensi, dan deep link.
- Provider native memilih entri sesuai tanggal hari ini setiap kali di-update (`updatePeriodMillis` sekitar 3 jam, dan saat tanggal berganti lewat `ACTION_DATE_CHANGED`).
- Jika entri untuk hari ini tidak ada (aplikasi tidak dibuka lebih dari 7 hari), widget menampilkan "Buka Nura untuk memperbarui".
- Ketuk widget membuka aplikasi di Detail Surah atau Detail Hadis lewat deep link `nura://ayah/<surah>/<ayat>` atau `nura://hadith/<slug>/<nomor>`.

## 9. Penanganan Error

| Kondisi | Perilaku |
|---|---|
| Gagal menyalin atau membuka `content.db` | Layar error penuh dengan tombol "Coba lagi". Penyebab dicatat di log. |
| Query konten gagal | `UiState.error` dengan pesan singkat dan tombol coba lagi. Tidak crash. |
| Hasil kosong (pencarian, bookmark) | `UiState.empty` dengan teks penjelas. |
| Tidak ada koneksi atau sakelar mati | Kontrol online dinonaktifkan dengan keterangan. Tidak ada dialog error. |
| Request API gagal | Audio: berhenti dan tampilkan snackbar. Jadwal: pakai fallback perhitungan. |
| Izin lokasi ditolak | Arahkan ke pilihan kota manual. |
| Izin notifikasi atau alarm tepat ditolak | Tampilkan keterangan dan tautan ke pengaturan sistem. |
| `user.db` gagal migrasi | Cadangkan file lama, buat baru, dan beri tahu pengguna bahwa bookmark mungkin hilang. |

## 10. Pengujian

- **Tool**: test build dan verifikasi pada fixture kecil, termasuk kasus gagal.
- **Repository**: test dengan database in-memory dari fixture. Contohnya daftar surah, ayat per surah, paging hadis, pencarian, bookmark, dan last read.
- **Normalisasi pencarian**: test unit untuk contoh teks Arab dan Indonesia.
- **Jadwal sholat**: test perhitungan offline terhadap jadwal resmi Kemenag untuk Bontang dan Jakarta pada beberapa tanggal, toleransi ±2 menit. Test alur cache, API, dan fallback dengan klien API tiruan.
- **Konten harian**: test bahwa `dayIndex` yang sama selalu menghasilkan konten yang sama, dan berganti antar hari.
- **Controller**: test transisi `UiState` dengan repository tiruan.
- **Manual di perangkat**: widget, notifikasi, audio, alur offline (mode pesawat), dan instalasi bersih.
- `flutter analyze` bersih dan `flutter test` lulus sebelum setiap commit.

## 11. Fase Implementasi

| Fase | Isi | Selesai jika |
|---|---|---|
| 1. Fondasi | Hapus kode lama di `lib/`, ganti nama paket dan Application ID, struktur folder, `sqlite3`, skrip build dan verifikasi, `content.db` dari data Quran dan hadis, `user.db`, inisialisasi, tema | `verify_content_db` lulus. Aplikasi terbuka ke Beranda kosong. Test lulus. |
| 2. Al-Qur'an | Daftar surah, detail, tafsir, juz (setelah `juz.json`), bookmark, last read, ukuran font | Bisa dibaca penuh secara offline |
| 3. Hadis | Daftar kitab, daftar dengan paging, detail, bookmark | Semua 9 kitab bisa dibaca offline |
| 4. Pencarian | FTS ayat dan hadis, layar pencarian | Pencarian di semua hadis di bawah 1 detik di perangkat uji |
| 5. Jadwal sholat | Lokasi, API dan cache, fallback, layar Sholat, notifikasi | Jadwal tampil offline dan online, notifikasi berbunyi |
| 6. Konten harian | Kartu di Beranda, widget Android | Widget berganti setiap hari tanpa membuka aplikasi |
| 7. Fitur online | Sakelar, audio streaming, unduhan | Audio jalan online dan dari unduhan saat offline |
| 8. Polish | Onboarding, Sumber & Atribusi, ikon, uji perangkat, persiapan Play Store | Siap rilis, terblokir oleh Q6 dan Q7 |

Fase 2 dan seterusnya membutuhkan Fase 1. Fase 5 membutuhkan `cities.json`. Fase 6 untuk ayat membutuhkan `daily_ayah.json`.

## 12. Pertanyaan Terbuka yang Memengaruhi Spec

| ID | Pertanyaan | Memengaruhi |
|---|---|---|
| Q2 | Nama aplikasi Nura (Play Store, DJKI) | Fase 8 |
| Q3 | Penyedia API audio dan jadwal, beserta syarat penggunaannya | Fase 5, 7 |
| Q4 | Sumber `surah_info.json`, `juz.json`, dan `cities.json` | Fase 1 (revelation), 2 (juz), 5 |
| Q5 | Nilai ihtiyat dan parameter perhitungan offline | Fase 5 |
| Q6 | Ketentuan tashih LPMQ | Rilis |
| Q7 | Lisensi teks terjemahan hadis | Rilis |
| Q8 | Verifikasi data ke sumber asli | Sebelum rilis |
| Q9 | Daftar kurasi `daily_ayah.json` (disusun pemilik proyek) | Fase 6 |

Jika `surah_info.json` belum tersedia di Fase 1, kolom `revelation` diizinkan sementara bernilai `''` dan UI tidak menampilkannya. Verifikasi menandainya sebagai peringatan, bukan kegagalan, sampai file tersedia.
