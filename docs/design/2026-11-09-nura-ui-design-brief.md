# Brief Desain UI Nura — Putaran 1 (Fondasi + Fase 1–2)

Tanggal: 9 November 2026 · Pemilik: Taufik Hidayat
Lokasi di repo: `docs/design/2026-11-09-nura-ui-design-brief.md`
Dokumen terkait: `docs/PRD.md`, `docs/specs/2026-11-09-nura-v1-design.md`, `docs/STATUS.md`, `AGENTS.md`

Brief ini jadi acuan Claude Code saat mendesain di Figma lewat FigCraft. Kalau ada yang bertentangan dengan PRD, ikuti PRD dan catat perbedaannya di bagian "Catatan terbuka".

---

## 1. Tujuan dan prinsip

Nura adalah aplikasi Islami offline-first untuk dibaca lama setiap hari: Al-Qur'an, hadis, dan jadwal sholat. Desainnya harus terasa **tenang dan modern**: bersih, lega, teduh, dan bisa dibaca dengan nyaman.

Prinsip:

1. **Teks dulu.** Teks Arab dan terjemahan selalu jadi elemen paling penting di layar baca. Ornamen tidak boleh mengganggu.
2. **Tenang.** Satu warna aksen utama, banyak ruang kosong, bayangan tipis atau tidak ada sama sekali.
3. **Ornamen Islami secukupnya.** Pola geometris tipis (opacity rendah) hanya di area dekoratif seperti header Beranda, kartu harian, dan onboarding. Jangan dipakai di area baca.
4. **Jujur soal offline/online.** Fitur yang butuh internet (audio, sinkron jadwal) punya status visual yang jelas: mati, sedang mengunduh, tersimpan offline.
5. **Siap dark mode sejak awal.** Semua warna diambil dari variables dengan mode Light dan Dark.

## 2. Target perangkat dan frame

| Frame | Ukuran | Kegunaan |
|---|---|---|
| Android Compact | 360 × 800 | Frame utama semua layar |
| Android Large | 412 × 915 | Cek ulang Beranda dan Baca Surah |

- Sertakan status bar (24) dan gesture nav bar (24) sebagai komponen placeholder.
- Bahasa UI: Bahasa Indonesia.
- Teks Arab ditata RTL (rata kanan).

## 3. Design tokens (Figma Variables)

Buat empat koleksi variables: `color`, `type`, `space`, `radius`. Koleksi `color` punya dua mode, **Light** dan **Dark**. Nama variabel mengikuti peran `ColorScheme` Material 3 supaya pemetaan ke Flutter 1:1.

### 3.1 Warna

Nilai di bawah adalah titik awal dan sudah dicek kontrasnya: pasangan teks utama di atas `surface`/`surfaceContainer` minimal 4.8:1 di kedua mode. Claude Code boleh menyetelnya selama tetap lolos kontras (bagian 8).

| Variabel | Light | Dark | Dipakai untuk |
|---|---|---|---|
| `color/primary` | `#1F6F5C` | `#7FC8B2` | Aksi utama, tab aktif, ikon aktif |
| `color/onPrimary` | `#FFFFFF` | `#00382C` | Teks/ikon di atas primary |
| `color/primaryContainer` | `#D3EEE5` | `#0F4F41` | Kartu sorotan, chip terpilih |
| `color/onPrimaryContainer` | `#00201A` | `#C9EDE1` | Teks di atas primaryContainer |
| `color/secondary` | `#7D6038` | `#D9BE92` | Aksen emas lembut: nomor ayat, ornamen |
| `color/surface` | `#F8F7F3` | `#0F1513` | Latar layar |
| `color/surfaceContainerLow` | `#F1F0EB` | `#161D1B` | Kartu biasa |
| `color/surfaceContainer` | `#EBEAE4` | `#1B2220` | Bottom sheet, nav bar |
| `color/onSurface` | `#1A1C1B` | `#E2E4E1` | Teks utama |
| `color/onSurfaceVariant` | `#55605C` | `#A9B3AF` | Teks sekunder, label |
| `color/outlineVariant` | `#C4CAC6` | `#3A4441` | Garis pemisah dan border dekoratif (bukan batas komponen interaktif) |
| `color/outline` | `#7A8580` | `#6B7672` | Batas komponen interaktif: SearchField, Chip, Button outlined, Toggle off. Kontras ≥3:1 di atas `surface`, `surfaceContainerLow`, dan `surfaceContainer` di kedua mode (Light 3.17–3.57, Dark 3.44–3.92) |
| `color/scrim` | `#000000` @ 32% | `#000000` @ 32% | Scrim di belakang bottom sheet (`ColorScheme.scrim`) |
| `color/error` | `#B3261E` | `#F2B8B5` | Error |
| `color/onError` | `#FFFFFF` | `#601410` | Teks di atas error |

