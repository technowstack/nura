# Handoff desain Nura ke Flutter (putaran 1 + penyegaran visual 1.5)

Tanggal: 2026-11-11, diperbarui 2026-11-19 untuk putaran 1.5 (`2026-11-17-nura-penyegaran-visual.md`). Sumber kebenaran desain: `2026-11-09-nura-ui-design-brief.md`. File Figma: `Nura — UI v1.figcraft` (folder ini). Nilai token: `tokens.json` (sumber), `tokens.dart` (referensi saja). Bahasa UI aplikasi: Indonesia.

## 1. Berkas

| Berkas | Isi |
|---|---|
| `tokens.json` | Semua variables, 89 variabel (`color` 28 Light/Dark, `space` 10, `radius` 5, `type` 44, `opacity` 2), format JSON FigCraft; diekspor ulang 2026-11-18 setelah putaran 1.5. Mode `UJI130` sengaja dibuang. Sumber nilai saat menulis tema. |
| `tokens.dart` | Ekspor Dart FigCraft sebagai referensi (konstanta per koleksi/mode). Nama kelas hasil ekspor bentrok dengan nama Flutter (`Color_`, `Type`, `Opacity`, `Radius`); jangan dipakai langsung. Salin nilai ke `tokens.dart` aplikasi di `lib/core/theme/` dengan nama sendiri. |
| `review-round1.md` | Hasil review dan semua keputusan per butir. |
| `CLAUDE.md`, `STATUS-desain.md` | Aturan kerja dan catatan progres desain. |

## 2. Pemetaan token (brief bagian 9)

| Figma | Flutter |
|---|---|
| `color/*` (Light, Dark) | `ColorScheme.light(...)` dan `ColorScheme.dark(...)`: primary, onPrimary, primaryContainer, onPrimaryContainer, secondary, surface, surfaceContainerLow, surfaceContainer, onSurface, onSurfaceVariant, outline, outlineVariant, error, onError, scrim |
| `color/scrim` | `ColorScheme.scrim`. Pakai `showModalBottomSheet(barrierColor: colorScheme.scrim.withValues(alpha: 0.32))`. Nilai token `#000000` alpha 32% sama di Light dan Dark. |
| `color/surfaceContainerLowest` | `ColorScheme.surfaceContainerLowest` (Light `#FFFFFF`, Dark `#0A0F0D`): kartu terang di atas `surface` (daftar surah, ayat, harian, LastReadCard, notifikasi) |
| `color/ext/*` (arabicText, lastReadHighlight, searchHighlight, ornament, offlineBadge, **hero, heroShape, onHero, onHeroAccent, iconAccent**) | `NuraColors extends ThemeExtension<NuraColors>`. Baru: hero Light `#185A4B`/Dark `#0F3F34`; heroShape `#1B6252`/`#124A3D`; onHero `#F8F7F3`/`#F1F2EF`; onHeroAccent `#EBCB8B`; iconAccent `#8A6A3E`/`#D9BE92` |
| `type/*` Latin (displaySmall ... labelMedium, translation) | `TextTheme`. Font `Plus Jakarta Sans`. Ukuran/tinggi baris/berat dari `tokens.json` (tinggi baris Flutter = lineHeight / ukuran). |
| `type/arabicReading`, `arabicCard`, `arabicTitle`, `arabicHero` (40/56, baru), `arabicReading36` | `NuraTextStyles extends ThemeExtension<NuraTextStyles>`. Font `LPMQ Isep Misbah`. |
| `space/*` (4, 8, 12, 16, 20, 24, 32, 36, 40, 48; `space/36` baru = ukuran OrnamentBadge), `radius/*` (sm 8, md 12, lg 16, xl 24, full 999) | Konstanta di `lib/core/theme/tokens.dart` |
| `opacity/disabledContent` 0.38, `opacity/disabledContainer` 0.12 | Default `ThemeData` Material 3 (`onSurface.withValues(alpha: 0.38)` untuk teks/ikon, `0.12` untuk latar/border). Tidak perlu ThemeExtension. |
| `color/outline` | Batas komponen interaktif (SearchField, Chip, Button outlined, Toggle off). `outlineVariant` hanya untuk pemisah/dekoratif. |

