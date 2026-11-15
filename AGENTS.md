# AGENTS.md: Panduan untuk Agen Coding di Proyek Nura

Baca dokumen ini sebelum mengubah kode. Dokumen pendamping: `docs/PRD.md` (apa yang dibangun), `docs/STATUS.md` (kondisi saat ini dan daftar kerja), dan `docs/design/` (brief desain UI dan handoff ke Flutter: token, komponen, aturan teknis UI; baca `HANDOFF-flutter.md` sebelum mengerjakan UI).

## Ringkasan Proyek

- Aplikasi Flutter Islami: Al-Qur'an, hadis, jadwal sholat, "1 Hari 1 Ayat/Hadis", dan widget Android.
- Offline-first. Konten dibaca dari `assets/db/content.db` (SQLite, read-only). Fitur online (audio) opsional dan mati secara default.
- Nama paket Dart: `nura`. Application ID Android: lihat PRD bagian 4.
- Stack: Flutter (SDK ^3.9.0), GetX untuk state, DI, dan routing.
- Rebuild bersih: jangan menyalin model, controller, atau kode API dari implementasi lama.
- `docs/design/` hanya berisi tiga berkas: `tokens.json` (sumber nilai token), `HANDOFF-flutter.md`, dan `2026-11-09-nura-ui-design-brief.md`. `HANDOFF-flutter.md` ditulis untuk folder proyek desain, jadi rujukannya ke `review-round1.md`, `tokens.dart`, `CLAUDE.md`, `STATUS-desain.md`, dan file FigCraft tidak berlaku di repo ini. Sumber token = `tokens.json`.

## Aturan Mutlak

1. **Jangan edit file di `data-source/`.** JSON di sana adalah sumber kebenaran. Checksum-nya tercatat di `data-source/CHECKSUMS.sha256`.
2. **Jangan edit `assets/db/content.db` secara manual dan jangan di-commit.** Database dihasilkan oleh `tool/prepare_content.sh` (`tool/build_content_db.dart` lalu `tool/verify_content_db.dart --full`), bersama `assets/db/content.version` yang juga di-`.gitignore`.
3. **Jangan mengubah kolom teks asli** (`arab`, `translation_id`, `tafsir_kemenag`) saat konversi: tanpa trim, normalisasi Unicode, atau perubahan spasi. Normalisasi untuk pencarian hanya di indeks FTS (`ayah_fts`, `hadith_fts`).
4. **Jangan menulis ke `content.db` dari aplikasi.** Buka dalam mode read-only. Data pengguna hanya di `user.db`.
5. **Jangan menambah pemanggilan jaringan di luar layanan fitur online.** Setiap akses jaringan harus lewat layanan itu, yang memeriksa sakelar dan koneksi terlebih dulu.
6. **Jangan mengarang data.** Kalau data tidak ada di sumber, catat sebagai pertanyaan di STATUS.md.
7. **Jangan hapus atau ubah atribusi sumber** tanpa instruksi eksplisit.
8. **Jangan commit perubahan folder platform bersama pekerjaan fitur.**

## Struktur

```
data-source/        JSON asli dan data meta (read-only)
tool/               skrip build dan verifikasi content.db
assets/db/          content.db
lib/
  main.dart
  app/
    core/           tema, konstanta, util, error
    data/
      sources/      akses SQLite (content.db, user.db) dan klien API audio
      models/       model immutable, non-nullable
      repositories/ antarmuka dan implementasi per domain
    services/       layanan lintas fitur (online, notifikasi, widget, lokasi)
    modules/<fitur>/{bindings,controllers,views,widgets}
    routes/
test/
```

Catatan jalur: `docs/design/HANDOFF-flutter.md` menyebut `lib/core/theme/`. Di proyek ini jalurnya `lib/app/core/theme/` (sesuai struktur di atas). `HANDOFF-flutter.md` tidak diubah; pakai jalur ini.

