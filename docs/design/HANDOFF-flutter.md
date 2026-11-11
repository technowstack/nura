# Handoff desain Nura ke Flutter (putaran 1)

Tanggal: 2026-11-11. Sumber kebenaran desain: `2026-11-09-nura-ui-design-brief.md`. File Figma: `Nura — UI v1.figcraft` (folder ini). Nilai token: `tokens.json` (sumber), `tokens.dart` (referensi saja). Bahasa UI aplikasi: Indonesia.

## 1. Berkas

| Berkas | Isi |
|---|---|
| `tokens.json` | Semua variables (koleksi `color` Light/Dark, `space`, `radius`, `type`, `opacity`), format JSON FigCraft. Mode `UJI130` sengaja dibuang. Sumber nilai saat menulis tema. |
| `tokens.dart` | Ekspor Dart FigCraft sebagai referensi (konstanta per koleksi/mode). Nama kelas hasil ekspor bentrok dengan nama Flutter (`Color_`, `Type`, `Opacity`, `Radius`); jangan dipakai langsung. Salin nilai ke `tokens.dart` aplikasi di `lib/core/theme/` dengan nama sendiri. |
| `review-round1.md` | Hasil review dan semua keputusan per butir. |
| `CLAUDE.md`, `STATUS-desain.md` | Aturan kerja dan catatan progres desain. |

## 2. Pemetaan token (brief bagian 9)

| Figma | Flutter |
|---|---|
| `color/*` (Light, Dark) | `ColorScheme.light(...)` dan `ColorScheme.dark(...)`: primary, onPrimary, primaryContainer, onPrimaryContainer, secondary, surface, surfaceContainerLow, surfaceContainer, onSurface, onSurfaceVariant, outline, outlineVariant, error, onError, scrim |
| `color/scrim` | `ColorScheme.scrim`. Pakai `showModalBottomSheet(barrierColor: colorScheme.scrim.withValues(alpha: 0.32))`. Nilai token `#000000` alpha 32% sama di Light dan Dark. |
| `color/ext/*` (arabicText, lastReadHighlight, searchHighlight, ornament, offlineBadge) | `NuraColors extends ThemeExtension<NuraColors>` |
| `type/*` Latin (displaySmall ... labelMedium, translation) | `TextTheme`. Font `Plus Jakarta Sans`. Ukuran/tinggi baris/berat dari `tokens.json` (tinggi baris Flutter = lineHeight / ukuran). |
| `type/arabicReading`, `arabicCard`, `arabicTitle`, `arabicReading36` | `NuraTextStyles extends ThemeExtension<NuraTextStyles>`. Font `LPMQ Isep Misbah`. |
| `space/*` (4, 8, 12, 16, 20, 24, 32, 40, 48), `radius/*` (sm 8, md 12, lg 16, xl 24, full 999) | Konstanta di `lib/core/theme/tokens.dart` |
| `opacity/disabledContent` 0.38, `opacity/disabledContainer` 0.12 | Default `ThemeData` Material 3 (`onSurface.withValues(alpha: 0.38)` untuk teks/ikon, `0.12` untuk latar/border). Tidak perlu ThemeExtension. |
| `color/outline` | Batas komponen interaktif (SearchField, Chip, Button outlined, Toggle off). `outlineVariant` hanya untuk pemisah/dekoratif. |

Ukuran Arab bisa diatur pengguna (20–40); desain default 28 dan ada contoh 36. Padding layar horizontal 20, jarak antarkartu 12, tanpa drop shadow.

## 3. Komponen, varian, dan keadaan

Properti dan nilai (nama set Figma, id sesuai file pada 2026-11-11):

| Komponen | Properti varian |
|---|---|
| Button | Type: Filled/Tonal/Outlined/Text · State: Default/Disabled · Icon: Off/On |
| Chip | Selected: Off/On (terpilih = centang + latar) |
| SearchField | State: Kosong/Terisi/Terisi dengan hapus |
| Toggle | Value: Off/On · State: Enabled/Disabled |
| Slider | State: Default/Disabled |
| TopAppBar | Type: Default/Aksi/Subjudul/Subjudul + Aksi |
| BottomNav | Active: Beranda/Al-Qur'an/Hadis/Sholat |
| Tab | Active: Surah/Juz/Bookmark |
| ListTile | Divider: Off/On |
| Snackbar | Type: Info/Error |
| ProgressBlock | Progress: 0/45/100 |
| BottomSheet | handle, judul, deskripsi, slot isi (layer "Slot isi", properti slot "Isi tambahan", isi bebas) |
| EmptyState, ErrorState | tunggal (judul, deskripsi, tombol) |
| NextPrayerCard, LastReadCard | tunggal (LastReadCard memakai ikon `history`) |
| DailyCard | Type: Ayat/Hadis (pratinjau widget) |
| DailyWidget (Light dan Dark) | Type: Ayat/Hadis · Size: 4x2/4x3 · Isi: Normal/Panjang |
| DailyNotification (Light dan Dark) | Type: Ayat/Hadis · State: Collapsed/Expanded |
| SurahHeaderCard | Bismillah: Ya/Tidak (Tidak untuk At-Taubah dan Al-Fatihah) |
| BismillahHeader | tunggal (dipakai di dalam SurahHeaderCard varian Ya) |
| SurahListItem | State: Default/Bookmarked/Terakhir dibaca (Terakhir dibaca = latar `lastReadHighlight` + ikon `history`; Bookmarked = ikon bookmark) |
| JuzListItem | tunggal (placeholder Q4) |
| AyahNumberBadge | Digits: 1/2/3 |
| AyahActionBar | Audio: Mati/Siap streaming/Tersimpan offline/Sedang memutar × Bookmark: Tidak/Ya (Ya = ikon terisi `primary`) |
| AyahCard | State: Default/Terakhir dibaca/Bookmarked/Terakhir dibaca + Bookmarked × Terjemahan: Tampil/Tersembunyi × Arab: 28/36 (36 hanya Default + Tampil) |

