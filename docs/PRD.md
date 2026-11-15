# PRD: Nura (Aplikasi Islami Offline-First)

Status dokumen: Draft v0.4 (selaras dengan `docs/specs/2026-11-09-nura-v1-design.md` dan putaran desain 1 di `docs/design/`)
Terakhir diperbarui: 2026-11-11

## 1. Ringkasan

Nura adalah aplikasi Flutter untuk membaca Al-Qur'an dan hadis, melihat jadwal sholat, serta mendapatkan "1 Hari 1 Ayat" dan "1 Hari 1 Hadis". Semua konten inti dibundel di dalam aplikasi sebagai database SQLite read-only, jadi aplikasi berfungsi penuh tanpa internet. Fitur yang butuh internet, seperti audio murottal, bersifat opsional dan mati secara default. Doa dan konten islami lain direncanakan untuk rilis berikutnya.

Aplikasi dibangun ulang dari awal (rebuild bersih) di branch baru. Kode lama tidak ditambal.

## 2. Tujuan

- Aplikasi Islami satu pintu untuk Al-Qur'an, hadis, dan jadwal sholat.
- Offline-first: semua fitur inti berjalan tanpa internet sejak instalasi.
- Fitur online opsional yang bisa dinyalakan atau dimatikan pengguna.
- Teks Al-Qur'an dan hadis identik dengan sumbernya, dibuktikan dengan verifikasi otomatis.
- Rilis publik di Google Play Store (Android) pada rilis pertama.
- Kebiasaan harian lewat "1 Hari 1 Ayat/Hadis", termasuk widget layar depan Android.

## 3. Pengguna

- Muslim Indonesia yang ingin membaca Al-Qur'an dan hadis dengan terjemahan Indonesia.
- Pengguna dengan koneksi tidak stabil, misalnya saat bepergian atau di daerah sinyal lemah.
- Pengguna yang ingin pengingat sholat dan bacaan harian tanpa iklan yang mengganggu.

## 4. Identitas Aplikasi

| Item | Nilai | Status |
|---|---|---|
| Nama aplikasi | Nura | Kandidat. Perlu cek Play Store dan DJKI |
| Nama paket Dart (`pubspec.yaml`) | `nura` | Disepakati |
| Application ID Android | `com.technowstack.nura` | Disepakati (2026-11-09). Tidak bisa diubah setelah rilis. Diterapkan di kode pada fase Fondasi |

## 5. Cakupan Rilis Pertama (v1)

### 5.1 Al-Qur'an (offline)
- Daftar 114 surah: nomor, nama Latin, nama Arab, arti, jumlah ayat, tempat turun.
- Detail surah: teks Arab dan terjemahan Indonesia per ayat. Tafsir Kemenag bisa dibuka atau ditutup per ayat.
- Tab Juz: 30 juz dengan awal dan akhir masing-masing.
- Bookmark ayat dan Last Read.
- Pencarian di terjemahan dan teks Arab. Hasil dikelompokkan per surah. Terjemahan tampil sebagai cuplikan (maksimal 3 baris) yang berpusat pada kata cocok, dan semua kata cocok disorot (aturan lengkap di spec bagian 5.5).
- Pengaturan baca: ukuran font Arab (20–40, default 28), sakelar tampil/sembunyi terjemahan, dan pilihan tema. Ukuran font terjemahan tetap, tidak diatur pengguna.

### 5.2 Al-Qur'an (online, opsional)
- Sakelar "Fitur Online" di Pengaturan, **mati secara default**.
- Saat menyala: audio murottal per ayat dan per surah bisa diputar streaming atau diunduh per surah.
- Audio yang sudah diunduh bisa diputar tanpa internet.
- Saat sakelar mati atau tidak ada koneksi, kontrol audio disembunyikan atau diberi keterangan. Aplikasi tidak boleh error.
- Hanya satu penyedia API audio yang dipakai.

### 5.3 Hadis (offline)
- Daftar 9 kitab: Bukhari, Muslim, Abu Daud, Tirmidzi, Nasai, Ibnu Majah, Ahmad, Malik, Darimi.
- Daftar hadis per kitab dengan nomor dan pratinjau, dimuat bertahap (paging).
- Detail hadis: teks Arab dan terjemahan Indonesia.
- Bookmark hadis.
- Pencarian dalam satu kitab atau di semua kitab.

