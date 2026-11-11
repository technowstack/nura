# STATUS: Proyek Nura

Terakhir diperbarui: 2026-11-11

Cabang utama: `main`. Setiap fase dikerjakan di branch sendiri (`feat/phase-N-<nama>`), lalu `merge --no-ff` ke `main` setelah review akhir. Fase 1 dikerjakan di `rebuild/nura` dan sudah di-merge lokal ke `main` (merge commit `7b0340c`). Belum di-push.

## Ringkasan Kondisi

- Arah proyek: rebuild bersih menjadi aplikasi Islami offline-first. Kode lama tidak ditambal.
- Repo lama (`main`, sebelum rebuild, HEAD `933deb5`): aplikasi Quran berbasis API, sekitar 25–30% jadi. Dijadikan referensi tampilan saja.
- Data JSON Quran dan hadis sudah dipindah ke `data-source/` dan di-track git. `CHECKSUMS.sha256` dan `README.md` sudah dibuat.
- Working tree lama yang kotor sudah dirapikan menjadi commit terpisah di `main` (platform, kode UI lama, docs, data).
- Tahap saat ini: Fase 1 (Fondasi) selesai. PRD v0.4, spec desain v1 (`docs/specs/2026-11-09-nura-v1-design.md`, disetujui), dan desain UI putaran 1 (`docs/design/`) sudah ada. Berikutnya: rencana Fase 2 (Al-Qur'an offline).

## Data

| Item | Status | Catatan |
|---|---|---|
| Quran (114 file, 6.236 ayat) | Ada, di `data-source/quran/` | Teks Arab, terjemahan Indonesia, tafsir Kemenag. Skema konsisten |
| Hadis (9 kitab, 38.102 hadis) | Ada | Field: number, arab, id. 69 MB, di `data-source/hadith/` |
| Info surah | Sebagian | Arti nama surah sudah ada di sumber Quran (`translations.id.name`, masuk ke kolom `name_id`). Tempat turun belum ada: perlu sumber di `data-source/meta/` (Q4) |
| Pemetaan juz | Belum ada | Perlu sumber di `data-source/meta/` |
| Data kota dan koordinat | Belum ada | Untuk pilihan lokasi, id kota di API jadwal, dan perhitungan offline |
| Daftar kurasi ayat harian (`meta/daily_ayah.json`) | Belum ada | Disusun pemilik proyek (Q9). Tanpa file ini fitur ayat harian disembunyikan |
| Transliterasi Latin | Belum ada | Di luar cakupan v1 kecuali sumber ditemukan |
| Audio murottal | Lewat API opsional | Penyedia belum dipilih |
| Jadwal sholat | Lewat API per bulan, disimpan lokal | Penyedia belum dipilih. Cadangan: perhitungan offline berlabel "perkiraan" |
| content.db dan skrip build/verifikasi | Selesai | Skema FTS5 contentless, 112,38 MB, `verify --full` lulus. Versi lewat sidecar `assets/db/content.version`. Dihasilkan lokal oleh `tool/prepare_content.sh`, tidak di-commit |

## Desain UI

| Item | Status | Catatan |
|---|---|---|
| Putaran desain 1 (Fondasi dan Fase 2) | Selesai, diserahkan 2026-11-11 | Brief: `docs/design/2026-11-09-nura-ui-design-brief.md`. Handoff ke Flutter: `docs/design/HANDOFF-flutter.md`. Token: `docs/design/tokens.json`. Di Figma (`Nura — UI v1`): 9 layar Fase 1 dan 16 layar Fase 2, masing-masing Light dan Dark |
| Putaran desain 2 | Belum | Layar hadis (termasuk detail dengan sanad), jadwal sholat bulanan, pengaturan notifikasi lengkap, pengunduhan audio, pengaturan umum, daftar kota, ikon aplikasi final, materi Play Store |
| Tema dari token desain | Belum | Tema saat ini masih dasar. Terapkan `ColorScheme`, `NuraColors`, `NuraTextStyles`, dan konstanta jarak/radius di `lib/app/core/theme/` dari `tokens.json` (jalur tetap `lib/app/core/theme/`; handoff menyebut `lib/core/theme/`, lihat catatan di AGENTS.md) |
| Font Arab LPMQ dan font Latin Plus Jakarta Sans | Belum ada di repo | Lisensi font Arab dicek sebelum rilis (Q6) |
| Placeholder di desain | Ada | Slot "[Q4]" (tempat turun, juz). Teks "~XXX MB" di layar error ruang penyimpanan: isi saat layar itu dibangun (ukuran `content.db` 112,38 MB; perhitungkan ruang `.tmp` saat pembaruan). Ikon selain `history` dan ilustrasi masih placeholder. Wordmark sementara (Q2) |

## Fitur v1

| Fitur | Status |
|---|---|
| Fondasi (struktur, paket, pipeline data, user.db) | Selesai (2026-11-10): pipeline data, `ContentDatabase`/installer, `user.db` dengan migrasi, bootstrap, DI, tema, route awal. Installer tidak lagi membaca 112 MB per start (hanya asset `content.version`), salinan memakai streaming native di Android. Uji manual di perangkat asli: pemilik proyek melaporkan aplikasi berjalan (rincian per langkah belum dicatat) |
| Al-Qur'an offline (surah, detail, tafsir, juz, bookmark, last read, cari) | Belum mulai |
| Hadis (kitab, daftar, detail, cari, bookmark) | Belum mulai |
| Jadwal sholat dan notifikasi | Belum mulai |
| 1 Hari 1 Ayat/Hadis (kartu dan notifikasi harian) | Belum mulai |
| Widget layar depan Android (dirender sebagai gambar dari Flutter) | Belum mulai |
| Fitur online: audio murottal | Belum mulai |
| Onboarding, atribusi, ikon, rilis | Belum mulai |

## Keputusan

| Tanggal | Keputusan |
|---|---|
| 2026-11-08 | Aplikasi Islami umum: Quran, hadis, jadwal sholat. Doa dan lainnya menyusul |
| 2026-11-08 | Target rilis publik di Play Store |
| 2026-11-08 | v1 memuat Quran, hadis, jadwal sholat, dan 1 Hari 1 Ayat/Hadis |
| 2026-11-08 | Widget layar depan Android untuk 1 Hari 1 Ayat/Hadis |
| 2026-11-09 | Offline-first. Fitur online (audio) opsional, mati secara default |
| 2026-11-09 | Konten dikonversi ke SQLite saat build (`content.db`, read-only). JSON asli disimpan di `data-source/` sebagai sumber kebenaran |
| 2026-11-09 | Integritas data dijamin dengan checksum dan verifikasi baris demi baris |
| 2026-11-09 | Data pengguna di `user.db` terpisah |
| 2026-11-09 | Rebuild bersih di branch baru, kode lama tidak ditambal |
| 2026-11-09 | Nama paket Dart: `nura` |
| 2026-11-09 | Pesan commit dalam Bahasa Inggris (Conventional Commits) |
| 2026-11-09 | Application ID Android: `com.technowstack.nura` (belum diterapkan di kode, dikerjakan di fase Fondasi) |
| 2026-11-09 | Git LFS sengaja tidak dipakai: file terbesar 13,4 MB (di bawah batas 100 MB GitHub), data tidak berubah, dan data sudah ada di riwayat git sehingga LFS tidak mengecilkan repo. Menambah LFS nanti butuh migrasi yang menulis ulang riwayat |
| 2026-11-09 | Jadwal sholat diambil dari API per bulan dan disimpan. Izin sinkron jadwal terpisah dari sakelar audio dan ditanyakan saat onboarding |
| 2026-11-09 | Jika belum ada jadwal tersimpan dan offline, jadwal dihitung offline (`adhan`, parameter Kemenag) dan diberi label "perkiraan" |
| 2026-11-09 | 1 Hari 1 Ayat memakai daftar kurasi (`data-source/meta/daily_ayah.json`). 1 Hari 1 Hadis dipilih otomatis dengan filter panjang terjemahan (maks. 400 karakter). Filter ini sementara dan digantikan aturan matan di Fase 6 (lihat keputusan 2026-11-11) |
| 2026-11-09 | Paket SQLite: `sqlite3` + `sqlite3_flutter_libs` (bukan `sqflite`), agar FTS5 pasti tersedia |
| 2026-11-09 | Sumber Quran: Kemenag. Sumber hadis: gadingnst/hadith-api (MIT, data asal tafsirq.com) |
| 2026-11-11 | Putaran desain 1: 1 Hari 1 Ayat/Hadis tampil di tiga tempat, yaitu kartu Beranda, widget layar depan, dan notifikasi harian |
| 2026-11-11 | Widget dirender sebagai gambar dari Flutter (font LPMQ tidak bisa dipakai di RemoteViews). Widget statis: tanpa tombol, seluruh widget satu area ketuk. Ukuran 4×2 dan 4×3, terang dan gelap |
| 2026-11-11 | Notifikasi harian ayat/hadis: satu per hari, jam bisa diatur atau dimatikan, default 06.00 dan bisa diubah pengguna. Isi terjemahan dan rujukan saja, tanpa teks Arab. Sakelar "Ayat & hadis harian" di onboarding langkah c, bersama "Pengingat adzan" |
| 2026-11-11 | Hadis harian menampilkan matan hasil ekstraksi: matan Arab dan matan terjemahan sama-sama substring persis dari sumber, dan keduanya harus bisa diekstrak bersih agar hadis lolos seleksi. Aturan seleksi lengkap (batas panjang N) ditetapkan di Fase 6 dan akan mengubah `daily_hadith`, jadi butuh persetujuan pemilik proyek saat itu |
| 2026-11-11 | Hadis harian secara default hanya dari Shahih Bukhari dan Shahih Muslim. Pengguna bisa memperluasnya ke 9 kitab di Pengaturan. Batas panjang matan (N) dan ekstraksi ditetapkan di Fase 6 |
| 2026-11-11 | Aturan cuplikan hasil pencarian Al-Qur'an: jendela maksimal 100 karakter berpusat pada kata cocok, dipotong ke batas kata, elipsis di sisi yang terpotong, isi cuplikan substring persis, semua kata cocok disorot, hasil dikelompokkan per surah (spec bagian 5.5) |
| 2026-11-11 | Lisensi font Arab (LPMQ Isep Misbah, cadangan KFGQPC Uthmanic Script Hafs) wajib dicek sebelum rilis: masuk Q6 |
| 2026-11-11 | Desain UI putaran 1 menjadi acuan tampilan (`docs/design/`): Material 3, font Latin Plus Jakarta Sans (OFL), ukuran teks Arab 20–40 (default 28) |
| 2026-11-11 | Seleksi matan hadis harian ditunda ke Fase 6 dan butuh persetujuan pemilik proyek (mengubah `daily_hadith`) |
| 2026-11-11 | Jalur kode tema tetap `lib/app/core/theme/`. `HANDOFF-flutter.md` tidak diubah; pemetaan jalur dicatat di AGENTS.md |
| 2026-11-11 | `main` adalah cabang utama. Setiap fase dikerjakan di branch sendiri (`feat/phase-N-<nama>`), lalu `merge --no-ff` ke `main` setelah review akhir (riwayat tidak di-squash). Commit docs langsung di `main` diperbolehkan |
| 2026-11-11 | Repo hanya menyimpan tiga berkas desain: `tokens.json`, `HANDOFF-flutter.md`, dan brief. `review-round1.md`, `tokens.dart`, `CLAUDE.md`, `STATUS-desain.md`, dan file FigCraft milik proyek desain terpisah dan tidak disalin. Sumber token = `tokens.json` |

## Pertanyaan Terbuka

| ID | Pertanyaan | Blokir |
|---|---|---|
| Q2 | Nama aplikasi Nura: cek Play Store dan DJKI | Rilis |
| Q3 | Penyedia API audio dan jadwal sholat, beserta syarat penggunaannya | Fitur online, jadwal sholat |
| Q4 | Sumber data meta: info surah, juz, kota | Quran (juz), jadwal sholat |
| Q5 | Parameter perhitungan offline (ihtiyat, dll.) untuk cadangan jadwal sholat | Jadwal sholat |
| Q6 | Ketentuan tashih LPMQ untuk Al-Qur'an digital, dan lisensi font Arab (LPMQ Isep Misbah; cadangan KFGQPC Uthmanic Script Hafs). LPMQ diambil dari sumber resmi (lajnah.kemenag.go.id/unduhan), catat tanggal unduh di catatan rilis | Rilis |
| Q7 | Konfirmasi lisensi teks terjemahan hadis | Rilis |
| Q8 | Verifikasi isi `data-source/` ke sumber asli (hadis: `gadingnst/hadith-api`). Assets asli sebelum dipindah tidak tersedia untuk dibandingkan. Tugas terpisah | Integritas data, rilis |
| Q9 | Daftar kurasi `data-source/meta/daily_ayah.json` (disusun pemilik proyek) | 1 Hari 1 Ayat (Fase 6) |

## Langkah Berikutnya

1. Cek manual di perangkat: waktu first-run dan memori untuk salinan native masih tertunda. Catat hasilnya setelah dijalankan.
2. Merge lokal ke `main` sudah dilakukan (merge commit `7b0340c`). Push hanya setelah pemilik proyek memastikan repo privat.
3. Tinjau rencana Fase 2 (`docs/plans/2026-11-11-nura-phase2-quran.md`, branch `feat/phase-2-quran`) dan jawab 10 keputusan di bagian awalnya, terutama paket `scrollable_positioned_list` dan file font di `assets/fonts/`. Data meta (Q4) dicari paralel.
4. Siapkan putaran desain 2 (hadis, jadwal sholat, pengaturan, ikon) sebelum Fase 3.
4. Clone baru: jalankan `tool/prepare_content.sh` sebelum `flutter run`/`build`/`test`.

## Catatan Teknis

- Ukuran sumber: `data-source/` 82 MB (Quran 12 MB, hadis 69 MB; Bukhari 13,4 MB terbesar).
- `content.db` dibuat lokal oleh `tool/prepare_content.sh` dan di-`.gitignore`, begitu juga `content.version`. Nilai `content.version` (`<schema_version>:<16 hex sha256 file db>`) dan `meta.data_version` (16 hex sha256 `CHECKSUMS.sha256`) diturunkan otomatis, tidak dipatok tangan. `built_at` tetap sehingga build deterministik; host dengan versi libsqlite3 berbeda menghasilkan hash berbeda (hanya satu salin ulang di perangkat). Test: 87 lulus. Clone baru wajib menjalankannya dulu: `pubspec.yaml` mendaftarkan `assets/db/content.db`, dan `flutter test`/`build` gagal ("No file or variants found for asset") jika file tidak ada.
- Ukuran `content.db` per `page_size`: 4096 = 124,54 MB; 8192 = 118,28 MB; 16384 = 112,38 MB (dipakai); 32768 = 109,03 MB (dicoba, tidak dipakai). Sebelum skema contentless: 187 MB. Rincian (page 4096): hadith 85,1 MB, hadith_fts 22,9 MB, ayah 13,9 MB.
- Ukuran build (2026-11-09): APK debug 200.414.436 byte (191 MiB); AAB release 80,4 MB (flutter) / 76,7 MiB, ditandatangani dengan kunci debug (template proyek `build.gradle.kts` memakai `signingConfig debug`). Perkiraan unduhan `bundletool get-size total`: tidak tersedia (bundletool tidak terpasang).
- Verifikasi checksum: 123 file di `data-source/` cocok semuanya dengan cadangan `../nura-data-backup/` (dibuat dari `data-source/` setelah dipindah, bukan dari assets asli).
- Belum dijalankan di repo lama: `flutter analyze`, test, dan aplikasi di emulator.