Warna tambahan (nanti jadi `ThemeExtension` di Flutter, bukan bagian `ColorScheme`):

| Variabel | Light | Dark | Dipakai untuk |
|---|---|---|---|
| `color/ext/arabicText` | `#121413` | `#F1F2EF` | Teks Arab (sedikit lebih kontras dari onSurface) |
| `color/ext/lastReadHighlight` | `#FFF4DE` | `#2A2418` | Latar ayat terakhir dibaca |
| `color/ext/searchHighlight` | `#FFE3A3` | `#5A4A1E` | Sorotan kata hasil pencarian |
| `color/ext/ornament` | `#1F6F5C` @ 8% | `#7FC8B2` @ 6% | Pola geometris dekoratif |
| `color/ext/offlineBadge` | `#2B7430` | `#81C784` | Lencana "tersimpan offline" (Light digelapkan dari `#2E7D32` agar ≥4.5:1 di atas `surfaceContainerLow`) |

### 3.2 Tipografi

- **Latin:** Plus Jakarta Sans (lisensi OFL).
- **Arab:** LPMQ Isep Misbah, font standar mushaf Kemenag. Cadangan: KFGQPC Uthmanic Script Hafs. **Lisensi kedua font wajib dicek sebelum rilis** (tambahkan ke daftar Q6).

| Variabel / style | Font | Ukuran / tinggi baris | Berat |
|---|---|---|---|
| `type/displaySmall` | Jakarta | 32 / 40 | 600 |
| `type/headlineSmall` | Jakarta | 24 / 32 | 600 |
| `type/titleLarge` | Jakarta | 20 / 28 | 600 |
| `type/titleMedium` | Jakarta | 16 / 24 | 600 |
| `type/bodyLarge` | Jakarta | 16 / 26 | 400 |
| `type/bodyMedium` | Jakarta | 14 / 22 | 400 |
| `type/labelLarge` | Jakarta | 14 / 20 | 600 |
| `type/labelMedium` | Jakarta | 12 / 16 | 500 |
| `type/arabicReading` | LPMQ | 28 / 56 | 400 |
| `type/arabicCard` | LPMQ | 22 / 44 | 400 |
| `type/arabicTitle` | LPMQ | 24 / 36 | 400 |
| `type/translation` | Jakarta | 15 / 24 | 400 |

Ukuran teks Arab nantinya bisa diatur pengguna (20–40). Desain default memakai 28. Buat satu varian contoh di 36 untuk mengecek tata letak saat teks membesar.

### 3.3 Jarak dan radius

- `space/*`: grid 4 pt → 4, 8, 12, 16, 20, 24, 32, 40, 48.
- Padding layar horizontal: 20. Jarak antarkartu: 12.
- `radius/*`: sm 8, md 12, lg 16, xl 24, full 999.
- Elevasi: tanpa drop shadow. Kedalaman dibangun dari tingkatan `surfaceContainer*` dan border `outlineVariant` tipis.
- Target sentuh minimal 48 × 48.

#### Ukuran komponen/platform tetap (dikecualikan dari aturan token)

Ukuran komponen/platform tetap berikut berupa angka literal di Figma, tidak terikat variable, karena merupakan ukuran bawaan komponen atau elemen dekoratif. Tidak diekspor ke Flutter kecuali ada kebutuhan. Ukuran yang sudah terikat token (badge nomor 40 = `space/40`, ikon 24 = `space/24`, area sentuh dan tinggi minimum Button/SearchField 48 = `space/48`) bukan pengecualian.