Keadaan AyahCard:
- **Terakhir dibaca:** latar `lastReadHighlight`, label "Terakhir dibaca" (labelMedium) + ikon `history` di baris tipis 24 di atas baris badge/aksi.
- **Bookmarked:** ikon bookmark terisi di AyahActionBar (tidak ada ikon kecil tambahan).
- **Tata letak:** badge nomor kiri dan AyahActionBar kanan dalam satu baris; di bawahnya teks Arab, lalu terjemahan, sesuai urutan di Figma. Tombol audio turun ke baris kedua bila tidak muat (wrap).

Layar (Figma): halaman `03 Screens · Fase 1` (9 layar Light+Dark) dan `04 Screens · Fase 2` (16 layar Light+Dark: 06a/b/c, 07a/b/c/d, 08a/b, 09a/b, 10a/b/c, 11a/b). Frame bernama `F1/xx`/`F2/xx`; variasi tinggi penuh dan Arab 36 ada sebagai frame terpisah.

## 4. Aturan teknis

### Pencarian Al-Qur'an (brief bagian 5, layar 10)
- Satu `Text.rich` per hasil untuk terjemahan, maksimal 3 baris.
- Cuplikan berpusat pada kemunculan pertama kata cocok: jendela maksimal 100 karakter, digeser agar tidak melewati awal/akhir teks, dipotong ke batas kata (spasi) tanpa memotong kata cocok. "…" di depan bila awal dipotong, di belakang bila akhir dipotong. Isi cuplikan (tanpa elipsis) harus substring persis terjemahan; teks < 100 karakter tampil utuh.
- Semua kemunculan kata cocok dalam cuplikan disorot. Flutter: `TextSpan(backgroundColor: searchHighlight)`. Di mockup Figma hanya SemiBold + garis bawah karena Figma tidak mendukung latar rentang; target Flutter memakai latar `searchHighlight` (kontras terhadap `onSurface` 13.68 Light / 6.75 Dark).
- Pencarian tidak peka huruf besar/kecil; kata cocok = substring. Hasil dikelompokkan per surah; pencarian di Arab dan terjemahan. Keadaan kosong: "Tidak ada hasil".
- Kasus uji: Al-Baqarah 45, Al-Baqarah 153, Ali 'Imran 146, An-Nahl 42.

### Hadis harian: ekstraksi matan
- Data tidak punya field matan. Matan Arab = substring persis dari teks Arab (Bukhari No. 34 dimulai dari "مَنْ يَقُمْ" sampai akhir). Matan terjemahan = substring persis dari terjemahan (teks di dalam tanda kutip setelah "bersabda:", tanpa sanad). Keduanya harus bisa diekstrak bersih agar sebuah hadis lolos seleksi hadis harian (aturan seleksi lengkap, batas karakter N, pembatasan ke Bukhari/Muslim: Fase 6).
- Rujukan: ayat `QS. <Nama Latin>: <ayat>` (mis. "QS. Asy-Syarh: 6"); hadis `HR. <Kitab> No. <n>` (mis. "HR. Shahih Bukhari No. 34"); nama kitab dari `hadithBookNames` di `lib/content_pipeline/content_schema.dart`.
- Kartu Hadis di Beranda memakai ukuran lebih sederhana daripada kartu Ayat; "Baca selengkapnya" menuju hadis lengkap dengan sanad (layar detail putaran 2).

### Widget layar utama dan notifikasi
- Widget dirender sebagai gambar dari Flutter (font LPMQ tidak bisa dipakai di RemoteViews, mis. paket `home_widget`). Komposisi statis, tanpa tombol; seluruh widget satu area ketuk. Isi: label, matan Arab, terjemahan (elipsis rapi), rujukan. Ukuran 4x2 dan 4x3.
- Notifikasi tanpa teks Arab (hanya terjemahan dan rujukan). Satu notifikasi per hari pada jam yang bisa diatur atau dimatikan; default 06.00 (asumsi, belum diputuskan produk).
- Onboarding langkah c: izin notifikasi dengan dua sakelar "Pengingat adzan" dan "Ayat & hadis harian".

### Keadaan disabled (Material 3)
Ikuti default M3: `opacity/disabledContent` 0.38 untuk teks/ikon, `disabledContainer` 0.12 untuk latar/border. Elemen disabled dikecualikan dari ambang kontras WCAG.

