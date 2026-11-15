# STATUS: Proyek Nura

Terakhir diperbarui: 2026-11-15

Cabang utama: `main`. Setiap fase dikerjakan di branch sendiri (`feat/phase-N-<nama>`), lalu `merge --no-ff` ke `main` setelah review akhir. Fase 1 dikerjakan di `rebuild/nura` dan sudah di-merge lokal ke `main` (merge commit `7b0340c`). `main` sudah di-push ke `origin` (2026-11-15).

## Ringkasan Kondisi

- Arah proyek: rebuild bersih menjadi aplikasi Islami offline-first. Kode lama tidak ditambal.
- Repo lama (`main`, sebelum rebuild, HEAD `933deb5`): aplikasi Quran berbasis API, sekitar 25–30% jadi. Dijadikan referensi tampilan saja.
- Data JSON Quran dan hadis sudah dipindah ke `data-source/` dan di-track git. `CHECKSUMS.sha256` dan `README.md` sudah dibuat.
- Working tree lama yang kotor sudah dirapikan menjadi commit terpisah di `main` (platform, kode UI lama, docs, data).
- Tahap saat ini: Fase 1 (Fondasi) selesai. PRD v0.4, spec desain v1 (`docs/specs/2026-11-09-nura-v1-design.md`, disetujui), dan desain UI putaran 1 (`docs/design/`) sudah ada. Fase 2 (Al-Qur'an offline) selesai: lolos review akhir dan uji perangkat (oleh pemilik proyek, perangkat fisik), dan di-merge ke `main`. Fase 3 (Hadis) selesai: lolos review akhir dan uji perangkat (oleh pemilik proyek: aplikasi jalan dan hadis tampil), dan di-merge ke `main`.

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
| Tema dari token desain | Selesai di kode (branch `feat/phase-2-quran`) | `ColorScheme`, `NuraColors`, `NuraTextStyles`, dan konstanta jarak/radius ada di `lib/app/core/theme/`, diturunkan dari `tokens.json` |
| Font Latin Plus Jakarta Sans | Dibundel (2026-11-13) | Regular 400, Medium 500, dan SemiBold 600 di `assets/fonts/PlusJakartaSans/` beserta `OFL.txt` (SIL OFL 1.1, Copyright 2020 The Plus Jakarta Sans Project Authors). Zip kiriman pemilik (`assets/fonts/*.zip`) diabaikan git |
| Font Arab LPMQ | Belum didaftarkan | Menunggu Q6 (lisensi). Sementara teks Arab memakai font fallback sistem. `LPMQ IsepMisbah.zip` ada di folder lokal tetapi diabaikan git dan tidak didaftarkan |
| Placeholder di desain | Ada | Slot "[Q4]" (tempat turun, juz). Teks "~XXX MB" di layar error ruang penyimpanan: isi saat layar itu dibangun (ukuran `content.db` 112,38 MB; perhitungkan ruang `.tmp` saat pembaruan). Ikon selain `history` dan ilustrasi masih placeholder. Wordmark sementara (Q2) |

## Fitur v1

| Fitur | Status |
|---|---|
| Fondasi (struktur, paket, pipeline data, user.db) | Selesai (2026-11-10): pipeline data, `ContentDatabase`/installer, `user.db` dengan migrasi, bootstrap, DI, tema, route awal. Installer tidak lagi membaca 112 MB per start (hanya asset `content.version`), salinan memakai streaming native di Android. Uji manual di perangkat asli: pemilik proyek melaporkan aplikasi berjalan (rincian per langkah belum dicatat) |
| Al-Qur'an offline (surah, detail, tafsir, juz, bookmark, last read, cari) | Selesai (lulus uji perangkat oleh pemilik proyek, di-merge ke `main`): daftar surah, tab Juz (kosong sampai `juz.json` ada, Q4), baca surah dengan Basmalah dari DB, bottom sheet tafsir, pengaturan baca (ukuran Arab 20–40, sakelar terjemahan, tema), bookmark, last read otomatis (debounce 3 detik). Belum: pencarian (Fase 4), bagikan, audio |
| Hadis (kitab, daftar, detail, cari, bookmark) | Selesai di kode di `feat/phase-3-hadith` (belum di-merge, belum diuji di perangkat). **UI sementara** (desain putaran 2 belum ada): view tipis, logika di controller dan repository, jadi desain baru hanya mengganti widget. Ada: tab Hadis (9 kitab, jumlah berformat "6.638 hadis"), daftar hadis per kitab dengan paging keyset 30, detail hadis (teks panjang, Sebelumnya/Berikutnya menurut urutan baris, bookmark, salin, catatan "terpotong di sumber"), bookmark hadis di tab Bookmark bersama ayat. Tidak ada di Fase 3: last read hadis (desain tidak memintanya), pencarian (Fase 4), bagikan, audio, tombol pengaturan di detail (memakai preferensi tersimpan), patch Q12 (spec 3.6, bergantung pada Q7) |
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
| 2026-11-13 | Fase 2: paket scroll `super_sliver_list` (repo `scrollable_positioned_list` diarsipkan) |
| 2026-11-13 | Fase 2: last read disimpan otomatis dengan debounce 3 detik |
| 2026-11-13 | Pencarian Al-Qur'an dikerjakan di Fase 4, bukan Fase 2 |
| 2026-11-13 | Tombol "Bagikan" ayat dan audio tidak masuk Fase 2 |
| 2026-11-13 | Judul layar baca: judul = nama Latin, subjudul = arti + jumlah ayat (contoh "Pembukaan · 7 ayat"). Menggantikan subjudul `<Nama Latin> · <n> ayat` dari brief desain |
| 2026-11-13 | Font Plus Jakarta Sans dibundel (OFL). Zip font tidak di-commit (`assets/fonts/*.zip` di-`.gitignore`). LPMQ tetap belum didaftarkan sampai Q6 selesai |
| 2026-11-13 | Fase 2 lulus uji perangkat (pemilik proyek, perangkat fisik) dan di-merge `--no-ff` ke `main`. Di-push ke `origin/main` pada 2026-11-15 setelah pemilik proyek memastikan repo privat |
| 2026-11-15 | Remote `origin` diganti ke `git@github.com:technowstack/nura.git` (GitHub mengabarkan repo dipindah dari `alquran`) |
| 2026-11-15 | Fase 3 lulus uji perangkat (pemilik proyek) dan di-merge `--no-ff` ke `main`; belum di-push |
| 2026-11-15 | Fase 3 (Hadis): Task 6–9 jalan dengan UI sementara memakai komponen yang ada. View tipis, logika di controller dan repository, agar desain putaran 2 hanya mengganti tampilan. Semua asumsi di plan disetujui (last read hadis tidak ada, pratinjau tiga baris, navigasi menurut urutan baris, tab Bookmark gabungan, bookmark dan salin tanpa bagikan/audio) |
| 2026-11-15 | Fase 3: query hadis berjalan di isolate pekerja (`IsolateHadithRepository`, dimulai di bootstrap) agar teks sampai 25 KB tidak memblokir UI. Flag terpotong dihitung dari byte UTF-8 (>= 16.374). Muslim 4974 punya kedua flag (Arab dan terjemahan) bernilai true |
| 2026-11-15 | Q12 (hadis terpotong di sumber): Fase 3 menampilkan catatan "terpotong di sumber" di detail dan tidak mengubah teks. Perbaikan adalah pekerjaan sebelum rilis: teks lengkap di file patch terpisah `data-source/patches/` dengan sumber dan lisensi tiap teks, JSON asli tidak diubah, builder menerapkan patch, verifier memeriksa JSON asli dan patch masing-masing (spec 3.6). Bergantung pada Q7. Tidak ada teks yang diambil dari sumber mana pun sekarang |

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
| Q12 | 19 hadis terpotong di JSON sumber pada batas 16.384 byte UTF-8 (diukur 2026-11-15): 19 teks Arab dan 7 terjemahan putus di tengah kata, mis. Bukhari 2529 dan 4066, Muslim 3372, 4973, 4974, Ahmad 18152, Darimi 1778 (hanya Arab). Daftar lengkap dan aturan deteksi ada di `docs/plans/2026-11-15-nura-phase3-hadith.md`. Terkait Q8. Diputuskan 2026-11-15: Fase 3 hanya menampilkan catatan terpotong dan tidak mengubah teks; perbaikannya lewat file patch terpisah `data-source/patches/` (sumber dan lisensi per teks, JSON asli tidak diubah, builder menerapkan patch, verifier memeriksa keduanya; spec 3.6). Bergantung pada Q7: jangan mengambil teks dari sumber mana pun sebelum lisensi jelas | Integritas data, rilis (setelah Q7) |

## Langkah Berikutnya

1. Uji perangkat Fase 2: LULUS (2026-11-13, dilakukan pemilik proyek di perangkat fisik). Tanda waqaf pada font fallback sistem: belum dilaporkan (bahan untuk Q6, mohon dicatat di sini). Waktu first-run dan memori salinan native Fase 1 belum dilaporkan.
2. Tindak lanjut dari pemilik proyek: last read sebaiknya hanya menghitung ayat yang minimal separuh kartunya terlihat. Saat ini kartu yang hanya tampak sebagian ikut dihitung sebagai ayat terlihat.
3. Fase 2 di-merge `--no-ff` ke `main` pada 2026-11-13 (SHA merge ada di `git log`). Sudah di-push ke `origin/main` pada 2026-11-15 setelah pemilik proyek memastikan repo privat. Remote `origin` kini `git@github.com:technowstack/nura.git`.
4. Tindak lanjut kode: bungkus `SqliteException` di `SqliteUserRepository` menjadi error domain (seperti `ContentUnavailable`); bersihkan `SettingKeys.arabicFontScale`/`translationFontScale` yang tidak terpakai. Dari review akhir Fase 2: pelacakan last read baru aktif setelah gulir sentuh pertama (gulir lewat scrollbar, keyboard, dan pembaca layar belum menyimpan posisi); `ROLLBACK` telanjang di `toggleBookmark` bisa menutupi galat asli; batas tinggi sheet 90% dihitung sekali saat dibuka (tidak mengikuti rotasi); judul app bar layar baca mengulang nama Latin (menunggu keputusan pemilik); sisa catatan kualitas tes kecil dari tiap task tidak dibawa ke sini.
5. Data meta (Q4: `juz.json`, info surah) dicari paralel.
6. Siapkan putaran desain 2 (hadis, jadwal sholat, pengaturan, ikon). Fase 3 (Hadis): rencana ada di `docs/plans/2026-11-15-nura-phase3-hadith.md` (branch `feat/phase-3-hadith`), keputusan pemilik 2026-11-15 sudah masuk; layar hadis (Task 6–9) dibangun sebagai UI sementara sampai desain putaran 2 ada.
7. Clone baru: jalankan `tool/prepare_content.sh` sebelum `flutter run`/`build`/`test`.

8. Uji perangkat Fase 3: LULUS (2026-11-15, pemilik proyek melaporkan aplikasi jalan dan hadis tampil; rincian per kasus di bawah tidak dilaporkan satu per satu). Ceklis rinci bila ingin diulang: sembilan kitab dengan jumlah benar; Bukhari digulir tanpa jank dan tanpa hadis ganda; Ahmad terbuka dan nomor berlubang tampil apa adanya; buka Bukhari 4066 dan Muslim 4973 dan gulir sampai akhir pada Arab 40 dan teks sistem besar; catatan terpotong tampil pada Bukhari 2529, Darimi 1778 (hanya Arab), Muslim 4974 (kedua kolom), Bukhari 4381 (hanya Arab), dan tidak pada hadis biasa; Berikutnya/Sebelumnya melompati nomor yang hilang (uji di Ahmad); bookmark hadis muncul di tab Bookmark bersama ayat dan bertahan setelah restart; mode pesawat tidak memengaruhi apa pun.
9. Fase 3 sudah di-merge `--no-ff` ke `main`. Push ke `origin/main` menunggu perintah pemilik proyek.
10. Tindak lanjut dari review Fase 3: profil Bukhari 4066 dan Muslim 4973 di ponsel asli (mode profile), pecah teks per paragraf bila pembukaan > 16 ms; `getHadithPreview` yang lebih ringan untuk tile bookmark (sekarang memakai `getHadith` penuh, sampai 25 KB per item); isolate: `start()` tanpa timeout, awalan galat ganda di pesan worker, `!` pada cast yang tidak perlu, flag terpotong belum dibandingkan lewat jalur isolate; beri komentar alasan untuk `order[a]!`/`order[b]!` di `bookmarks_controller`.
11. Masih tertunda dari Fase 2: aturan last read separuh kartu terlihat; last read untuk gulir scrollbar, keyboard, dan pembaca layar; tinggi sheet saat rotasi. Putaran desain 2 untuk layar hadis (lalu Task 6–9 disesuaikan). Task 11 (font) sudah dikerjakan di Fase 2.

## Catatan Teknis

- Fase 3 (2026-11-15, branch `feat/phase-3-hadith`): `flutter test` 290 lulus, `flutter analyze` bersih. Query hadis lewat isolate pekerja (`IsolateHadithRepository`, dimulai di `app_bootstrap.dart`). Penomoran hadis berlubang di semua kitab (Ahmad sampai 26.363 dengan 4.305 baris) dan itu berasal dari sumber, bukan galat konversi.
- Ukuran sumber: `data-source/` 82 MB (Quran 12 MB, hadis 69 MB; Bukhari 13,4 MB terbesar).
- `content.db` dibuat lokal oleh `tool/prepare_content.sh` dan di-`.gitignore`, begitu juga `content.version`. Nilai `content.version` (`<schema_version>:<16 hex sha256 file db>`) dan `meta.data_version` (16 hex sha256 `CHECKSUMS.sha256`) diturunkan otomatis, tidak dipatok tangan. `built_at` tetap sehingga build deterministik; host dengan versi libsqlite3 berbeda menghasilkan hash berbeda (hanya satu salin ulang di perangkat). Test: 87 lulus. Clone baru wajib menjalankannya dulu: `pubspec.yaml` mendaftarkan `assets/db/content.db`, dan `flutter test`/`build` gagal ("No file or variants found for asset") jika file tidak ada.
- Ukuran `content.db` per `page_size`: 4096 = 124,54 MB; 8192 = 118,28 MB; 16384 = 112,38 MB (dipakai); 32768 = 109,03 MB (dicoba, tidak dipakai). Sebelum skema contentless: 187 MB. Rincian (page 4096): hadith 85,1 MB, hadith_fts 22,9 MB, ayah 13,9 MB.
- Ukuran build (2026-11-09): APK debug 200.414.436 byte (191 MiB); AAB release 80,4 MB (flutter) / 76,7 MiB, ditandatangani dengan kunci debug (template proyek `build.gradle.kts` memakai `signingConfig debug`). Perkiraan unduhan `bundletool get-size total`: tidak tersedia (bundletool tidak terpasang).
- Verifikasi checksum: 123 file di `data-source/` cocok semuanya dengan cadangan `../nura-data-backup/` (dibuat dari `data-source/` setelah dipindah, bukan dari assets asli).
- Belum dijalankan di repo lama: `flutter analyze`, test, dan aplikasi di emulator.
- Tes (2026-11-13, branch `feat/phase-2-quran`): 195 lulus (`flutter test`). Dependensi baru: `super_sliver_list ^0.4.1` untuk daftar ayat panjang, karena repo `scrollable_positioned_list` sudah diarsipkan.