| Elemen | Ukuran |
|---|---|
| Bintang ornamen | 18 × 18 |
| Ikon / ilustrasi bulat (onboarding, error) | 96 × 96 |
| Ring (onboarding jadwal) | 12 × 12 |
| Ilustrasi placeholder | tinggi 200 |
| Pegangan sheet | 32 × 4 |
| Track slider | tinggi 4 |
| Indikator tab | tinggi 4 |
| Isi progress | tinggi 8 |
| Tinggi baris daftar tetap (frame "Baris") | 64, 65, 68, 108, 130 (menurut isi baris) |
| Status bar placeholder | 360 × 24 |
| Gesture navigation | tinggi 24 |
| Scrim dan Overlay sheet | 360 × 800 (ukuran frame layar) |
| Wadah lebar layar | 392 |
| Pola bintang dekoratif | 320 × 300 dan 320 × 96 |
| Jarum jam (onboarding jadwal) | 12 × 12 |
| Pemisah | tinggi 1 |
| Lebar kartu DailyCard | 320 |
| Lebar bottom sheet | 360 |
| Tinggi maksimum bottom sheet | 720 (90% dari tinggi layar 800) |
| Bintang ornamen DailyCard/widget | 120 × 120 dan 90 × 90 |
| Isi progress dan slider | lebar 129 dan 288 (mengikuti nilai contoh) |
| Lebar varian Button di lembar komponen | 86, 88, 118, 120 (instans di layar hug) |
| Lebar SurahHeaderCard | 360 (di layar fill) |

### 3.4 Opacity (keadaan disabled, mengikuti Material 3)

Koleksi `opacity` (satu mode) dan dua warna turunan di koleksi `color`:

| Variabel | Nilai | Dipakai untuk |
|---|---|---|
| `opacity/disabledContent` | `0.38` | Konten disabled (teks, ikon) |
| `opacity/disabledContainer` | `0.12` | Latar dan border disabled |
| `color/disabledContent` | `onSurface` @ `opacity/disabledContent` (Light dan Dark) | Teks/ikon disabled |
| `color/disabledContainer` | `onSurface` @ `opacity/disabledContainer` (Light dan Dark) | Latar disabled (filled, tonal), border disabled (outlined), track toggle/slider nonaktif |

Aturan: elemen disabled tidak memakai opacity pada layer; warnanya diganti ke `color/disabledContent` atau `color/disabledContainer`. Catatan teknis: FigCraft tidak bisa mengikat opacity warna ke variabel angka, jadi nilai alpha `0.38` dan `0.12` ditulis ulang di dua variabel warna turunan dan harus tetap sama dengan koleksi `opacity`.

## 4. Komponen

Semua komponen memakai auto layout dan variables. Tidak boleh ada nilai warna, ukuran teks, atau jarak yang di-hardcode.

Aturan pemakaian garis:

- `color/outline` untuk batas komponen interaktif: `SearchField`, `Chip` (tidak terpilih), `Button` outlined, dan `Toggle` dalam keadaan off.
- `color/outlineVariant` untuk garis pemisah dan border dekoratif: pemisah daftar, border kartu, handle `BottomSheet`.
- Jangan memakai `outlineVariant` sebagai satu-satunya penanda batas komponen yang bisa disentuh (kontrasnya di bawah 3:1).