### Scrim dan bottom sheet
Scrim `ColorScheme.scrim` alpha 32%; sheet rata bawah, tinggi maksimum 90% tinggi layar (720 pada frame 800), isi bisa digulir; frame 08b/09b di Figma adalah versi tinggi penuh hanya untuk dokumentasi (Figma tidak mensimulasikan gulir).

### Ukuran dan tata letak
- Button dan SearchField: tinggi mengikuti isi dengan `minHeight` 48 (`space/48`); label Button wrap dan rata tengah. Tombol navigasi ayat (Sebelumnya/Berikutnya, Button Text + ikon panah) boleh turun baris.
- Tinggi baris daftar tetap di Figma (64/65/68/108/130) hanya mengikuti isi: di Flutter pakai tinggi mengikuti isi dengan minHeight.
- Teks keterangan SurahListItem wrap (tidak dipotong). Ukuran komponen/platform tetap lain (bintang 18, ilustrasi 96, status bar placeholder, dst.) tercatat di brief bagian 3.3 dan tidak diekspor.
- Uji Latin 130%: tata letak harus utuh saat teks Latin 130% dan Arab 36 (mode `UJI130` di koleksi type; resep di `CLAUDE.md` bagian "Uji Latin 130%").
- Target sentuh minimal 48 × 48; status tidak boleh hanya warna (lastRead = label + ikon + latar; bookmark = ikon terisi; offline = teks + centang; chip/tab punya penanda tambahan).
- Ikon "Terakhir dibaca": Material Symbols Rounded `history` (Apache 2.0). Hanya `history` yang diambil dari Material Symbols Rounded (Apache 2.0). Ikon lain masih placeholder sederhana buatan sendiri (path kasar) dan perlu diganti ikon final.

## 5. Placeholder dan catatan terbuka

| Hal | Status |
|---|---|
| **Q4** (Makkiyah/Madaniyah, juz, rentang ayat) | Slot ada di SurahListItem, SurahHeaderCard, dan tab Juz; berisi "[Q4]" dengan layer berakhiran "(menunggu Q4)". Data-source tidak punya field ini; jangan diisi dari ingatan. |
| **~XXX MB** | Layar error ruang penyimpanan: teks "~XXX MB" (layer "storage-size (isi setelah Task 7)"). Isi setelah angka Task 7 tersedia. |
| **Jam 06.00** | Jam default notifikasi harian adalah asumsi, belum diputuskan produk. |
| **Lisensi font Q6** | Plus Jakarta Sans (OFL); LPMQ Isep Misbah dan cadangan KFGQPC Uthmanic Script Hafs: lisensi wajib dicek sebelum rilis. LPMQ diambil dari sumber resmi LPMQ (lajnah.kemenag.go.id/unduhan); catat tanggal unduh di catatan rilis. |
| **Ikon dan ilustrasi** | Ikon selain `history` adalah placeholder kasar; ikon aplikasi final (brief bagian 10) dan ilustrasi EmptyState/ErrorState/onboarding (kini lingkaran/frame kosong) belum ada. |
| **Wordmark** | Splash memakai wordmark sementara (Q2). |
| **Aturan seleksi hadis harian** | Fase 6 (matan Arab dan terjemahan bisa diekstrak bersih, batas karakter N, Bukhari/Muslim). Tidak ada hadis panjang uji untuk widget "Isi=Panjang" varian Hadis. |
| **Layar detail hadis** | Belum didesain (putaran 2); "Baca selengkapnya" hanya tautan. |
| **Daftar kota** | Layar onboarding jadwal memakai 2 ListTile contoh; daftar kota lengkap dan hasil pencarian kota belum didesain. |
| **Jam sholat, kota, tanggal Hijriah** | Contoh berlabel "(contoh)". |
| **Keadaan error/tombol dua baris** | Tombol utama onboarding/error pada layar sempit: Button wrap sudah ada, tetapi varian khusus belum. |
| **Gulir sheet** | Gulir di dalam sheet tidak bisa disimulasikan di Figma; implementasi Flutter perlu memastikan isi bergulir dengan tinggi maksimum 90%. |
| **Target ayat terlihat** | Layar Baca Surah 07a menampilkan ±2,09 ayat Al-Baqarah di frame 800 (target 2,5 dilepas oleh keputusan produk; info saja). |
| **Varian sisa** | Mode `UJI130` dan 8 salinan `UJI130b` di `99 Playground` dipertahankan untuk uji ulang. |

## 6. Verifikasi yang sudah dilakukan (pengawas, 2026-11-10/11)
- Audit seluruh halaman 02, 03, 04 (+99): 0 nilai tanpa binding variable, semua teks bertext style; teks Arab (ayat, nama surah, matan hadis) cocok persis dengan `data-source/`; terjemahan, tafsir, hadis, dan cuplikan pencarian substring persis; kontras (teks ≥ 4.5:1, ikon ≥ 3:1, elemen disabled dikecualikan) dan target sentuh ≥ 48 lolos di Light dan Dark.
