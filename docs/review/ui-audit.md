# Audit penyelarasan UI dengan handoff Putaran 1.5

Tanggal: 2026-11-19 · Branch: `feat/ui-alignment` · Tidak ada kode yang diubah.

## Cakupan dan batas

- **Acuan:** `docs/design/2026-11-17-nura-penyegaran-visual.md`, `HANDOFF-flutter.md`, `2026-11-09-nura-ui-design-brief.md`, `tokens.json`, dan 14 gambar di `docs/design/screenshots/` (Beranda, 06a, 07a, 07b, 07c, 10a, 11a; Light dan Dark).
- **Pembanding:** kode di `lib/app/`. **Screenshot aplikasi di perangkat BELUM ada:** tidak ada perangkat yang terhubung (`adb devices` kosong) dan tidak ada AVD terpasang. Semua perbedaan di bawah berasal dari pembacaan kode dibanding desain. Jarak, tinggi baris, dan rendering font perlu dipastikan dengan screenshot perangkat. Kolom "Pasti?": **K** = pasti dari kode, **P** = perlu konfirmasi di perangkat.
- **Daftar task di handoff Putaran 1.5:** handoff dan brief tidak memuat daftar task implementasi bernomor untuk Putaran 1.5. Penomoran yang ada hanya "Task 8 (Menyiapkan konten)", "Task 10 (Onboarding, layar error, pemetaan token)" dan "Langkah 3b (widget, DailyCard)" di brief. Daftar di bagian 4 adalah usulan saya dengan awalan **UA-**, bukan penomoran dari handoff.
- Besar kerja: **S** (< 0,5 hari), **M** (0,5–1,5 hari), **L** (> 1,5 hari), termasuk tes.

## 1. Temuan lintas layar (fondasi)

| # | Perbedaan | Desain | Kode sekarang | Penyebab | Pasti? | Kerja |
|---|---|---|---|---|---|---|
| F1 | Token baru belum ada | `ext/hero`, `heroShape`, `onHero`, `onHeroAccent`, `iconAccent`, `surfaceContainerLowest`, `space/36`, `type/arabicHero` | `NuraColors` hanya 5 field lama; `NuraSpace` tanpa 36; tidak ada `arabicHero`; `app_theme.dart` tidak mengisi `surfaceContainerLowest` | Token Putaran 1.5 baru diekspor 2026-11-18 | K | S |
| F2 | Font Arab LPMQ tidak terdaftar | Semua teks Arab LPMQ Isep Misbah (juga nama surah Arab dan penanda ۝) | `pubspec.yaml` hanya mendaftarkan Plus Jakarta Sans; Arab memakai font sistem | Menunggu Q6 (lisensi) | K | S setelah Q6; **memblokir tampilan benar** untuk nama Arab, ۝, `arabicHero` |
| F3 | Kartu konten | `surfaceContainerLowest` + border `outlineVariant` 1 px + radius `lg` | Kartu memakai warna lama dan `ornament` sebagai latar | Perubahan Putaran 1.5 | K (warna), P (border dan radius) | M (tersebar) |
| F4 | Ikon | Material Symbols Rounded weight 300, `iconAccent`/`onHero` | `Icons.*` bawaan Material (mis. `play_arrow_rounded`, `bookmark_border`, `tune`) | Ikon belum diganti | K | M (font/aset ikon baru perlu persetujuan, AGENTS.md) |
| F5 | Komponen baru belum ada | `OrnamentBadge` (bintang delapan), bilah aksi 5 sel sama lebar | Hanya `ayah_number_badge.dart`; `ayah_action_bar.dart` berisi IconButton biasa | Putaran 1.5 | K | M |

## 2. Perbedaan per layar

### F1/05 Beranda