| Komponen | Varian / properti |
|---|---|
| `TopAppBar` | default, dengan aksi (cari, menu), dengan subjudul (mis. "Al-Baqarah · 286 ayat") |
| `BottomNav` | 4 item: Beranda, Al-Qur'an, Hadis, Sholat · aktif/tidak |
| `Button` | filled, tonal, outlined, text · default/disabled · dengan/tanpa ikon |
| `Chip` | filter · terpilih/tidak |
| `SearchField` | kosong, terisi, dengan tombol hapus |
| `SurahListItem` | nomor (bingkai ornamen), nama Latin, arti, jumlah ayat, Makkiyah/Madaniyah, nama Arab · default/bookmarked/terakhir dibaca |
| `JuzListItem` | nomor juz, rentang surah:ayat |
| `AyahNumberBadge` | angka 1–3 digit |
| `AyahCard` | Arab + terjemahan · default/lastRead/bookmarked/lastRead+bookmarked · terjemahan tampil/tersembunyi · baris aksi. lastRead = latar `lastReadHighlight` + label "Terakhir dibaca" + ikon history (Material Symbols Rounded). Bookmarked = ikon bookmark terisi di `AyahActionBar` saja (tanpa ikon kecil di dekat badge). Sorotan hasil pencarian lewat rentang teks SemiBold + garis bawah (bagian 5 layar 10), bukan varian AyahCard |
| `AyahActionBar` | bookmark, tafsir, salin, bagikan, putar audio · audio: mati (tersembunyi), siap streaming, tersimpan offline, sedang memutar |
| `BismillahHeader` | teks Basmalah; dipakai sebagai instans di dalam `SurahHeaderCard` varian Bismillah=Ya, tidak lagi berdiri sendiri di layar. At-Taubah tanpa Basmalah; Al-Fatihah tanpa (Basmalah adalah ayat 1) |
| `SurahHeaderCard` | nama Arab, Latin, arti, jumlah ayat, tempat turun · varian `Bismillah=Ya` (memuat Basmalah di dalam kartu, tinggi 158) / `Bismillah=Tidak` (94; dipakai At-Taubah dan Al-Fatihah) |
| `NextPrayerCard` | nama sholat berikutnya, jam, hitung mundur, lokasi · label "perkiraan" saat pakai perhitungan offline |
| `DailyWidget` | tipe Ayat / Hadis · 4×2 dan 4×3 cell · Light/Dark · versi teks sangat panjang untuk uji pemotongan. Satu area ketuk, tanpa tombol di dalam, radius ±24 (widget Android 12+). Lihat bagian 12 |
| `DailyNotification` | collapsed / expanded (BigText), gaya notifikasi Android standar, ikon kecil aplikasi (placeholder), tanpa teks Arab. Lihat bagian 12 |
| `DailyCard` | tipe Ayat / Hadis (**pratinjau widget**, bahasa visual sama dengan `DailyWidget`) · aksi bagikan. **Ayat:** kartu menonjol dengan ornamen tipis di latar, Arab `arabicCard`, terjemahan, sumber (mis. "QS. Asy-Syarh: 6"). **Hadis:** kartu biasa yang lebih sederhana, hanya **matan** Arab (di atas) dan terjemahan matan (teks di dalam tanda kutip setelah "bersabda:", tanpa sanad), baris sumber gaya `labelLarge` (mis. "HR. Shahih Bukhari No. 34") dan tautan "Baca selengkapnya" ke hadis lengkap dengan sanad (layar detail masuk putaran 2). Tanpa batas baris untuk matan |
| `LastReadCard` | surah:ayat, tombol lanjutkan |
| `BottomSheet` | handle, judul, isi bergulir |
| `Toggle` / `Slider` / `ListTile` | untuk pengaturan |
| `ProgressBlock` | progres instalasi konten (persen + label) |
| `EmptyState` | ilustrasi tipis, judul, deskripsi, aksi |
| `ErrorState` | ikon, judul, deskripsi, aksi utama/sekunder |
| `Snackbar` | info, error |

## 5. Layar putaran 1

### Fase 1 — Fondasi (sejalan dengan Task 8–10)