### 5.4 Jadwal Sholat
- Jadwal lima waktu, plus imsak, terbit, dan dhuha, berdasarkan lokasi GPS atau kota yang dipilih.
- Jadwal diambil dari API per bulan (bulan berjalan dan berikutnya) lalu disimpan di perangkat, sehingga bisa dibuka offline setelah sinkron.
- Izin sinkron jadwal **terpisah** dari sakelar audio dan ditanyakan saat onboarding.
- Jika belum ada jadwal tersimpan dan perangkat offline, jadwal dihitung offline dari koordinat (paket `adhan`, parameter Kemenag) dan diberi label **"perkiraan"**.
- Notifikasi pengingat per waktu sholat, bisa diatur masing-masing. Dijadwalkan dalam zona waktu wilayah terpilih (WIB/WITA/WIT), bukan zona waktu perangkat.
- Keputusan (belum dikerjakan, Fase 5): sumber jadwal = API equran.id v2. Lokasi dipilih sebagai provinsi + kabupaten/kota (nama persis seperti di API), bukan koordinat. Jadwal diambil sekali per bulan per wilayah lalu disimpan.
- Penanda waktu sholat berikutnya dan hitung mundur.

### 5.5 1 Hari 1 Ayat dan 1 Hari 1 Hadis
- Pilihan ditentukan dari tanggal secara deterministik, jadi pengguna dengan setelan yang sama melihat konten yang sama di hari yang sama.
- 1 Hari 1 Ayat memakai **daftar kurasi** dari pemilik proyek (`data-source/meta/daily_ayah.json`). Jika file belum ada, fitur ayat harian disembunyikan.
- 1 Hari 1 Hadis dipilih **otomatis**. Yang ditampilkan adalah **matan** hadis, bukan hadis lengkap dengan sanad. Matan Arab dan matan terjemahan diekstrak dari teks sumber sebagai substring persis (data tidak punya field matan terpisah). Sebuah hadis hanya lolos seleksi jika matan Arab **dan** terjemahannya bisa diekstrak bersih.
- Secara default hadis harian hanya diambil dari Shahih Bukhari dan Shahih Muslim. Pengguna bisa memperluasnya ke 9 kitab di Pengaturan.
- Aturan seleksi hadis harian ditetapkan di Fase 6: ekstraksi bersih dan batas panjang matan (N). Penerapannya mengubah `daily_hadith` dan butuh persetujuan pemilik proyek. Sampai Fase 6, `content.db` memakai filter sementara: terjemahan tidak lebih dari 400 UTF-16 code unit (`String.length` Dart).
- Rujukan ditampilkan sebagai `QS. <Nama Latin>: <ayat>` untuk ayat dan `HR. <Kitab> No. <nomor>` untuk hadis. Kartu hadis punya tautan "Baca selengkapnya" ke hadis lengkap dengan sanad.
- Tampil di **tiga tempat**: kartu di layar depan aplikasi, widget layar depan Android, dan notifikasi harian.
- **Widget** ("Ayat hari ini" dan "Hadis hari ini", ukuran 4×2 dan 4×3, terang dan gelap) dirender sebagai **gambar** dari Flutter, karena font Arab LPMQ tidak bisa dipakai di RemoteViews. Widget bersifat statis: tanpa tombol, seluruh widget satu area ketuk. Isinya label, matan Arab, terjemahan, dan rujukan. Teks yang melebihi ruang dipotong dengan elipsis.
- **Notifikasi harian**: satu per hari, jamnya bisa diatur atau dimatikan, default 06.00 dan bisa diubah pengguna. Isinya terjemahan dan rujukan saja, **tanpa teks Arab**, karena notifikasi tidak bisa memakai font khusus. Ketuk notifikasi membuka Beranda.

### 5.6 Umum
- Tema terang, gelap, dan ikut sistem. Pilihan tersimpan.
- Onboarding tampil sekali pada peluncuran pertama, tiga langkah: (a) sambutan, (b) jadwal sholat: pilih kota dan beri izin sinkron online yang terpisah, (c) izin notifikasi dengan dua sakelar "Pengingat adzan" dan "Ayat & hadis harian" (langkah ini bisa dilewati). Audio murottal tidak ditanyakan di onboarding karena mati secara default; cukup disebut bahwa audio bisa diaktifkan di Pengaturan.
- Tampilan mengikuti desain putaran 1 (`docs/design/`): Material 3, tema terang dan gelap, font Latin Plus Jakarta Sans dan font Arab LPMQ Isep Misbah.
- Halaman "Sumber & Atribusi" yang mencantumkan semua sumber data.

## 6. Di Luar Cakupan v1

- Transliterasi Latin per ayat (bisa masuk v1 jika data offline dengan lisensi jelas ditemukan).
- Doa-doa dan konten islami lain.
- Widget iOS dan rilis iOS.
- Akun pengguna, sinkronisasi cloud, dan iklan.
- Platform web, Windows, Linux, dan macOS.

## 7. Arsitektur Data

### 7.1 Alur data