| Desain (Putaran 1.5) | Kode sekarang | Penyebab | Pasti? | Kerja |
|---|---|---|---|---|
| Hero full-bleed `ext/hero` ±360: lokasi + ikon cari, tanggal Hijriah, **jam besar**, hitung mundur "Maghrib dalam N menit", baris 6 waktu, siluet `heroShape` | Tidak ada. Beranda = header "Beranda" + ikon `tune` + `ListView` kartu harian. Waktu sholat hanya di tab Sholat | Beranda Fase 6 dibuat sebelum Putaran 1.5; data ada di `PrayerController`, belum dipasang di Beranda | K | **L** |
| Tanggal Hijriah | Belum ada sumber atau perhitungan Hijriah | Desain menulisnya sebagai contoh | K | Butuh keputusan (kode sendiri atau paket baru) |
| Lembar konten `surface` menumpuk 24 px di atas hero, radius `xl` | Tidak ada | Idem | K | termasuk hero |
| `LastReadCard` di Beranda (kartu terang, nama surah Arab kecil, "Lanjutkan") | Tidak ada kartu last read di Beranda | Last read ada di Quran, belum dipasang di Beranda | K | M |
| DailyCard Ayat/Hadis dengan ornamen bintang tipis (Ayat), kartu terang | `DailyAyahCard`/`DailyHadithCard` (Fase 6), gaya sebelum 1.5 | F3 | K | S–M |
| `NextPrayerCard` tidak dipakai di Beranda | Komponen ada di `core/widgets`, tidak dipasang di Beranda | Sesuai desain | K | 0 |
| Bottom nav 4 item | `NavigationBar` dengan label sama | Sesuai | K | 0 |
| Ikon `tune` (pengaturan harian) tidak ada di desain | Ada di header Beranda | Sementara (Fase 6) | K | Diganti Pengaturan di Fase 8 Task 1 |

### F2/06a Daftar Al-Qur'an

| Desain | Kode | Penyebab | Pasti? | Kerja |
|---|---|---|---|---|
| `SurahListItem`: `OrnamentBadge` + nama Latin + "Arti · [Q4] · N ayat" + nama Arab `arabicTitle` `iconAccent` kanan | `surah_list_item.dart`: badge lama, warna `ornament`, nama Arab belum bergaya baru | F1, F2, F5 | K | M |
| Kartu terang + border + radius `lg` | Gaya lama | F3 | K | termasuk |
| `JuzListItem` selaras SurahListItem | `juz_list_item.dart` sederhana | F5 | K | S |
| Tab: garis bawah `primary` 2 px | `TabBar` Material standar (Surah, Juz, Bookmark) | Indikator M3 bisa sudah mirip | P | S |

### F2/07a–c Baca Surah

| Desain | Kode | Penyebab | Pasti? | Kerja |
|---|---|---|---|---|
| `SurahHeaderCard` kartu `ext/hero` (info kiri `onHero`/`onHeroAccent`, nama Arab `arabicHero` kanan) | `surah_header_card.dart`: latar `ornament`, teks `arabicText` | F1, F2 | K | M |
| Basmalah di kartu terang terpisah | `bismillah_header.dart`, bentuk lama | F3 | K | S |
| `AyahCard`: nomor kecil `iconAccent` kiri atas, menu ⋯ kanan atas, Arab rata kanan, terjemahan, garis `outlineVariant`, bilah aksi | `ayah_card.dart`: `AyahNumberBadge` + aksi sebaris; tanpa ⋯; tanpa garis | F5 | K | M |
| **Penanda ۝ + angka Arab-Indik**, disambung `U+00A0`, spasi ASCII ujung dibuang | Tidak ada; `ayah.arab` ditampilkan apa adanya, tidak ada `U+06DD`/`U+00A0` di `lib/` | Aturan baru (sudah di PRD 5.1 dan spec 5.6) | K | S + tes; benar visual hanya dengan LPMQ |
| Bilah aksi 5 sel sama lebar tinggi 48; putar hilang saat audio mati; sel audio ikon + teks status | `ayah_action_bar.dart` dengan kontrol Fase 7: putar, jeda, "putar dari sini" | Mockup 1.5 tidak mengenal kontrol surah dan "putar dari sini" (audio streaming Fase 7 belum tercermin di desain) | K | M; **perlu keputusan desain** |
| Terakhir dibaca: latar `lastReadHighlight` + label + ikon `history` | Latar sudah ada | Sesuai | P | S |

### F2/10a Pencarian dan F2/11a Bookmark

| Desain | Kode | Penyebab | Pasti? | Kerja |
|---|---|---|---|---|
| Hasil per surah, kartu terang, cuplikan maks 3 baris, sorotan | `search_view.dart`, `search_result_tile.dart`: cuplikan dan sorotan sesuai spec 5.5 | Gaya kartu lama | P | S (F3) |
| ۝ pada hasil kadang jatuh ke baris sendiri | Tidak ada ۝ | Idem | K | S, bergantung F2 |
| Bookmark: kartu `surfaceContainerLowest`, ikon `iconAccent` | `bookmark_tile.dart`, `bookmarks_tab.dart` gaya lama | F3, F4 | K | S |

