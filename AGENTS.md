# AGENTS.md: Panduan untuk Agen Coding di Proyek Nura

Baca dokumen ini sebelum mengubah kode. Dokumen pendamping: `docs/PRD.md` (apa yang dibangun) dan `docs/STATUS.md` (kondisi saat ini dan daftar kerja).

## Ringkasan Proyek

- Aplikasi Flutter Islami: Al-Qur'an, hadis, jadwal sholat, "1 Hari 1 Ayat/Hadis", dan widget Android.
- Offline-first. Konten dibaca dari `assets/db/content.db` (SQLite, read-only). Fitur online (audio) opsional dan mati secara default.
- Nama paket Dart: `nura`. Application ID Android: lihat PRD bagian 4.
- Stack: Flutter (SDK ^3.9.0), GetX untuk state, DI, dan routing.
- Rebuild bersih: jangan menyalin model, controller, atau kode API dari implementasi lama.

## Aturan Mutlak

1. **Jangan edit file di `data-source/`.** JSON di sana adalah sumber kebenaran. Checksum-nya tercatat di `data-source/CHECKSUMS.sha256`.
2. **Jangan edit `assets/db/content.db` secara manual.** Database hanya dibuat ulang lewat `tool/build_content_db.dart`, lalu wajib lulus `tool/verify_content_db.dart` sebelum di-commit.
3. **Jangan mengubah kolom teks asli** (`arab`, `translation_id`, `tafsir_kemenag`) saat konversi: tanpa trim, normalisasi Unicode, atau perubahan spasi. Normalisasi untuk pencarian hanya di kolom `*_search` dan indeks FTS.
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
- Satu class publik per file.

## Perintah

- `flutter analyze` harus bersih sebelum commit.
- `flutter test` harus lulus. Repository, mapper, dan skrip verifikasi data wajib punya test.
- `dart run tool/build_content_db.dart` lalu `dart run tool/verify_content_db.dart` setiap kali data atau skema berubah.
- Fitur UI dilaporkan selesai hanya setelah dijalankan di emulator atau perangkat.

## Git

- Kerja di branch rebuild, bukan di `main` lama.
- Satu topik per commit: fitur, perbaikan, data, atau platform. Jangan campur.
- Pesan commit **wajib dalam Bahasa Inggris**, format Conventional Commits: `type: summary` dalam bentuk imperatif, huruf kecil, tanpa titik di akhir. Tipe: `feat`, `fix`, `refactor`, `data`, `chore`, `docs`, `test`, `build`.
  - Contoh: `feat: load surah list from content.db`, `data: add juz mapping source`, `chore: regenerate android platform folder`.
  - Body opsional, juga dalam Bahasa Inggris, menjelaskan alasan perubahan.
- Cek `git status` sebelum commit dan jangan ikut mengcommit file yang tidak terkait.
- Perbarui `docs/STATUS.md` di akhir setiap tugas.

## Tanyakan Dulu ke Pemilik Proyek

- Sumber atau lisensi data baru.
- Paket baru yang besar atau memengaruhi ukuran aplikasi.
- Perubahan nama, application ID, atau ikon.
- Perubahan skema `content.db`.
- Metode perhitungan jadwal sholat dan penyedia API audio.