```
data-source/                 JSON asli (sumber kebenaran), disimpan di repo, TIDAK dibundel ke app
  quran/1.json … 114.json
  hadith/*.json
  meta/                      data statis tambahan: info surah, pemetaan juz, kota, daftar kurasi ayat harian (daily_ayah.json)
  CHECKSUMS.sha256

tool/build_content_db.dart   skrip konversi JSON → SQLite (dijalankan developer)
tool/verify_content_db.dart  verifikasi baris demi baris terhadap JSON

assets/db/content.db         hasil konversi, dibundel ke app, dibuka READ-ONLY

(di perangkat) user.db       bookmark, last read, pengaturan, status unduhan audio
```

### 7.2 Integritas data

1. JSON di `data-source/` adalah sumber kebenaran dan tidak boleh diedit. Setiap file punya checksum SHA-256 di `CHECKSUMS.sha256`.
2. Kolom teks asli (`arab`, `translation`, `tafsir`) disalin byte demi byte tanpa normalisasi, trim, atau perubahan encoding.
3. Kebutuhan pencarian dilayani indeks FTS5 contentless yang berisi teks hasil normalisasi (Arab tanpa harakat, teks huruf kecil tanpa tanda baca). Kolom asli tidak pernah diubah.
4. Verifikasi otomatis wajib lulus setiap kali `content.db` dibuat (`tool/prepare_content.sh`; file ini tidak di-commit):
   - Jumlah: 114 surah, 6.236 ayat, 9 kitab, 38.102 hadis, dan jumlah per kitab sesuai.
   - Setiap baris dibandingkan dengan JSON sumber. Satu karakter beda berarti gagal.
   - Checksum JSON sumber cocok dengan `CHECKSUMS.sha256`.
5. Tabel `meta` di `content.db` menyimpan versi data, tanggal build, dan checksum sumber.
6. Aplikasi membuka `content.db` dalam mode read-only. Data pengguna hanya ditulis ke `user.db`.

### 7.3 Skema `content.db` (garis besar)

- `surah` (number, name_arab, name_latin, name_id, ayah_count, revelation)
- `ayah` (surah_number, ayah_number, arab, translation_id, tafsir_kemenag)
- `juz` (number, start_surah, start_ayah, end_surah, end_ayah)
- `hadith_book` (slug, name, hadith_count)
- `hadith` (book_slug, number, arab, translation_id, translation_length)
- Tabel FTS5 contentless (`ayah_fts`, `hadith_fts`, rowid = id tabel utama) untuk ayat dan hadis.
- `daily_ayah` dan `daily_hadith` (urutan konten harian, diacak dengan seed tetap saat build).
- `meta` (key, value)

Skema lengkap ada di spec desain (bagian 3.2).

### 7.4 Paket SQLite

Pakai `sqlite3` dan `sqlite3_flutter_libs` (bukan `sqflite`). Library SQLite dibundel bersama aplikasi sehingga FTS5 pasti tersedia di semua versi Android, dan skrip di `tool/` memakai mesin yang sama dengan aplikasi.

## 8. Arsitektur Aplikasi (ringkas)

- Flutter, GetX untuk state, dependency injection, dan routing.
- Lapisan: `data` (sumber SQLite, API audio, dan API jadwal sholat) → `repository` (antarmuka per domain) → `modules` (binding, controller, view per fitur).
- Tidak ada akses database atau jaringan langsung dari view atau controller. Semuanya lewat repository.
- Fitur online dibungkus layanan tersendiri (`OnlineService`) yang memeriksa sakelar dan koneksi sebelum dipakai. Audio dikendalikan sakelar "Fitur Online"; sinkron jadwal sholat dikendalikan izin tersendiri.
- Widget Android memakai AppWidgetProvider native yang menampilkan gambar. Gambar widget dirender oleh Flutter (font Arab LPMQ tidak bisa dipakai di RemoteViews), misalnya lewat paket `home_widget`. Aplikasi menulis gambar harian, lalu widget membacanya. Notifikasi harian memakai `flutter_local_notifications`, sama dengan pengingat sholat.

## 9. Kebutuhan Non-Fungsional

- **Offline:** semua fitur di 5.1, 5.3, 5.4, 5.5, dan 5.6 berjalan tanpa internet.
- **Integritas:** verifikasi data (7.2) lulus di setiap build.
- **Performa:** daftar surah dan hadis terbuka tanpa jank yang terlihat. Pencarian di semua hadis selesai di bawah 1 detik pada perangkat kelas menengah.
- **Ukuran:** ukuran AAB dicatat di STATUS.md setiap rilis.
- **Atribusi:** semua sumber data tercantum di halaman "Sumber & Atribusi".
- **Aksesibilitas dasar:** ukuran font bisa diatur, kontras tema memadai.