1. **Splash.** Logo/wordmark Nura di atas `surface`, ornamen tipis.
2. **Menyiapkan konten (Task 8).** Muncul saat `content.db` disalin dari APK ke penyimpanan. `ProgressBlock` dengan teks "Menyiapkan Al-Qur'an dan hadis untuk dibaca offline…", ditambah catatan bahwa proses ini hanya sekali.
3. **Onboarding (Task 10)**, 3 langkah:
   - a. Sambutan: apa isi Nura, semuanya bisa dipakai offline.
   - b. Jadwal sholat: pilih kota, minta **izin sinkron online terpisah**. Jelaskan bahwa tanpa izin ini jadwal tetap ada lewat perhitungan offline berlabel "perkiraan".
   - c. Notifikasi: izin notifikasi Android, dengan dua sakelar: "Pengingat adzan" dan "Ayat & hadis harian" (jam default 06.00, bisa diubah). Bisa dilewati.
   - Audio murottal **tidak** ditanyakan di onboarding karena mati secara default. Cukup disebut bahwa audio bisa diaktifkan di Pengaturan.
4. **Layar error (Task 10):**
   - Ruang penyimpanan tidak cukup. Tampilkan perkiraan ruang yang dibutuhkan; ukuran akhir mengikuti hasil pengukuran Task 7.
   - Instalasi konten gagal/rusak, dengan tombol "Coba lagi".
   - Error tak terduga (fallback umum).
5. **Beranda.** Urutan: header dengan salam + tanggal Hijriah/Masehi dan ikon cari → `NextPrayerCard` (kartu utama: isi `primaryContainer`, jam `displaySmall`, tanpa border) → `LastReadCard` (ringkas satu baris: surah:ayat + tombol Lanjutkan, area sentuh 48) → `DailyCard` Ayat (menonjol) → `DailyCard` Hadis (sederhana). Dilengkapi `BottomNav`. `QuickMenuItem` dihapus dari putaran ini (menduplikasi `BottomNav`). Ornamen header/kartu ayat: pola bintang delapan kecil berulang memakai `color/ext/ornament`.

### Fase 2 — Al-Qur'an offline

6. **Daftar Al-Qur'an.** Tab Surah / Juz / Bookmark dan `SearchField`. Tab Juz bergantung pada Q4 (sumber `juz.json`), jadi didesain dengan data contoh.
7. **Baca Surah.** `SurahHeaderCard` (varian Bismillah=Ya, Basmalah di dalam kartu; At-Taubah/Al-Fatihah memakai Bismillah=Tidak) → daftar `AyahCard`. Satu ayat ditampilkan dalam keadaan `lastRead`. App bar menampilkan nama surah dan pengaturan tampilan.
8. **Tafsir (bottom sheet).** Tafsir Kemenag untuk satu ayat. Teksnya panjang dan bisa digulir; ada navigasi ayat berlabel "Sebelumnya" dan "Berikutnya" (Button Text berikon panah kiri/kanan; baris wrap bila tidak muat di Latin 130%). Sheet menempel di bawah (Overlay layout vertikal rata bawah).
9. **Pengaturan tampilan baca (bottom sheet).** Slider ukuran teks Arab dengan pratinjau langsung, sakelar tampilkan terjemahan, dan pilihan tema (Sistem/Terang/Gelap). Tinggi sheet maksimum 90% layar (720 dari 800); isi yang melebihi digulir/dipotong, pegangan dan judul tetap terlihat. Frame F2/09b menampilkan seluruh isi tanpa terpotong (tinggi hug).
10. **Pencarian Al-Qur'an.** Hasil dikelompokkan per surah, kata cocok disorot dengan `searchHighlight`, pencarian di teks Arab maupun terjemahan. Sertakan keadaan kosong ("Tidak ada hasil").
    - **Aturan cuplikan hasil (juga spesifikasi implementasi Flutter).** Satu node teks `Terjemahan` per hasil, maksimal 3 baris. Cuplikan berpusat pada kemunculan pertama kata cocok: jendela maksimal 100 karakter, digeser agar tidak melewati awal/akhir teks, lalu dipotong ke batas kata (spasi terdekat) tanpa memotong kata cocok. Elipsis "…" ditambahkan di depan bila awal dipotong dan di belakang bila akhir dipotong. Isi cuplikan (tanpa elipsis) harus substring persis dari terjemahan; tanda baca tetap menempel pada kata. Semua kemunculan kata cocok di dalam cuplikan disorot. Teks lebih pendek dari 100 karakter ditampilkan utuh. Pencarian tidak peka huruf besar/kecil; kata cocok = substring.
    - **Sorotan.** Target Flutter: `TextSpan` dengan `backgroundColor: searchHighlight` pada rentang kata cocok. Di Figma gaya per rentang teks hanya mendukung teks (bobot, dekorasi, warna isi) dan tidak mendukung latar rentang maupun variable pada warna rentang. Karena itu mockup memakai rentang SemiBold + garis bawah pada kata cocok; warna `searchHighlight` tetap di token dan dipakai di Flutter.
    - **Kasus uji di mockup:** Al-Baqarah 45 (kata di tengah, elipsis belakang), Al-Baqarah 153 (elipsis depan dan belakang), Ali 'Imran 146 (kata di akhir ayat, elipsis depan), An-Nahl 42 (ayat pendek, tanpa elipsis).
