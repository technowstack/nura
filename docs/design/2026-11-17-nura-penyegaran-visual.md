# Nura — Penyegaran Visual (Putaran 1.5)

Tanggal: 17 November 2026 · Pemilik: Taufik Hidayat
Lokasi: folder desain `/mnt/itstaufikhdyt/Programming/Design/nura/`
Berlaku di atas: `2026-11-09-nura-ui-design-brief.md` (brief utama tetap jadi sumber kebenaran; dokumen ini menambah dan mengganti bagian yang disebut saja)

## 1. Kenapa

Putaran 1 sudah benar secara struktur, token, dan aksesibilitas, tapi rasanya masih terlalu polos. Referensi yang dipilih Taufik (folder `referensi/`) punya karakter yang ingin dicapai:

- Palet teal + emas yang tetap tenang. Ini **sejalan dengan token kita**, jadi palet tidak diganti, hanya dipertegas.
- Ornamen Islami dipakai sebagai **elemen fungsional**, misalnya bintang delapan sebagai bingkai nomor dan nama surah dalam kaligrafi. Ornamen bukan sekadar hiasan latar.
- Area "hero" Beranda yang berwarna penuh dan menjadi pusat informasi waktu sholat.
- Kartu terang di atas latar krem, dengan ikon garis berwarna emas.

Referensi dipakai sebagai **arah, bukan untuk disalin**. Tata letak, ilustrasi, dan detailnya dibuat sendiri.

## 2. Yang TIDAK diambil dari referensi

- Ilustrasi 3D (mushaf, masjid) dan render masjid fotorealistik. Terlihat generik dan butuh aset berlisensi.
- Bulan sabit + bintang sebagai logo atau hiasan, karena terlalu klise.
- Gradasi di kartu hero. Kedalaman dibangun dengan lapisan bidang datar dua nada, bukan gradasi.
- Fitur di luar cakupan v1: checklist aktivitas, Hifz, Qibla, Zakat, Donasi, Tasbih, dan transliterasi Latin. Fitur seperti ini tidak boleh muncul di layar, meskipun hanya sebagai ikon.
- Menu cepat di Beranda tetap dihapus (keputusan Langkah 2), karena isinya akan menduplikasi bottom nav.

## 3. Token baru dan perubahan

Semua sudah dicek kontrasnya.

| Variable | Light | Dark | Dipakai untuk |
|---|---|---|---|
| `color/ext/hero` | `#185A4B` | `#0F3F34` | Latar area hero Beranda (full-bleed di belakang status bar) |
| `color/ext/heroShape` | `#1B6252` | `#124A3D` | Bidang siluet di dalam hero (satu nada lebih terang/gelap, datar). Nilai awal `#1F6F5C`/`#145244` diubah atas keputusan Taufik supaya samar (rasio bidang 1,12 Light, 1,16 Dark; onHeroAccent di atasnya 4,6:1 Light, 6,5:1 Dark) |
| `color/ext/onHero` | `#F8F7F3` | `#F1F2EF` | Teks di atas hero (7.5:1) |
| `color/ext/onHeroAccent` | `#EBCB8B` | `#EBCB8B` | Angka/aksen emas di atas hero (5.2:1, lolos teks kecil) |
| `color/ext/iconAccent` | `#8A6A3E` | `#D9BE92` | Ikon garis emas di kartu terang (5.0:1 di atas putih) |
| `color/surfaceContainerLowest` | `#FFFFFF` | `#0A0F0D` | Kartu terang di atas latar `surface` krem |
| `space/36` | 36 | 36 | Ukuran `OrnamentBadge` |
| `type/arabicHero` | LPMQ 40 / 56 | LPMQ 40 / 56 | Nama surah Arab besar di `SurahHeaderCard` (mode `UJI130`: 52 / 72,8) |

Kartu konten (daftar surah, ayat, harian) pindah dari `surfaceContainerLow` ke `surfaceContainerLowest`, dengan border `outlineVariant` 1 px dan radius `lg` (16).

## 4. Perubahan komponen

