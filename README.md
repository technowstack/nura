# Nura

Aplikasi Islami untuk Android yang mengutamakan offline: Al-Qur'an, hadis, jadwal sholat, dan satu ayat serta satu hadis setiap hari. Dibuat dengan Flutter.

Versi `1.0.0+1`. Belum dirilis: lihat [syarat rilis](#syarat-rilis).

## Fitur

- **Al-Qur'an:** 114 surah dengan terjemahan dan tafsir Kemenag, baca per surah atau per juz, bookmark, terakhir dibaca.
- **Hadis:** 9 kitab (38.102 hadis), bookmark, salin dengan rujukan.
- **Pencarian** di Al-Qur'an dan hadis.
- **Jadwal sholat** per kabupaten/kota dengan pengingat.
- **Harian:** ayat dan hadis hari ini di Beranda, widget layar depan, dan notifikasi.
- **Audio murottal** (streaming), termasuk memutar satu juz.
- Tema terang dan gelap, ukuran huruf Arab dan terjemahan bisa diatur.

Konten Al-Qur'an dan hadis bisa dibaca tanpa internet. Dua hal memakai internet, dan keduanya bisa dimatikan: unduhan jadwal sholat (menyala secara default di onboarding) dan "Fitur Online" untuk audio (mati secara default). Tidak ada akun, analitik, atau iklan.

## Menjalankan

Prasyarat:

- Flutter 3.44 atau lebih baru.
- Android SDK platform 37.
- Linux: `sudo apt install libsqlite3-dev` (dipakai `flutter test` dan skrip di `tool/`).

```sh
flutter pub get
tool/prepare_content.sh   # membuat assets/db/content.db dari data-source/
flutter run
```

`tool/prepare_content.sh` wajib dijalankan pada clone baru. `content.db` tidak disimpan di git.

## Memeriksa

```sh
flutter analyze
flutter test
```

## Build rilis

Penandatanganan membaca `android/key.properties` dan tidak memakai kunci debug sebagai cadangan. Tanpa berkas itu build rilis gagal. Langkah membuat keystore dan membangun AAB ada di [docs/release/signing.md](docs/release/signing.md).

Keystore dan `key.properties` tidak boleh masuk git.

## Struktur

```
data-source/   JSON asli (sumber kebenaran, jangan diedit)
tool/          skrip pembuat, pemeriksa, dan pengambil data
lib/app/       core, data, services, modules, routes
assets/        content.db (hasil skrip), font, logo (assets/icon/)
docs/          PRD, spec, rencana, desain, status, dokumen rilis
test/
```

Arsitektur: GetX untuk state, DI, dan routing; view menampilkan state dari controller, controller memakai repository atau service. `content.db` dibuka read-only; data pengguna ada di `user.db`.

## Dokumen

- [AGENTS.md](AGENTS.md): aturan kerja, baca sebelum mengubah kode.
- [docs/PRD.md](docs/PRD.md): apa yang dibangun.
- [docs/STATUS.md](docs/STATUS.md): kondisi saat ini dan daftar kerja.
- [docs/design/](docs/design/): token dan handoff desain.
- [docs/release/](docs/release/): penandatanganan, izin, Data Safety, kebijakan privasi (draf).

## Sumber dan atribusi

- Teks Arab, terjemahan, dan tafsir Al-Qur'an: Kementerian Agama RI.
- Hadis: [gadingnst/hadith-api](https://github.com/gadingnst/hadith-api) (MIT), data asal tafsirq.com.
- Jadwal sholat, audio, dan tempat turun surah: [EQuran.id](https://equran.id). Audio: EQuran.id (sumber: Verse By Verse Quran).
- Batas juz: [Tanzil.info](https://tanzil.net), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), data diformat ulang.
- Font: Plus Jakarta Sans dan Scheherazade New (SIL OFL 1.1).
- Ikon: Material Symbols (Apache 2.0).

Rincian lisensi data ada di [data-source/README.md](data-source/README.md).

## Syarat rilis

Rilis publik masih terblokir oleh beberapa hal di luar kode, antara lain status lisensi teks Al-Qur'an (tashih LPMQ) dan terjemahan hadis. Daftar lengkapnya ada di bagian "Pertanyaan Terbuka" pada [docs/STATUS.md](docs/STATUS.md).