11. **Bookmark.** Daftar ayat yang disimpan, ditambah empty state.

Setiap layar dibuat dalam **Light dan Dark**. Untuk layar daftar, tambahkan keadaan kosong/memuat bila relevan.

## 6. Konten contoh: aturan integritas

Teks Al-Qur'an dan hadis tidak boleh salah, bahkan di mockup sekalipun.

- **Jangan mengetik teks Arab dari ingatan model.** Ambil teks Arab, terjemahan, dan tafsir contoh langsung dari file di `data-source/` (misalnya Al-Fatihah 1–7 dan Al-Baqarah 1–5), salin apa adanya.
- Untuk hadis contoh, ambil satu hadis dari `data-source/` dan sertakan nama kitab beserta nomornya. Contoh Beranda: Shahih Bukhari No. 34. Kartu harian menampilkan **matan** hasil ekstraksi, yaitu substring persis dari terjemahan di data (teks di dalam tanda kutip setelah "bersabda:"), diverifikasi byte demi byte. Matan Arab diambil sebagai substring persis dari teks Arab (untuk Bukhari No. 34 dimulai dari "مَنْ يَقُمْ" sampai akhir) dan ditampilkan dengan `type/arabicCard` di atas terjemahan matan. Ekstraksi matan berlaku untuk Arab **dan** terjemahan, dan keduanya harus bisa diekstrak bersih agar sebuah hadis lolos seleksi hadis harian. Data tidak punya field matan terpisah; ekstraksi ini hanya di desain.
- Nama surah, arti, dan jumlah ayat juga diambil dari data, bukan dikarang.
- Jam sholat di mockup boleh contoh, tapi diberi label "contoh" di nama layer.

## 7. Konvensi file Figma

- Nama file: `Nura — UI v1`
- Halaman: `00 Cover`, `01 Foundations`, `02 Components`, `03 Screens · Fase 1`, `04 Screens · Fase 2`, `99 Playground`
- Nama frame: `F1/05 Beranda — Light`, `F2/07 Baca Surah — Dark`, dan seterusnya.
- Nama layer bermakna (`AyahCard/Arabic`, bukan `Frame 123`).
- Eksperimen dan versi yang ditolak dipindah ke `99 Playground`, tidak dihapus.

## 8. Aksesibilitas (wajib lolos)

- Kontras teks normal minimal 4.5:1 dan teks besar/ikon minimal 3:1, di Light dan Dark.
- Target sentuh minimal 48 × 48.
- Status tidak boleh dibedakan dengan warna saja: bookmark, offline, dan "perkiraan" selalu disertai ikon atau teks.
- Tata letak tetap utuh saat teks Arab 36 dan teks Latin diperbesar 130%.

## 9. Pemetaan ke Flutter (untuk Task 10)

| Figma | Flutter |
|---|---|
| `color/*` (Light/Dark) | `ColorScheme.light(...)` / `ColorScheme.dark(...)` (`color/scrim` → `ColorScheme.scrim`, dipakai `showModalBottomSheet(barrierColor: colorScheme.scrim.withValues(alpha: 0.32))`; nilai alpha ada di token) |
| `color/ext/*` | `NuraColors extends ThemeExtension` |
| `type/*` Latin | `TextTheme` |
| `type/arabic*`, `type/translation` | `NuraTextStyles extends ThemeExtension` |
| `space/*`, `radius/*` | konstanta di `lib/core/theme/tokens.dart` |