Ukuran Arab bisa diatur pengguna (20–40); desain default 28 dan ada contoh 36. Padding layar horizontal 20, jarak antarkartu 12, tanpa drop shadow.

## 3. Komponen, varian, dan keadaan

Properti dan nilai (nama set Figma, sesuai file pada 2026-11-19):

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
| NextPrayerCard, LastReadCard | tunggal. LastReadCard: kartu terang, ikon `history`, nama surah Arab kecil. NextPrayerCard tidak dipakai di Beranda; disimpan untuk layar Jadwal Sholat putaran 2 |
| DailyCard | Type: Ayat/Hadis (pratinjau widget; kartu terang) |
| DailyWidget (Light dan Dark) | Type: Ayat/Hadis · Size: 4x2/4x3 · Isi: Normal/Panjang. Ukuran: Ayat 4x2 = 168 dan 4x3 = 256 (memuat nama surah Arab `arabicTitle` `iconAccent`); Hadis 152/240; lebar 320. Ukuran ini hanya perkiraan desain: widget dirender sesuai ukuran yang diberikan launcher (grid sel, bisa di-resize pengguna), bukan ukuran tetap |
| DailyNotification (Light dan Dark) | Type: Ayat/Hadis · State: Collapsed/Expanded (kartu terang + border `outlineVariant`, tanpa Arab) |
| SurahHeaderCard | Bismillah: Ya/Tidak (Tidak untuk At-Taubah dan Al-Fatihah). Kartu `ext/hero`: info kiri (label `onHero`, nilai `onHeroAccent`), nama Arab `arabicHero` kanan. Ya = Basmalah di kartu terang terpisah di bawah kartu hero (tinggi 226; Tidak = 124) |
| BismillahHeader | tunggal (dipakai di dalam SurahHeaderCard varian Ya) |
| SurahListItem | State: Default/Bookmarked/Terakhir dibaca; `OrnamentBadge` + nama Latin + "Arti · N ayat · [Q4]" + nama Arab `arabicTitle` `iconAccent`; kartu `surfaceContainerLowest` + border `outlineVariant` + radius `lg` (Terakhir dibaca = latar `lastReadHighlight` + ikon `history`; Bookmarked = ikon bookmark) |
| JuzListItem | tunggal (placeholder Q4): `OrnamentBadge` + "Juz [Q4]" + rentang "[Q4]" + chevron; kartu `surfaceContainerLowest` + border `outlineVariant` + radius `lg` (selaras SurahListItem) |
| OrnamentBadge (menggantikan AyahNumberBadge) | Digits: 1/2/3 · ukuran 36 (`space/36`): bingkai bintang delapan garis tipis `iconAccent` + angka. Dipakai di SurahListItem dan JuzListItem; nomor ayat di AyahCard kini teks kecil `iconAccent` tanpa bingkai |
| AyahActionBar | Audio: Mati/Siap streaming/Tersimpan offline/Sedang memutar × Bookmark: Tidak/Ya (Ya = ikon terisi `primary`). Urutan: salin, bookmark, putar, bagikan, tafsir; 5 tombol sama lebar dan sama tinggi 48 (latar `surfaceContainerLow`, radius `md`); putar hilang saat audio mati; sel audio vertikal (ikon + teks status) dengan tinggi sama |
| Tab | (lihat atas) garis bawah `primary` 2 px pada tab aktif |
| AyahCard (struktur baru) | Baris atas (nomor kecil `iconAccent` kiri, menu `Icon/more` kanan, area sentuh 48), Arab + penanda ۝, terjemahan, garis `outlineVariant`, AyahActionBar. State: Default/Terakhir dibaca/Bookmarked/Terakhir dibaca + Bookmarked × Terjemahan: Tampil/Tersembunyi × Arab: 28/36 (36 hanya Default + Tampil) |