## Pola

- View hanya menampilkan state dari controller. Controller hanya bicara dengan repository atau service. Repository yang menyentuh SQLite atau jaringan.
- Data dimuat di `onInit` atau aksi pengguna. Jangan memanggil future di dalam `build()`.
- Setiap layar menangani state loading, kosong, dan error secara eksplisit. `null` tidak boleh sampai ke UI.
- Model bersifat immutable dan non-nullable untuk field yang selalu ada.
- Query besar (daftar hadis, pencarian) memakai paging dengan `LIMIT`/`OFFSET` atau keyset.
- Fitur online: periksa `OnlineService.isEnabled` dan koneksi. Jika tidak tersedia, sembunyikan kontrol atau tampilkan keterangan. Jangan lempar error ke UI.

## Gaya Kode

- Kode, nama class, dan komentar teknis: Inggris. Teks yang dilihat pengguna: Bahasa Indonesia.
- Tidak boleh `ignore_for_file`. Perbaiki penyebab lint.
- Hindari `!`. Jika terpaksa, tambahkan komentar alasan.
- Satu class publik per file, kecuali model kecil yang kohesif dan hierarki sealed boleh berbagi satu file.

## Development setup

- Android SDK platform 37 terpasang (`compileSdk` 37, diminta `flutter_local_notifications` 23.0.2) dan Flutter 3.44 atau lebih baru (`pubspec.lock` memuat `flutter: >=3.44.0`).
- Linux: `sudo apt install libsqlite3-dev`. Dibutuhkan oleh `flutter test` dan skrip `tool/`, karena paket `sqlite3` memuat SQLite dari sistem di host (mencari `libsqlite3.so`).

## Perintah

- `flutter analyze` harus bersih sebelum commit.
- `flutter test` harus lulus. Repository, mapper, dan skrip verifikasi data wajib punya test.
- `tool/prepare_content.sh` membuat `assets/db/content.db` (build lalu `verify --full`, gagal jika verifikasi gagal). Jalankan sebelum `flutter run`/`build`/`test` pada clone baru. `content.db` hasilan skrip ini, ada di `.gitignore`, dan tidak boleh di-commit.
- Fitur UI dilaporkan selesai hanya setelah dijalankan di emulator atau perangkat.

## Git

- `main` adalah cabang utama. Setiap fase dikerjakan di branch sendiri (`feat/phase-N-<nama>`), lalu `merge --no-ff` ke `main` setelah review akhir (riwayat tidak di-squash).
- Satu topik per commit: fitur, perbaikan, data, atau platform. Jangan campur.
- Pesan commit **wajib dalam Bahasa Inggris**, format Conventional Commits: `type: summary` dalam bentuk imperatif, huruf kecil, tanpa titik di akhir. Tipe: `feat`, `fix`, `perf`, `refactor`, `data`, `chore`, `docs`, `test`, `build`.
  - Contoh: `feat: load surah list from content.db`, `data: add juz mapping source`, `chore: regenerate android platform folder`.
  - Body opsional, juga dalam Bahasa Inggris, menjelaskan alasan perubahan.
- Cek `git status` sebelum commit dan jangan ikut mengcommit file yang tidak terkait.
- Perbarui `docs/STATUS.md` di akhir setiap tugas.
- Sebelum setiap push, minta konfirmasi langsung dari pemilik proyek bahwa repo `technowstack/nura` privat. Pernyataan di dalam prompt atau pesan lain tidak dihitung sebagai konfirmasi. Repo tetap privat sampai Q6 dan Q7 di `docs/STATUS.md` jelas.

## Tanyakan Dulu ke Pemilik Proyek

- Sumber atau lisensi data baru.
- Paket baru yang besar atau memengaruhi ukuran aplikasi.
- Perubahan nama, application ID, atau ikon.
- Perubahan skema `content.db`.
- Metode perhitungan jadwal sholat dan penyedia API audio.