Pemetaan disabled: ikuti default Material 3. `opacity/disabledContent` = `onSurface.withValues(alpha: 0.38)` (teks/ikon) dan `opacity/disabledContainer` = `onSurface.withValues(alpha: 0.12)` (latar/border). Di Flutter keduanya cukup memakai default `ThemeData` M3; tidak perlu `ThemeExtension` kecuali ingin menimpa.

Setelah token disetujui, ekspor ke `docs/design/tokens.json` sebagai satu-satunya sumber nilai yang dibaca saat menulis tema Flutter.

## 10. Di luar putaran ini

Layar hadis (termasuk detail hadis dengan sanad lengkap), jadwal sholat bulanan, pengaturan notifikasi lengkap, pengunduhan audio, pengaturan umum, ikon aplikasi final, dan materi Play Store. Semua ini masuk putaran 2 dengan memakai komponen dari putaran ini.

## 11. Catatan terbuka

- Lisensi font Arab (LPMQ Isep Misbah / KFGQPC) → masuk daftar Q6.
- Tab Juz bergantung pada Q4.
- Nama "Nura" belum lolos Q2. Wordmark di putaran ini masih sementara.
- Jam default notifikasi harian 06.00 adalah asumsi, belum diputuskan produk.
- Aturan seleksi hadis harian (matan Arab dan terjemahan harus bisa diekstrak bersih, batas karakter N, pembatasan ke Bukhari/Muslim) masuk Fase 6.

## 12. Keputusan produk: 1 Hari 1 Ayat/Hadis (tiga tempat)

Ditetapkan 9 November 2026.

- **A.** Ayat/hadis harian tampil di **tiga tempat**: kartu Beranda, widget layar depan Android, dan notifikasi harian.
- **B.** Kartu Beranda dan widget memakai bahasa visual yang sama. `DailyCard` adalah "pratinjau widget".
- **C. Widget** (dikerjakan di Langkah 3b bersama `DailyCard`, bukan putaran 2):
  - Dua widget: "Ayat hari ini" dan "Hadis hari ini". Ukuran 4×2 dan 4×3 cell, Light dan Dark.
  - Dirender sebagai gambar dari Flutter (font LPMQ tidak bisa dipakai di RemoteViews), jadi komposisinya statis: tanpa tombol di dalam; seluruh widget adalah satu area ketuk.
  - Isi: label, matan Arab, terjemahan (dipotong rapi dengan elipsis bila perlu), dan rujukan.
  - Radius mengikuti widget Android 12+ (±24). Sediakan juga versi dengan teks sangat panjang untuk menguji pemotongan.
- **D. Notifikasi harian:**
  - Satu notifikasi per hari pada jam tetap yang bisa diatur atau dimatikan. Default 06.00 (asumsi).
  - Notifikasi tidak bisa memakai font custom, jadi isinya **terjemahan dan rujukan saja, tanpa teks Arab**.
  - Mockup collapsed dan expanded (BigText) dengan gaya notifikasi Android standar, plus ikon kecil aplikasi (placeholder).
  - Ketuk notifikasi membuka Beranda dengan kartu harian.
- **E.** Onboarding langkah c ("Notifikasi") memuat dua sakelar: "Pengingat adzan" dan "Ayat & hadis harian" (jam default bisa diubah).

Catatan teknis: widget dirender sebagai gambar (mis. paket `home_widget`); notifikasi tanpa teks Arab.

### Catatan implementasi widget (3b)

Ukuran widget di desain adalah perkiraan (4×2 ≈ 320×152, 4×3 ≈ 320×240, radius 24). Ukuran sebenarnya bergantung launcher; Flutter merender gambar sesuai ukuran widget yang diminta Android. Teks Arab dan terjemahan yang melebihi ruang dipotong dengan elipsis (Arab 1 baris di 4×2 dan 2 baris di 4×3; terjemahan 1 dan 3 baris).