Keadaan AyahCard:
- **Terakhir dibaca:** latar `lastReadHighlight`, label "Terakhir dibaca" (labelMedium) + ikon `history` di baris tipis 24 di atas baris badge/aksi.
- **Bookmarked:** ikon bookmark terisi di AyahActionBar (tidak ada ikon kecil tambahan).
- **Tata letak:** baris atas (nomor kecil kiri, menu kanan), Arab rata kanan, terjemahan, garis pemisah, lalu AyahActionBar selebar kartu (struktur putaran 1.5; menggantikan badge + bilah aksi sebaris).

Layar (Figma): halaman `03 Screens · Fase 1` (9 layar Light+Dark; F1/05 Beranda dibuat ulang di putaran 1.5; layar 06-11 dirakit ulang dari komponen baru) dan `04 Screens · Fase 2` (16 layar Light+Dark: 06a/b/c, 07a/b/c/d, 08a/b, 09a/b, 10a/b/c, 11a/b). Frame bernama `F1/xx`/`F2/xx`; variasi tinggi penuh dan Arab 36 ada sebagai frame terpisah.

## 4. Aturan teknis

### Putaran 1.5 (penyegaran visual)

- **Penanda akhir ayat tidak boleh putus baris sendirian.** Penanda digambar aplikasi sebagai widget sebaris (`AyahEndMarker`: cincin `U+06DD` dengan nomor Arab-Indik di tengahnya), bukan teks, karena mesin teks Flutter tidak menerapkan ligatur GSUB font yang melingkupi angka. Kata terakhir (dengan tanda waqaf) dan penanda ditaruh dalam satu widget karena mesin mengabaikan U+00A0/U+2060 di sebelah widget sebaris. Teks data tidak berubah selain pembuangan spasi ASCII di ujung; disimpan/dicari/disalin tanpa penanda.
- **Menu kartu ayat** memakai ikon `more_horiz` (⋯ horizontal) Material Symbols Rounded 300; area sentuh 48.
- **AyahActionBar:** kelima sel sama lebar dan sama tinggi 48 pada semua varian (audio mati = empat sel); sel audio berisi ikon di atas teks status pendek ("Stream", "Offline", "Memutar").
- **JuzListItem** mengikuti SurahListItem (OrnamentBadge, kartu `surfaceContainerLowest`, border `outlineVariant`); nomor juz dan rentang ayat tetap "[Q4]".
- **ListTile onboarding:** ikon Material Symbols Rounded 300 (`location_on` di depan, `chevron_right` di belakang).
- **Penanda akhir ayat:** teks Arab AyahCard diakhiri simbol ۝ (U+06DD) + angka Arab-Indik. Cincin U+06DD diambil dari font (`nuraArabicFont`), nomornya digambar aplikasi di dalam cincin. Pada hasil pencarian penanda kadang jatuh ke baris sendiri (catatan terbuka).
- **Beranda:** hero full-bleed `ext/hero` (±360 termasuk status bar) dan siluet datar `heroShape` jadi kerangka layar, bukan hiasan opsional; lembar konten `surface` menumpuk 24 px di atasnya (radius `xl`). Tanpa gradasi. Waktu sholat berikutnya = warna `onHeroAccent` + titik (jangan hanya warna; underline tidak dipakai).
- **Ikon:** Material Symbols Rounded weight 300 (google/material-design-icons, Apache 2.0): `iconAccent` di kartu terang, `onHero` di hero. Chevron navigasi ayat buatan sendiri. Ikon Subuh/Isya memakai glyph bulan sabit fungsional (nightlight/bedtime).
- Kartu konten: `surfaceContainerLowest` + border `outlineVariant` 1 px + radius `lg`.

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
- Uji Baca Surah: ayat panjang di ukuran Arab 36: penanda ۝ tidak boleh jatuh sendiri ke baris baru (kata terakhir dan penanda satu widget; lihat aturan penanda akhir ayat di atas).
- Target sentuh minimal 48 × 48; status tidak boleh hanya warna (lastRead = label + ikon + latar; bookmark = ikon terisi; offline = teks + centang; chip/tab punya penanda tambahan).
- Ikon fungsi (history, bookmark, salin, bagikan, putar, tafsir, more, ikon hero) = Material Symbols Rounded weight 300 (Apache 2.0); komponen `Icon/<nama>` 24x24 di Figma.

## 5. Placeholder dan catatan terbuka