1. **`OrnamentBadge` (baru, menggantikan `AyahNumberBadge`)**: bingkai bintang delapan bergaris tipis warna `iconAccent`, berisi angka. Dipakai di `SurahListItem` (angka Latin) dan di nomor ayat (`AyahCard`). Ukuran 36 (`space/36`); versi 28 tidak dibuat karena penanda akhir ayat memakai simbol ۝ dari teks.
2. **`SurahListItem`**: kiri `OrnamentBadge`, tengah nama Latin (titleMedium) + "Arti · [Q4] · N ayat", kanan **nama surah Arab** dengan LPMQ (`type/arabicTitle`, warna `iconAccent`). Teks Arab nama surah diambil dari field `name` di data, bukan diketik.
3. **`SurahHeaderCard`** jadi kartu `ext/hero`:
   - kiri: daftar info (Nama, Arti, Jumlah ayat, Tempat turun [Q4]) dengan label `onHero` dan nilai `onHeroAccent`
   - kanan: nama surah Arab besar (LPMQ, sekitar 40)
   - **Bismillah dalam kartu terang terpisah** di bawahnya, teksnya disalin dari data (Al-Fatihah ayat 1)
4. **`AyahCard`**:
   - nomor ayat kecil warna `iconAccent` di kiri atas, menu ⋯ di kanan atas
   - teks Arab rata kanan, diakhiri **penanda akhir ayat** (simbol ۝ U+06DD + angka Arab-Indik, LPMQ mendukungnya; di desain U+06DD didahului U+00A0 agar tidak putus baris)
   - terjemahan, garis pemisah `outlineVariant`, lalu **bilah aksi berupa 5 tombol sama lebar** dengan latar `surfaceContainerLow` dan radius `md`: salin, bookmark, putar, bagikan, tafsir. Tombol putar disembunyikan saat audio mati (aturan lama tetap berlaku).
5. **Ikon**: semua ikon fungsi memakai Material Symbols Rounded weight 300 warna `iconAccent` di kartu terang, dan `onHero` di hero. Ikon navigasi bawah tetap `onSurfaceVariant`/`primary`.
6. **Tab** (Surah/Juz/Bookmark): garis bawah `primary` 2 px pada tab aktif, label `primary`.

## 5. Beranda baru

Urutan dari atas:

1. **Hero full-bleed `ext/hero`** (sekitar 360 tinggi, termasuk status bar):
   - baris atas: lokasi (chip transparan dengan ikon pin) dan ikon cari
   - tanggal Hijriah (contoh), **jam sekarang besar** (displaySmall atau lebih, `onHero`), lalu "Maghrib dalam **27 menit**" dengan angka `onHeroAccent`
   - **baris 6 waktu** (Subuh, Terbit, Dzuhur, Ashar, Maghrib, Isya): ikon, nama, dan jam. Waktu berikutnya ditandai `onHeroAccent` **plus garis bawah atau titik** (tidak hanya warna)
   - di latar hero: **siluet datar** kubah dan menara satu nada (`heroShape`), rendah dan tipis, tanpa gradasi atau detail realistis. Siluet tidak boleh menurunkan kontras teks di atasnya
   - label "perkiraan" tetap muncul saat jadwal dari perhitungan offline
2. **Lembar konten** yang menumpuk 24 px di atas hero dengan sudut atas melengkung (radius `xl`), latar `surface`.
3. Di dalam lembar: `LastReadCard` (kartu terang, nama surah Arab kecil di kanan), `DailyCard` Ayat, lalu `DailyCard` Hadis. Ornamen bintang tipis tetap hanya di DailyCard Ayat.
4. Bottom nav tetap 4 item.

`NextPrayerCard` yang lama tidak dipakai lagi di Beranda karena fungsinya diambil alih hero. Komponennya tetap disimpan untuk layar Jadwal Sholat di putaran 2.

## 6. Layar yang diperbarui

- F1/05 Beranda: dibuat ulang sesuai bagian 5.
- F2/06 Daftar Al-Qur'an, F2/07 Baca Surah, F2/08 Tafsir, F2/10 Pencarian, F2/11 Bookmark: dirakit ulang dari komponen yang diperbarui.
- F1/03 Onboarding dan F1/04 Error: hanya ikon dan warna kartu yang ikut berubah lewat komponen. Tata letaknya tidak diubah.
- DailyWidget: ikut bahasa visual baru (kartu terang, nama surah Arab, `iconAccent`).

## 7. Aturan yang tetap berlaku

Semua aturan di CLAUDE.md tetap berlaku: teks Arab dari data dengan `\u` dan verifikasi byte, placeholder [Q4], binding variable 100%, Light + Dark, cek halaman/dokumen aktif, simpan per batch, dan berhenti setelah timeout dua kali.