### Tanpa mockup 1.5

Onboarding dan error hanya ikut komponen (ikon `location_on`/`chevron_right`, warna kartu). Layar error ruang penyimpanan belum ada (aturan angka di spec 5.4). Layar Hadis, Jadwal Sholat, daftar kota, dan Pengaturan belum didesain (putaran 2). Widget layar depan: desain menambah nama surah Arab dan kartu terang; `daily_widget_image.dart` perlu F1 dan F2 (M).

## 3. Rangkuman besar kerja

| Kelompok | Besar |
|---|---|
| Token dan tema (F1) | S |
| Registrasi font LPMQ (F2) | S, **menunggu Q6** |
| Kartu terang di semua layar (F3) | M |
| Ikon Material Symbols (F4) | M, butuh persetujuan |
| `OrnamentBadge`, bilah aksi, `AyahCard`, `SurahHeaderCard`, `SurahListItem`, `JuzListItem` | M–L |
| Penanda ۝ + U+00A0 | S |
| Beranda hero | L |
| Widget layar depan | M |
| Total perkiraan | sekitar 8–12 hari kerja termasuk tes dan uji perangkat |

## 4. Usulan daftar task (awalan UA-, bukan dari handoff)

1. **UA-1 Token dan tema:** `NuraColors` (+ hero, heroShape, onHero, onHeroAccent, iconAccent), `surfaceContainerLowest`, `NuraSpace.s36`, `arabicHero`; sumber `tokens.json`; tes pemetaan Light dan Dark.
2. **UA-2 Font dan penanda ayat:** daftarkan LPMQ (setelah Q6), fungsi tampilan `U+00A0 + U+06DD + angka Arab-Indik` (tes byte-persis, teks data tidak diubah).
3. **UA-3 Komponen dasar:** `OrnamentBadge`, bilah aksi 5 sel, kartu terang bersama, ikon (F4).
4. **UA-4 Daftar Al-Qur'an:** `SurahListItem`, `JuzListItem`, tab.
5. **UA-5 Baca Surah:** `SurahHeaderCard` hero + Basmalah terpisah, `AyahCard` baru, menu ⋯, kontrol audio di bilah.
6. **UA-6 Pencarian dan Bookmark:** gaya kartu baru.
7. **UA-7 Beranda hero:** hero, lembar, last read, kartu harian; keputusan tanggal Hijriah.
8. **UA-8 Widget layar depan:** nama Arab dan kartu terang.
9. **UA-9 Uji perangkat:** screenshot Light dan Dark dibandingkan 14 gambar desain.

## 5. Pertanyaan untuk pemilik

1. Sambungkan perangkat (atau pasang emulator) agar screenshot perbandingan bisa diambil; audit ini belum memuatnya.
2. Q6 (lisensi LPMQ) menentukan kapan UA-2 bisa dikerjakan; tanpa LPMQ, hasil visual Arab dan ۝ tidak mewakili desain.
3. Ikon Material Symbols: izinkan font/aset ikon (Apache 2.0), atau pakai `Icons.*` sampai putaran 2?
4. Tanggal Hijriah di hero: dihitung offline, dari API, atau ditunda?
5. Nasib kontrol audio Fase 7 ("Putar surah", "Putar dari sini", "Jeda") di bilah aksi 5 sel: butuh keputusan desain.

## 6. Status pelaksanaan (2026-11-19)

UA-1 sampai UA-8 selesai di branch `feat/ui-alignment` (rencana `docs/plans/2026-11-19-nura-ui-alignment.md`); UA-9 (uji perangkat) menunggu pemilik; checklist di `docs/STATUS.md` (butir 0b). Keputusan atas pertanyaan di bagian 5: perangkat ditunda ke akhir; font Arab cadangan Scheherazade New dengan satu titik penggantian; ikon `material_symbols_icons`; Hijriah offline dengan penyesuaian −1/0/+1; audio: sel putar di bilah dan "Putar dari sini" di menu ⋯. Tersisa: kartu ayat penuh di pencarian dan bookmark (F-pencarian), "Bagikan" (paket baru).
