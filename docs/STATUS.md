# STATUS: Proyek Nura

Terakhir diperbarui: 2026-11-09

Branch kerja: `rebuild/nura` (dibuat dari `main`, HEAD `25e3738`). Belum di-push.

## Ringkasan Kondisi

- Arah proyek: rebuild bersih menjadi aplikasi Islami offline-first. Kode lama tidak ditambal.
- Repo lama (`main`, sebelum rebuild, HEAD `933deb5`): aplikasi Quran berbasis API, sekitar 25–30% jadi. Dijadikan referensi tampilan saja.
- Data JSON Quran dan hadis sudah dipindah ke `data-source/` dan di-track git. `CHECKSUMS.sha256` dan `README.md` sudah dibuat.
- Working tree lama yang kotor sudah dirapikan menjadi commit terpisah di `main` (platform, kode UI lama, docs, data).
- Tahap saat ini: perencanaan. PRD v0.2 disusun. Spec desain belum dibuat.

## Data

| Item | Status | Catatan |
|---|---|---|
| Quran (114 file, 6.236 ayat) | Ada, di `data-source/quran/` | Teks Arab, terjemahan Indonesia, tafsir Kemenag. Skema konsisten |
| Hadis (9 kitab, 38.102 hadis) | Ada | Field: number, arab, id. 69 MB, di `data-source/hadith/` |
| Info surah (arti, tempat turun) | Belum ada | Perlu sumber di `data-source/meta/` |
| Pemetaan juz | Belum ada | Perlu sumber di `data-source/meta/` |
| Data kota dan koordinat | Belum ada | Untuk jadwal sholat offline |
| Transliterasi Latin | Belum ada | Di luar cakupan v1 kecuali sumber ditemukan |
| Audio murottal | Lewat API opsional | Penyedia belum dipilih |
| content.db dan skrip build/verifikasi | Belum dibuat | |

## Fitur v1

| Fitur | Status |
|---|---|
| Fondasi (struktur, paket, pipeline data, user.db) | Belum mulai |
| Al-Qur'an offline (surah, detail, tafsir, juz, bookmark, last read, cari) | Belum mulai |
| Hadis (kitab, daftar, detail, cari, bookmark) | Belum mulai |
| Jadwal sholat dan notifikasi | Belum mulai |
| 1 Hari 1 Ayat/Hadis (kartu) | Belum mulai |
| Widget layar depan Android | Belum mulai |
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
| 2026-11-09 | Sumber Quran: Kemenag. Sumber hadis: gadingnst/hadith-api (MIT, data asal tafsirq.com) |

## Pertanyaan Terbuka

| ID | Pertanyaan | Blokir |
|---|---|---|
| Q2 | Nama aplikasi Nura: cek Play Store dan DJKI | Rilis |
| Q3 | Penyedia API audio dan syarat penggunaannya | Fitur online |
| Q4 | Sumber data meta: info surah, juz, kota | Quran (juz), jadwal sholat |
| Q5 | Metode perhitungan jadwal sholat | Jadwal sholat |
| Q6 | Ketentuan tashih LPMQ untuk Al-Qur'an digital | Rilis |
| Q7 | Konfirmasi lisensi teks terjemahan hadis | Rilis |
| Q8 | Verifikasi isi `data-source/` ke sumber asli (hadis: `gadingnst/hadith-api`). Assets asli sebelum dipindah tidak tersedia untuk dibandingkan. Tugas terpisah | Integritas data, rilis |

## Langkah Berikutnya

1. Susun spec desain (skema `content.db`, struktur modul, alur fitur online, widget).
2. Susun rencana implementasi dari spec.
3. Mulai fase Fondasi di branch baru.

## Catatan Teknis

- Ukuran sumber: `data-source/` 82 MB (Quran 12 MB, hadis 69 MB; Bukhari 13,4 MB terbesar). Ukuran `content.db` dan AAB akan dicatat setelah build pertama.
- Verifikasi checksum: 123 file di `data-source/` cocok semuanya dengan cadangan `../nura-data-backup/` (dibuat dari `data-source/` setelah dipindah, bukan dari assets asli).
- Belum dijalankan di repo lama: `flutter analyze`, test, dan aplikasi di emulator.