| Hal | Status |
|---|---|
| **Q4** (Makkiyah/Madaniyah, juz, rentang ayat) | Slot ada di SurahListItem, SurahHeaderCard, dan tab Juz; berisi "[Q4]" dengan layer berakhiran "(menunggu Q4)". Data-source tidak punya field ini; jangan diisi dari ingatan. |
| **Angka ruang (ex "~XXX MB")** | Layar error ruang penyimpanan: angka dihitung saat runtime, bukan teks tetap. Rumus: ukuran asset `content.db` × 1,10, dibulatkan ke atas per 5 MB (data sekarang ≈ 125 MB), dibandingkan dengan ruang kosong perangkat sebelum penyalinan. Layer "storage-size" di Figma hanyalah contoh. Aturan lengkap: spec bagian 5.4. |
| **Jam 06.00** | Jam default notifikasi harian adalah asumsi, belum diputuskan produk. |
| **Lisensi font Q6** | Plus Jakarta Sans (OFL); LPMQ Isep Misbah dan cadangan KFGQPC Uthmanic Script Hafs: lisensi wajib dicek sebelum rilis. LPMQ diambil dari sumber resmi LPMQ (lajnah.kemenag.go.id/unduhan); catat tanggal unduh di catatan rilis. |
| **Ikon dan ilustrasi** | Ikon fungsi sudah Material Symbols Rounded 300; ikon aplikasi final (brief bagian 10) dan ilustrasi EmptyState/ErrorState/onboarding (kini lingkaran/frame kosong) belum ada. |
| **Wordmark** | Splash memakai wordmark sementara (Q2). |
| **Aturan seleksi hadis harian** | Fase 6 (matan Arab dan terjemahan bisa diekstrak bersih, batas karakter N, Bukhari/Muslim). Tidak ada hadis panjang uji untuk widget "Isi=Panjang" varian Hadis. |
| **Layar detail hadis** | Belum didesain (putaran 2); "Baca selengkapnya" hanya tautan. |
| **Daftar kota** | Layar onboarding jadwal memakai 2 ListTile contoh; daftar kota lengkap dan hasil pencarian kota belum didesain. |
| **Jam sholat, kota, tanggal Hijriah** | Contoh berlabel "(contoh)". |
| **Keadaan error/tombol dua baris** | Tombol utama onboarding/error pada layar sempit: Button wrap sudah ada, tetapi varian khusus belum. |
| **Gulir sheet** | Gulir di dalam sheet tidak bisa disimulasikan di Figma; implementasi Flutter perlu memastikan isi bergulir dengan tinggi maksimum 90%. |
| **Target ayat terlihat** | Layar Baca Surah 07a menampilkan ±2,09 ayat Al-Baqarah di frame 800 (target 2,5 dilepas oleh keputusan produk; info saja). |
| **Varian sisa** | Mode `UJI130` di Figma dipertahankan untuk uji ulang (tidak ada di tokens.json); salinan `UJI130b` dibuang 2026-11-18, 99 Playground hanya berisi 4 Beranda uji. |
| **Terbuka putaran 1.5** | (a) ukuran widget Ayat 168/256 tetap perkiraan (ukuran sebenarnya dari launcher); (b) kontras `onHeroAccent` di atas `heroShape` Light 4,61:1 diterima (batas tipis; cek ulang jika `heroShape` atau `onHeroAccent` diubah); (c) penanda ۝ masih bisa jatuh ke baris sendiri pada hasil pencarian bila baris Arab pas penuh (diatasi: kata terakhir + penanda satu widget; pada hasil pencarian penanda berdiri sendiri sebagai widget). |

## 6. Verifikasi yang sudah dilakukan (pengawas, 2026-11-10/11)
- Audit seluruh halaman 02, 03, 04 (+99): 0 nilai tanpa binding variable, semua teks bertext style; teks Arab (ayat, nama surah, matan hadis) cocok persis dengan `data-source/`; terjemahan, tafsir, hadis, dan cuplikan pencarian substring persis; kontras (teks ≥ 4.5:1, ikon ≥ 3:1, elemen disabled dikecualikan) dan target sentuh ≥ 48 lolos di Light dan Dark.