## 10. Sumber Data dan Lisensi

| Data | Sumber | Status lisensi |
|---|---|---|
| Teks Arab, terjemahan, dan tafsir Al-Qur'an | Kementerian Agama RI | Perlu cek ketentuan tashih LPMQ untuk mushaf digital |
| Hadis 9 kitab | github.com/gadingnst/hadith-api (MIT), data asal tafsirq.com | Lisensi MIT mencakup repo. Status lisensi teks terjemahan dari sumber asal perlu dikonfirmasi |
| Audio murottal | API pihak ketiga (belum dipilih) | Perlu cek syarat penggunaan |
| Jadwal sholat (API) | equran.id v2 (`https://equran.id/api/v2/shalat`, dokumentasi `https://equran.id/apidev/shalat`); diputuskan | Syarat layanan belum dibaca: wajib dibaca sebelum rilis |
| Info surah, juz, kota | Belum dipilih | Perlu sumber dengan lisensi jelas |
| Daftar kurasi ayat harian | Disusun pemilik proyek | Menunggu daftar (Q9) |
| Font Arab LPMQ Isep Misbah (cadangan KFGQPC Uthmanic Script Hafs) | LPMQ Kemenag (lajnah.kemenag.go.id/unduhan) | Lisensi kedua font wajib dicek sebelum rilis (Q6). Catat tanggal unduh di catatan rilis |
| Font Latin Plus Jakarta Sans | Plus Jakarta Sans | OFL |

Rilis publik terblokir sampai status lisensi Al-Qur'an dan hadis jelas.

## 11. Rencana Rilis

Urutan fase mengikuti spec desain bagian 11.

1. **Fondasi:** hapus kode lama, paket dan Application ID, struktur proyek, `sqlite3`, skrip build dan verifikasi, `content.db`, `user.db`, tema.
2. **Al-Qur'an offline:** daftar surah, detail, tafsir, juz, bookmark, last read, ukuran font.
3. **Hadis:** daftar kitab, daftar dengan paging, detail, bookmark.
4. **Pencarian:** FTS ayat dan hadis, cuplikan hasil dan sorotan kata cocok.
5. **Jadwal sholat:** lokasi, API dan cache, fallback perhitungan, notifikasi.
6. **1 Hari 1 Ayat/Hadis:** kartu di aplikasi, aturan seleksi hadis (matan), widget Android (gambar dari Flutter), dan notifikasi harian.
7. **Fitur online:** sakelar, audio streaming dan unduhan.
8. **Polish dan rilis:** onboarding, atribusi, ikon, uji di perangkat, Play Store.

Tanggal target belum ditetapkan.

## 12. Pertanyaan Terbuka

1. ~~**Application ID Android.**~~ Diputuskan: `com.technowstack.nura` (lihat bagian 4).
2. **Nama aplikasi.** Nura masih perlu dicek di Play Store dan DJKI.
3. **Penyedia API audio dan jadwal sholat.** Jadwal sholat: diputuskan equran.id v2 (syarat layanan belum dibaca; wajib sebelum rilis). Audio: kandidat equran.id, belum diputuskan.
4. **Sumber data meta** (info surah, juz, kota) dan transliterasi.
5. **Parameter perhitungan offline** (cadangan jadwal sholat, termasuk ihtiyat). Perlu diverifikasi dengan jadwal Kemenag.
6. **Ketentuan tashih LPMQ** untuk Al-Qur'an digital, dan **lisensi font Arab**: LPMQ Isep Misbah (cadangan KFGQPC Uthmanic Script Hafs). Lisensi kedua font wajib dicek sebelum rilis. LPMQ diambil dari sumber resmi (lajnah.kemenag.go.id/unduhan) dan tanggal unduh dicatat di catatan rilis.
7. **Konfirmasi lisensi teks hadis** ke pemilik repo atau sumber asal.
8. **Verifikasi isi `data-source/` ke sumber asli** (hadis: gadingnst/hadith-api). Lihat STATUS.md Q8.
9. **Daftar kurasi `data-source/meta/daily_ayah.json`.** Disusun pemilik proyek. Dibutuhkan untuk 1 Hari 1 Ayat (Fase 6).
10. ~~**Jam default notifikasi harian.**~~ Diputuskan (2026-11-11): 06.00, bisa diubah pengguna (lihat 5.5).
11. ~~**Sumber hadis harian.**~~ Diputuskan (2026-11-11): default hanya Shahih Bukhari dan Shahih Muslim, bisa diperluas ke 9 kitab di Pengaturan (lihat 5.5). Batas panjang matan (N) dan ekstraksi ditetapkan di Fase 6.
