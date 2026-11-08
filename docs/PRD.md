# PRD: Nura (Aplikasi Islami Offline-First)

Status dokumen: Draft v0.2
Terakhir diperbarui: 2026-11-09

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
| Application ID Android | `com.technowstack.nura` | Usulan, perlu konfirmasi. Tidak bisa diubah setelah rilis |

## 5. Cakupan Rilis Pertama (v1)

### 5.1 Al-Qur'an (offline)
- Daftar 114 surah: nomor, nama Latin, nama Arab, arti, jumlah ayat, tempat turun.
- Detail surah: teks Arab dan terjemahan Indonesia per ayat. Tafsir Kemenag bisa dibuka atau ditutup per ayat.
- Tab Juz: 30 juz dengan awal dan akhir masing-masing.
- Bookmark ayat dan Last Read.
- Pencarian di terjemahan dan teks Arab.
- Pengaturan ukuran font Arab dan terjemahan.

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
- Jadwal lima waktu, plus imsak dan terbit, berdasarkan lokasi GPS atau kota yang dipilih.
- Perhitungan dilakukan offline dari koordinat.
- Notifikasi pengingat per waktu sholat, bisa diatur masing-masing.
- Penanda waktu sholat berikutnya dan hitung mundur.

### 5.5 1 Hari 1 Ayat dan 1 Hari 1 Hadis
- Pilihan ditentukan dari tanggal secara deterministik, jadi semua pengguna melihat konten yang sama di hari yang sama.
- Tampil sebagai kartu di layar depan aplikasi.
- Widget layar depan Android menampilkan konten yang sama tanpa membuka aplikasi.

### 5.6 Umum
- Tema terang, gelap, dan ikut sistem. Pilihan tersimpan.
- Halaman pengenalan (onboarding) tampil sekali pada peluncuran pertama.
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
  meta/                      data statis tambahan: info surah, pemetaan juz, kota
  CHECKSUMS.sha256

tool/build_content_db.dart   skrip konversi JSON → SQLite (dijalankan developer)
tool/verify_content_db.dart  verifikasi baris demi baris terhadap JSON

assets/db/content.db         hasil konversi, dibundel ke app, dibuka READ-ONLY

(di perangkat) user.db       bookmark, last read, pengaturan, status unduhan audio
```

### 7.2 Integritas data

1. JSON di `data-source/` adalah sumber kebenaran dan tidak boleh diedit. Setiap file punya checksum SHA-256 di `CHECKSUMS.sha256`.
2. Kolom teks asli (`arab`, `translation`, `tafsir`) disalin byte demi byte tanpa normalisasi, trim, atau perubahan encoding.
3. Kebutuhan pencarian dilayani kolom terpisah (`*_search`, misalnya Arab tanpa harakat dan teks huruf kecil) dan indeks FTS5. Kolom asli tidak pernah diubah.
4. Verifikasi otomatis wajib lulus sebelum `content.db` di-commit:
   - Jumlah: 114 surah, 6.236 ayat, 9 kitab, 38.102 hadis, dan jumlah per kitab sesuai.
   - Setiap baris dibandingkan dengan JSON sumber. Satu karakter beda berarti gagal.
   - Checksum JSON sumber cocok dengan `CHECKSUMS.sha256`.
5. Tabel `meta` di `content.db` menyimpan versi data, tanggal build, dan checksum sumber.
6. Aplikasi membuka `content.db` dalam mode read-only. Data pengguna hanya ditulis ke `user.db`.

### 7.3 Skema `content.db` (garis besar)

- `surah` (number, name_arab, name_latin, meaning, ayah_count, revelation)
- `ayah` (surah_number, ayah_number, arab, translation_id, tafsir_kemenag, arab_search, translation_search)
- `juz` (number, start_surah, start_ayah, end_surah, end_ayah)
- `hadith_book` (slug, name, hadith_count)
- `hadith` (book_slug, number, arab, translation_id, arab_search, translation_search)
- Tabel FTS5 untuk ayat dan hadis.
- `meta` (key, value)

Skema final ditetapkan di spec desain.

## 8. Arsitektur Aplikasi (ringkas)

- Flutter, GetX untuk state, dependency injection, dan routing.
- Lapisan: `data` (sumber SQLite dan API audio) → `repository` (antarmuka per domain) → `modules` (binding, controller, view per fitur).
- Tidak ada akses database atau jaringan langsung dari view atau controller. Semuanya lewat repository.
- Fitur online dibungkus layanan tersendiri yang memeriksa sakelar dan koneksi sebelum dipakai.
- Widget Android memakai paket `home_widget` dan AppWidgetProvider native. Aplikasi menulis konten harian, lalu widget membacanya.

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
| Info surah, juz, kota | Belum dipilih | Perlu sumber dengan lisensi jelas |

Rilis publik terblokir sampai status lisensi Al-Qur'an dan hadis jelas.

## 11. Rencana Rilis

1. **Fondasi:** branch baru, struktur proyek bersih, nama paket, pipeline data (`data-source/`, skrip build dan verifikasi, `content.db`), `user.db`.
2. **Al-Qur'an offline:** daftar surah, detail, tafsir, juz, bookmark, last read, pencarian.
3. **Hadis:** daftar kitab, daftar dan detail hadis, pencarian, bookmark.
4. **Jadwal sholat dan notifikasi.**
5. **1 Hari 1 Ayat/Hadis:** kartu di aplikasi, lalu widget Android.
6. **Fitur online:** sakelar, audio streaming dan unduhan.
7. **Polish dan rilis:** onboarding, atribusi, ikon, uji di perangkat, Play Store.

Tanggal target belum ditetapkan.

## 12. Pertanyaan Terbuka

1. **Application ID Android.** Usulan `com.technowstack.nura`.
2. **Nama aplikasi.** Nura masih perlu dicek di Play Store dan DJKI.
3. **Penyedia API audio.** Kandidat: equran.id. Perlu cek syarat penggunaan.
4. **Sumber data meta** (info surah, juz, kota) dan transliterasi.
5. **Metode perhitungan jadwal sholat.** Perlu disesuaikan dan diverifikasi dengan jadwal Kemenag.
6. **Ketentuan tashih LPMQ** untuk Al-Qur'an digital.
7. **Konfirmasi lisensi teks hadis** ke pemilik repo atau sumber asal.
