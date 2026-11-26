# Nura Fase 8 (Polish dan Persiapan Rilis): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Onboarding sekali jalan, layar Pengaturan terpusat, layar Sumber & Atribusi, ikon dan splash, dan konfigurasi build rilis Play Store yang aman (AAB bertanda tangan dengan keystore di luar git), plus daftar syarat rilis yang masih terbuka sebagai checklist.

**Architecture:** Tidak ada layanan atau skema baru. `SettingsController` dan `SettingsView` menyatukan semua sakelar yang sekarang tersebar (sheet baca, sheet harian, layar Sholat) di atas store dan layanan yang sudah ada (`OnlineService`, `AudioSettingsStore`, `DailySettingsStore`, `PrayerStore`, `UserRepository`, `ThemeController`), jadi satu sumber kebenaran per setelan. `OnboardingController` memakai ulang pemilih wilayah, `PrayerRepository`, `PrayerNotifier`, dan `DailyNotifier`. Sumber & Atribusi adalah layar statis. Ikon, splash, dan penandatanganan rilis adalah perubahan platform (`android/`) di commit terpisah.

**Tech Stack:** Flutter, GetX, XML Android untuk ikon adaptif dan splash (tanpa `flutter_launcher_icons`/`flutter_native_splash`, lihat D4), `showLicensePage` bawaan Flutter untuk lisensi paket. Tidak ada paket baru yang diusulkan; bila pemilik memilih paket pembuat ikon/splash, itu keputusan terbuka (D4).

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (5.3, 5.4, 11 Fase 8), `docs/PRD.md` (5.7 onboarding dan Sumber & Atribusi, 6 sumber data, 7 non-fungsional, 9 pertanyaan terbuka), `docs/STATUS.md` (daftar Q dan syarat rilis), desain: `docs/design/2026-11-09-nura-ui-design-brief.md` (bagian 5 layar 1 Splash dan 3 Onboarding, bagian 10 "di luar putaran ini": pengaturan umum, ikon aplikasi final, materi Play Store belum didesain) dan `docs/design/HANDOFF-flutter.md`. Baca juga `AGENTS.md`.

## Global Constraints

- Kode dan komentar teknis Inggris; teks pengguna Indonesia. Tanpa `ignore_for_file`. Hindari `!` (komentar alasan bila terpaksa). `flutter analyze` bersih, `flutter test` lulus sebelum tiap commit. Satu topik per commit (Conventional Commits Inggris). Perubahan `android/` di commit terpisah (AGENTS aturan 8). Jangan push; sebelum push, konfirmasi langsung dari pemilik bahwa repo privat.
- **Keystore, `key.properties`, dan kata sandi tidak pernah masuk git** (`android/.gitignore` sudah menolak `key.properties`, `*.keystore`, `*.jks`); tidak ada rahasia di log, STATUS, atau laporan.
- Tidak ada pemanggilan jaringan baru. Sakelar tetap satu sumber kebenaran: layar Pengaturan, onboarding, dan layar lain membaca dan menulis setting yang sama lewat store/layanan yang ada.
- Layar baru menangani loading, kosong, dan error; target sentuh ≥ 48 dp; skala teks 130% pada 360×640 tanpa overflow; tidak ada future di `build()`.
- UI Fase 8 sementara: desain putaran 2 (pengaturan umum, ikon final, materi Play Store) belum ada. Logika di controller, view tipis, memakai komponen yang ada.
- Semua string UI baru dikumpulkan untuk persetujuan pemilik. Tidak ada perubahan skema `content.db`/`user.db`, tidak ada data-source baru.
- Aturan AGENTS bagian Pola: setiap klien HTTP punya test terhadap transport asli (tidak ada klien HTTP baru di fase ini).

> **Urutan kerja (2026-11-19):** Fase 8 ditunda sampai penyelarasan UI dengan handoff Putaran 1.5 selesai (audit: `docs/review/ui-audit.md`, branch `feat/ui-alignment`).

## Fakta yang diukur (2026-11-17)

| Hal | Nilai |
|---|---|
| Onboarding sekarang | Placeholder Fase 1: satu layar "Selamat datang di Nura" + tombol "Mulai" yang menulis `onboarding_done=true` lalu `Get.offAllNamed(Routes.home)`. `NuraApp` memilih `initialRoute` = home bila `onboarding_done == 'true'`, selain itu onboarding |
| Setelan tersebar | Sheet baca surah: ukuran font Arab, sakelar terjemahan, tema, bagian "Audio" (sakelar "Fitur Online" dan qari). Sheet harian (ikon "Pengaturan harian" di Beranda): sumber hadis + keterangan 9 kitab, sakelar dan jam notifikasi harian. Layar Sholat: wilayah, sakelar sinkron ("Unduh jadwal sholat"), lima sakelar pengingat, catatan izin. Layar Pengaturan terpusat: belum ada |
| Kunci setting yang ada | `theme_mode`, `online_enabled`, `prayer_sync_enabled`, `onboarding_done`, `arabic_font_size`, `show_translation`, `qari_id`, `notify_*` (lima waktu), `prayer_adjust_*`, `daily_hadith_source`, `daily_notify_enabled`, `daily_notify_time` (+ `arabic_font_scale`/`translation_font_scale` tidak terpakai) |
| Build rilis | `android/app/build.gradle.kts`: `signingConfig = signingConfigs.getByName("debug")` (template, ada TODO); `applicationId com.technowstack.nura`; `minSdk 24`, `targetSdk 36`, `compileSdk 37`; `pubspec.yaml` `version: 0.1.0+1`; R8 aktif (ada `proguard.map`) |
| Ukuran AAB (`flutter build appbundle --release`, ditandatangani kunci debug) | **94,7 MB** (94.709.586 byte). Pada 2026-11-09: 80,4 MB. Isi terbesar: `content.db` 118.145.024 byte tak terkompresi (112,7 MiB), lalu peta R8 dan simbol debug (metadata, bukan unduhan pengguna). Kenaikan ±14 MB berasal dari kode dan paket Fase 3–7 |
| Izin di manifest hasil gabungan (rilis) | `INTERNET`, `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `WAKE_LOCK`, **`FOREGROUND_SERVICE`** (tidak kita deklarasikan: datang transitif dari `androidx.work` lewat `home_widget`; `SystemForegroundService` ada di manifest dengan `enabled=@bool/enable_system_foreground_service_default`, tanpa `foregroundServiceType`). Keputusan Fase 7 D3 melarang izin foreground service |
| Ikon dan splash | Ikon launcher masih ikon bawaan Flutter (`mipmap-*/ic_launcher.png`, tanpa ikon adaptif atau monokrom); splash = `launch_background` putih bawaan template; tidak ada `flutter_launcher_icons`/`flutter_native_splash` di `pubspec.yaml`; desain splash ada di brief (logo/wordmark di atas `surface`, ornamen tipis), ikon final belum didesain |
| Lisensi font | Plus Jakarta Sans: OFL (`assets/fonts/PlusJakartaSans/OFL.txt` sudah jadi asset). LPMQ Isep Misbah: status lisensi dan tashih belum jelas (Q6); font itu dipakai untuk teks Arab |
| Sumber data (README `data-source/`, PRD bagian 6) | Kemenag RI (Al-Qur'an: Arab, terjemahan, tafsir); `gadingnst/hadith-api` (MIT) dengan data asal tafsirq.com (9 kitab hadis); EQuran.id v2 (jadwal sholat, sumber Bimas Islam Kemenag; audio murottal, sumber Verse By Verse Quran); LPMQ Kemenag (font); Plus Jakarta Sans (OFL); daftar ayat harian disusun pemilik (sementara) |

## Daftar syarat rilis yang masih terbuka (checklist, bukan task kode)

| Item | Status sekarang | Tindakan pemilik / catatan |
|---|---|---|
| Q2 Nama "Nura" | Belum dicek | Cek Play Store dan DJKI |
| Q3 equran.id | Syarat layanan dibaca (2026-11-16); keputusan audio dan jadwal dibuat | Konfirmasi tertulis ke equran.id dianjurkan (tidak wajib): streaming audio, pemakaian jadwal, lisensi sumber audio (Verse By Verse Quran) |
| Q6 LPMQ | Belum jelas | Ketentuan tashih LPMQ untuk mushaf digital dan lisensi font; catat tanggal unduh font di catatan rilis; cadangan KFGQPC |
| Q7 Terjemahan hadis | Belum jelas | Konfirmasi lisensi teks terjemahan (data asal tafsirq.com) |
| Q8 Verifikasi `data-source/` | Belum | Bandingkan ke sumber asli; tugas terpisah |
| Q9 Daftar ayat harian | Sementara 3 ayat uji | Kurasi final oleh pemilik; selama kosong/sementara fitur ayat tampil dengan daftar uji |
| Q12 Hadis terpotong | 19 hadis dikecualikan dari kandidat harian | Keputusan patch teks sumber bergantung Q7 |
| Sampel matan | `docs/review/matan-samples-2.md` belum diperiksa | Pemilik memeriksa 50 sampel; entri bermasalah ke `daily_hadith_exclude.json` |
| Q4, Q5 | Q4 koordinat kab/kota belum ada (cadangan `adhan` tidak aktif); Q5 diputuskan | Tidak memblokir rilis; catat bahwa cadangan offline belum aktif |
| Atribusi dan privasi | Layar Sumber & Atribusi dibuat di fase ini | Kebijakan privasi (URL publik) dibutuhkan Play Console (D9) |
| Uji perangkat | Sebagian per fase | Checklist uji perangkat tiap fase di STATUS; uji build rilis (R8) di Task 5 |

## Review Focus

1. **Onboarding terputus atau ditolak**: aplikasi dimatikan di tengah onboarding, tombol Kembali, izin notifikasi ditolak, tidak memilih wilayah, internet mati saat sakelar nyala: `onboarding_done` baru `true` di akhir; buka ulang melanjutkan dari awal dengan setelan yang sudah dipilih tetap tersimpan; tidak ada layar buntu; tidak ada permintaan jaringan sebelum pengguna menyalakan sakelarnya (Task 2).
2. **Satu sumber kebenaran untuk sakelar**: mengubah Fitur Online, sinkron jadwal, atau notifikasi di Pengaturan harus langsung berlaku di layanan hidup (audio berhenti saat Fitur Online dimatikan, jadwal dan pengingat dijadwalkan ulang, widget dan notifikasi harian mengikuti), dan layar lain (Sholat, baca surah) menampilkan nilai yang sama tanpa salinan basi (Task 1, 2).
3. **Keamanan penandatanganan rilis**: build rilis tanpa `key.properties` gagal dengan pesan jelas (tidak diam-diam memakai kunci debug), tidak ada keystore atau kata sandi di git atau log, AAB hasil build terverifikasi bertanda tangan kunci rilis (Task 5).
4. **Build rilis berperilaku sama dengan debug**: R8 tidak merusak widget (pencarian kelas provider lewat nama), notifikasi, audio, dan deep link; izin di manifest hasil gabungan sesuai daftar yang disetujui (Task 5).
5. **Kelengkapan atribusi**: setiap sumber yang benar-benar dipakai aplikasi (Kemenag, hadith-api/tafsirq.com, EQuran.id untuk jadwal dan audio, Verse By Verse Quran, font) tercantum, dan tidak ada sumber yang disebut tetapi tidak dipakai; daftar lisensi paket dapat dibuka (Task 3).

## Keputusan terbuka dan asumsi

Keputusan pemilik 2026-11-19 untuk D1, D4, D8, dan D9 sudah tercatat di bawah (arahan D1 opsi A tanggal 2026-11-17 keliru dan ditarik). Pelaksanaan Fase 8 ditunda sampai penyelarasan UI (branch `feat/ui-alignment`, `docs/review/ui-audit.md`) selesai. D2, D3, dan D5–D7, D10–D12 tetap asumsi.

| ID | Pertanyaan | Asumsi / usulan |
|---|---|---|
| D1 | **DIPUTUSKAN (B, 2026-11-19)**: isi onboarding | Tiga langkah sesuai PRD 5.7. Langkah jadwal: pilih wilayah + sakelar "Unduh jadwal sholat" (`prayer_sync_enabled`). **"Fitur Online" tidak ditanyakan di onboarding**; diatur di Pengaturan, dan langkah sambutan hanya menyebut bahwa audio bisa diaktifkan di sana. PRD, spec, dan brief tidak berubah Perubahan 2026-11-26 (pemilik): sakelar menyala secara bawaan di onboarding; ditulis dan diunduh baru setelah "Lanjut". |
| D2 | Layar Pengaturan | Rute `/settings`, dibuka dari ikon di header Beranda (menggantikan ikon "Pengaturan harian" yang membuka sheet). Bagian: Tampilan (tema, ukuran font Arab, tampilkan terjemahan), Fitur Online (sakelar "Fitur Online", qari, sakelar "Unduh jadwal sholat"), Jadwal sholat (wilayah, lima pengingat, keterangan izin), Harian (sumber hadis + keterangan 9 kitab, notifikasi harian + jam), Tentang (Sumber & Atribusi, lisensi paket, versi aplikasi, `data_version`). Bagian "Audio" di sheet baca surah dan sheet harian dihapus; sheet baca tetap memuat opsi tampilan baca (ukuran font, terjemahan, tema) yang memakai store yang sama. Sakelar pengingat sholat dan sinkron tetap juga di layar Sholat (kontekstual) dan terikat ke state yang sama |
| D3 | Sumber & Atribusi | Layar statis dari Pengaturan > Tentang. Daftar: Al-Qur'an (teks Arab, terjemahan, tafsir): Kementerian Agama RI; hadis 9 kitab: gadingnst/hadith-api (MIT), data asal tafsirq.com; jadwal sholat: EQuran.id (sumber Bimas Islam Kemenag); audio: "Audio: EQuran.id (sumber: Verse By Verse Quran)"; font Arab LPMQ Isep Misbah (Kemenag, status lisensi mengikuti Q6) dan Plus Jakarta Sans (OFL, teks OFL dari asset); daftar ayat harian: pemilik proyek; tempat turun surah: EQuran.id (sumber Kemenag); pemetaan juz: Tanzil.info (metadata Tanzil, Creative Commons Attribution 3.0; kredit ke Tanzil.info, tautan lisensi https://creativecommons.org/licenses/by/3.0/, data diformat ulang; teks lengkap di `data-source/README.md`). Tombol "Lisensi perangkat lunak" membuka `showLicensePage` (Flutter, tanpa paket). Teks lisensi font/hadis ditampilkan hanya sejauh sudah jelas; bagian yang menunggu Q6/Q7 diberi catatan netral dan diperbarui sebelum rilis |
| D4 | **DIPUTUSKAN (B, 2026-11-19)**: ikon dan splash | Placeholder sederhana dari token tema, ditandai SEMENTARA di STATUS; aset final menyusul. Dipasang lewat XML Android, **tanpa `flutter_launcher_icons` dan `flutter_native_splash`**. Splash: tema Android 12+ dan `launch_background`, tanpa animasi |
| D5 | Penandatanganan rilis | `android/key.properties` (di luar git) berisi `storeFile`, `storePassword`, `keyAlias`, `keyPassword`; `signingConfigs.release` membacanya; **tanpa fallback ke kunci debug**: bila berkas tidak ada, tugas `bundleRelease`/`assembleRelease` gagal dengan pesan "key.properties tidak ditemukan" (build debug dan test tidak terpengaruh). Keystore dibuat pemilik dengan `keytool` (langkah di `docs/release.md`, tanpa kata sandi), disimpan dan dicadangkan di luar repo; disarankan Play App Signing (kunci yang dipakai di sini menjadi kunci unggah). Verifikasi dengan keystore sekali pakai yang dibuat di luar repo |
| D6 | Versi | `pubspec.yaml`: `1.0.0+1` pada rilis pertama; `versionCode` naik setiap unggahan (pola: `+N`); versi ditampilkan di Pengaturan > Tentang |
| D7 | Ukuran | AAB 94,7 MB saat ini (tabel fakta). Tidak ada pengurangan yang diusulkan (db sudah memakai `page_size 16384` dan FTS contentless). Ukuran dicatat di STATUS setiap rilis (PRD 7); perkiraan unduhan pengguna dihitung dengan `bundletool get-size total` (alat unduhan, bukan dependensi proyek) di Task 5 |
| D8 | **DIPUTUSKAN (2026-11-19)**: izin | (1) Hapus `FOREGROUND_SERVICE` dengan `tools:node="remove"` **setelah memastikan** tidak ada jalur foreground service di `home_widget`/`androidx.work` yang kita pakai (periksa kode dan manifest hasil gabungan); uji widget dan notifikasi di build rilis. (2) Pertahankan `SCHEDULE_EXACT_ALARM` dan siapkan pernyataan penggunaannya untuk Play Console. (3) Izin lain dipertahankan |
| D9 | **DIPUTUSKAN (B, 2026-11-19)**: Data Safety dan kebijakan privasi | Draf Data Safety konservatif: wilayah (nama provinsi dan kab/kota) dan alamat IP dikirim ke layanan pihak ketiga (equran.id) hanya saat fitur online dinyalakan; tanpa akun, analitik, atau iklan; data pengguna hanya di perangkat. Draf kebijakan privasi di `docs/release/privacy-policy.md` (dibuat di Task 7, belum ada). Tempat hosting diputuskan pemilik nanti. Jawaban akhir tetap diperiksa pemilik |
| D10 | Materi Play Store | Deskripsi, tangkapan layar, ikon 512 px, gambar fitur 1024×500, kategori, peringkat konten, kelompok sasaran: disusun pemilik (putaran desain 2 dan materi Play Store); bukan task kode, hanya checklist di STATUS |
| D11 | Tindak lanjut kecil dari STATUS yang ikut Fase 8 (usulan, dapat dikurangi) | (a) hapus `SettingKeys.arabicFontScale`/`translationFontScale` yang tidak terpakai; (b) bungkus `SqliteException` di `SqliteUserRepository` menjadi error domain; (c) kartu waktu sholat berikutnya menampilkan nama "-" bila jadwal besok tidak ada (perbaiki teksnya); (d) last read hanya menghitung ayat yang minimal separuh kartunya terlihat (permintaan pemilik di STATUS; perubahan perilaku kecil). Tidak ikut: sinkron latar belakang WorkManager (butuh rencana dan persetujuan sendiri), profil kinerja pencarian dan hadis panjang, pengetatan matan Arab, serta Q13 lanjutan |
| D12 | Stabilitas build rilis | Uji perangkat dilakukan pada build rilis (bukan hanya debug): R8 dan penghapusan resource bisa mengubah perilaku plugin yang memakai refleksi (nama kelas provider widget). Aturan keep ditambah bila perlu (`proguard-rules.pro`) |

---

### Task 1: Layar Pengaturan terpusat

**Files:**
- Create: `lib/app/modules/settings/{bindings,controllers,views,widgets}/…`
- Modify: `lib/app/routes/app_routes.dart`, `app_pages.dart`, `lib/app/modules/home/home_view.dart` (ikon header), `lib/app/modules/home/widgets/daily_settings_sheet.dart` (dihapus), `lib/app/modules/quran_detail/widgets/reading_settings_sheet.dart` (bagian Audio dihapus), `lib/app/app_bootstrap.dart` (registrasi)
- Test: `test/app/modules/settings/settings_controller_test.dart`, `settings_view_test.dart`; perbarui tes home, reading sheet, dan daily sheet yang menyangkut bagian yang dipindah

**Interfaces:**
- Consumes: `OnlineService` (audioEnabled, prayerSyncEnabled + setter), `AudioSettingsStore`, `DailySettingsStore`, `PrayerStore`, `UserRepository` (tema, font, terjemahan), `ThemeController`, `PrayerNotifier`, `DailyNotifier`, `DailyRefresher`, `AudioPlayerService`. Produces: `SettingsController` (state dari store, aksi per setelan yang memanggil layanan yang sama dengan layar lama), `SettingsView`, `Routes.settings`.

- [ ] **Step 1: Write the failing tests**: setiap sakelar menulis setting yang sama dengan layar lamanya (tabel kunci di atas) dan memanggil layanan yang sama; Fitur Online dimatikan saat memutar → pemutar berhenti dan kontrol audio hilang di layar baca; sinkron jadwal dinyalakan/dimatikan memengaruhi layar Sholat; jam dan sakelar notifikasi harian menjadwalkan ulang `DailyNotifier`; sumber hadis memperbarui kartu Beranda dan widget (refresh paksa); keterangan 9 kitab muncul hanya saat dipilih; qari hanya terlihat saat Fitur Online hidup; ikon di Beranda membuka Pengaturan dan sheet harian tidak ada lagi; sheet baca tidak lagi memuat bagian Audio; keadaan izin notifikasi ditolak menampilkan keterangan; skala teks 130% pada 360×640 tanpa overflow; target sentuh ≥ 48 dp.
- [ ] **Step 2–4: Run fail, implement (UI sementara, D2), run pass.**
- [ ] **Step 5: Commit** `feat: add settings screen` dan `refactor: move temporary switches into settings`.

### Task 2: Onboarding

**Files:**
- Modify: `lib/app/modules/onboarding/onboarding_view.dart`, `lib/app/nura_app.dart` (bila logika awal berubah), `lib/app/app_bootstrap.dart`
- Create: `lib/app/modules/onboarding/{controllers,bindings,widgets}/…`
- Test: `test/app/modules/onboarding/onboarding_controller_test.dart`, `onboarding_view_test.dart`

**Interfaces:**
- Consumes: komponen pemilih wilayah (`RegionPickerView`) dan `PrayerRegions` dari modul Sholat, `PrayerRepository.selectRegion`, `OnlineService`, `PrayerNotifier` dan alur izin notifikasi dari Fase 5, `DailySettingsStore` + `DailyNotifier`. Produces: `OnboardingController` (langkah a–c, kemajuan, `finish()` yang menulis `onboarding_done`).

- [ ] **Step 1: Write the failing tests**: tiga langkah berurutan dan Kembali/Lewati sesuai D1; onboarding tidak memuat sakelar "Fitur Online" (`online_enabled` tidak berubah); tidak ada permintaan jaringan dan tidak ada setting online yang berubah sebelum sakelar jadwal dinyalakan; memilih wilayah menyimpannya lewat repository yang sama dengan layar Sholat; menyalakan "Unduh jadwal sholat" menulis `prayer_sync_enabled`; langkah notifikasi: izin Android 13+ diminta hanya saat pengguna menyalakan salah satu pengingat, ditolak → sakelar tetap mati dengan keterangan, tidak buntu; `onboarding_done` hanya ditulis di akhir (menutup aplikasi di tengah → onboarding mulai lagi, setelan yang sudah dipilih tetap); setelah selesai `Get.offAllNamed(Routes.home)` dan tombol Kembali sistem tidak kembali ke onboarding; pengguna yang sudah `onboarding_done=true` tidak melihat onboarding; setelan onboarding dan Pengaturan tetap sinkron (state sama); 130% teks dan target sentuh.
- [ ] **Step 2–4: Run fail, implement (UI sementara), run pass.**
- [ ] **Step 5: Commit** `feat: add first-run onboarding`.

### Task 3: Sumber & Atribusi

**Files:**
- Create: `lib/app/modules/settings/views/attribution_view.dart`, data sumber sebagai konstanta Dart tunggal `lib/app/core/attributions.dart`
- Modify: `lib/app/routes/*`, Pengaturan > Tentang
- Test: `test/app/modules/settings/attribution_view_test.dart`

**Interfaces:** Produces: `const List<Attribution> kAttributions` (judul, sumber, lisensi/catatan, urutan tampil), layar yang membacanya, tombol `showLicensePage`.

- [ ] **Step 1: Write the failing tests**: setiap sumber di D3 tampil dengan teks persis (judul dan sumber), termasuk "Audio: EQuran.id (sumber: Verse By Verse Quran)", "Tempat turun surah: EQuran.id (sumber Kemenag)", dan "Pemetaan juz: Tanzil.info (metadata Tanzil, Creative Commons Attribution 3.0; kredit ke Tanzil.info, tautan lisensi https://creativecommons.org/licenses/by/3.0/, data diformat ulang)" dengan tautan ke lisensi; catatan yang menunggu Q6/Q7 tampil netral; teks OFL dibuka dari asset yang ada; tombol lisensi membuka halaman lisensi Flutter; tidak ada sumber yang tidak dipakai (tes konsistensi: tiap entri punya rujukan di PRD bagian 6); 130% teks, bisa digulir, tidak overflow.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: add sources and attribution screen`.

### Task 4: Ikon aplikasi dan splash (platform)

*(D4 diputuskan: placeholder sementara; aset final menyusul)*

**Files:** `android/app/src/main/res/mipmap-*`, `mipmap-anydpi-v26/ic_launcher.xml` (+ `ic_launcher_round.xml`), `drawable/ic_launcher_foreground.xml`/`background`/`monochrome`, `values/styles.xml`, `values-v31/styles.xml`, `values-night/*`, `drawable/launch_background.xml`; `AndroidManifest.xml` hanya bila nama ikon berubah.

- [ ] **Step 1:** Tulis daftar uji perangkat (tidak ada tes unit untuk resource): ikon di launcher terang/gelap, ikon bertema Android 13+, splash Android 12+ dan di bawahnya, tidak ada kilat putih di tema gelap.
- [ ] **Step 2:** Pasang aset dan XML; `flutter build apk --debug` berhasil.
- [ ] **Step 3: Commit** `feat: add app icon and splash` (platform, terpisah).

### Task 5: Konfigurasi rilis (platform)

**Files:** `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml` (izin sesuai D8), `android/app/proguard-rules.pro` bila perlu, `pubspec.yaml` (versi D6), `docs/release.md` (baru: langkah membuat keystore, `key.properties` contoh tanpa nilai nyata, perintah build, verifikasi tanda tangan, cadangan kunci), `.gitignore` bila perlu.

**Interfaces:** Produces: `signingConfigs.release` dari `key.properties`, tugas rilis yang gagal tanpa berkas itu, manifest tanpa izin yang tidak disetujui.

- [ ] **Step 1: Write the check**: skrip `tool/check_release_config.sh` (atau tes Dart yang membaca berkas) yang gagal bila: `build.gradle.kts` memakai `signingConfigs.getByName("debug")` untuk release, `key.properties`/`*.jks`/`*.keystore` terlacak git, atau manifest hasil gabungan memuat izin di luar daftar yang disetujui; jalankan dan lihat merah.
- [ ] **Step 2:** Implement signing, versi, penghapusan izin sesuai D8 (`tools:node="remove"`), aturan R8 bila perlu.
- [ ] **Step 3:** Buktikan: tanpa `key.properties` → `flutter build appbundle --release` gagal dengan pesan yang jelas; dengan keystore sekali pakai di luar repo (dibuat di direktori scratch) → AAB berhasil dan `jarsigner -verify` menunjukkan kunci itu (bukan debug); `bundletool get-size total` dicatat; `git status` bersih dari rahasia.
- [ ] **Step 4:** Bangun APK rilis dengan keystore sekali pakai, pasang di perangkat pemilik, daftar uji: widget (hadis dan ayat), notifikasi sholat dan harian, audio, deep link widget, dan setelan; hasil dilaporkan pemilik (R8, D12).
- [ ] **Step 5: Commit** `build: configure signed release builds` (platform, terpisah) dan `docs: add release guide`.

### Task 6: Tindak lanjut kecil

**Files:** sesuai D11 (a)–(d): `lib/app/data/sources/setting_keys.dart`, `sqlite_user_repository.dart`, kartu waktu sholat berikutnya, penghitungan last read di modul `quran_detail`.
- Test: tes yang ada diperbarui, tes baru per butir.

- [ ] **Step 1: Write the failing tests** per butir D11 yang disetujui pemilik: (a) tidak ada rujukan ke kunci yang dihapus; (b) `SqliteException` pada `SqliteUserRepository` menjadi error domain dan controller menampilkan state error, tidak crash; (c) kartu besok-hilang tidak menampilkan "-"; (d) last read hanya mencatat ayat yang ≥ 50% kartunya terlihat (kasus: ayat terlihat 30%, 50%, 90%; gulir cepat).
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** satu commit per butir.

### Task 7: Dokumen dan penyelesaian

**Files:** `docs/STATUS.md`, `docs/PRD.md` (hanya bila Pengaturan atau Sumber & Atribusi menyimpang; D1 tidak mengubah PRD), `docs/release/privacy-policy.md` (draf D9), `docs/specs/2026-11-09-nura-v1-design.md` (5.3 navigasi, 7.3, 8.3 sakelar di onboarding, bagian 11), `docs/design/*` bila ada catatan penyimpangan

- [ ] **Step 1:** `flutter analyze`, `flutter test`, `flutter build apk --debug`, dan `flutter build appbundle --release` (dengan keystore sekali pakai di luar repo) berhasil; ukuran AAB dicatat.
- [ ] **Step 2:** Perbarui STATUS: fase, keputusan D1–D12, daftar string UI baru untuk persetujuan, daftar uji perangkat (onboarding pada instalasi bersih dan pada instalasi yang sudah ada, Pengaturan menyalakan dan mematikan tiap sakelar, Sumber & Atribusi, ikon dan splash, build rilis), checklist syarat rilis (tabel di atas) dengan status terbaru, ukuran AAB, daftar izin akhir, draf Data Safety dan kebijakan privasi sebagai item pemilik.
- [ ] **Step 3: Commit** `docs: update status after phase 8`.

## Spec coverage

| Spec / PRD | Task |
|---|---|
| Spec 11 Fase 8: onboarding | 2 |
| PRD 5.7: onboarding tiga langkah, halaman Sumber & Atribusi | 2, 3 |
| Spec 5.3: layar Pengaturan (tema, font, Fitur Online, qari, sinkron jadwal, sumber hadis, Sumber & Atribusi) | 1, 3 |
| Pemindahan sakelar sementara (sheet baca, sheet harian) | 1 |
| Ikon dan splash (brief layar 1; ikon final di luar putaran 1) | 4 |
| PRD 7: ukuran AAB dicatat, atribusi lengkap | 5, 7 |
| Persiapan Play Store: build bertanda tangan, izin, Data Safety, kebijakan privasi | 5, 7 (D5, D8, D9) |
| Syarat rilis terbuka (Q2, Q3, Q6, Q7, Q8, Q9, Q12, sampel matan) | checklist, 7 |
| Tindak lanjut kecil dari STATUS | 6 |

---

## Tambahan keputusan pemilik (2026-11-22): Task 1 dan Task 3 dikerjakan sekarang

Hanya **Task 1 (Pengaturan terpusat)** dan **Task 3 (Sumber & Atribusi)** dikerjakan sekarang; task Fase 8 lainnya menunggu. Keputusan D1, D4, D8, D9 sudah tercatat di atas.

**Pengaturan terpusat (menggantikan butir D2 bila berbeda):** semua setelan pindah ke satu layar Pengaturan: tema; ukuran huruf Arab **dan terjemahan** (setelan baru: ukuran terjemahan dapat diatur; PRD 5.1 dan spec 5.6 yang menyatakan ukuran terjemahan tetap diperbarui); sakelar tampilkan terjemahan; Fitur Online dan qari; unduh jadwal sholat (sinkron); wilayah; pengingat per waktu sholat; notifikasi harian dan jamnya; sumber hadis harian (dengan keterangan derajat untuk 9 kitab); penyesuaian tanggal Hijriah (`hijri_adjust`, -1/0/+1). Sheet sementara di layar baca (pengaturan baca) dan sheet harian dihapus atau diarahkan ke Pengaturan. **Letak:** desain Putaran 1.5 tidak menentukan; spec 5.3 mendaftar "Pengaturan" sebagai layar sendiri dan navigasi bawah tetap 4 item, jadi dibuka dari ikon di header (hero) Beranda yang menggantikan ikon `tune`; dilaporkan ke pemilik.

**Sumber & Atribusi (di dalam Pengaturan, bagian Tentang):** Kementerian Agama RI (teks, terjemahan, tafsir Al-Qur'an); gadingnst/hadith-api (MIT) dengan data asal tafsirq.com; EQuran.id (jadwal sholat dari Bimas Islam Kemenag, audio dari Verse By Verse Quran, tempat turun surah); Tanzil.info (batas juz, Creative Commons Attribution 3.0 dengan tautan lisensi); font Plus Jakarta Sans dan Scheherazade New (OFL); Material Symbols (Apache 2.0); halaman lisensi paket Flutter (`showLicensePage`). Daftar teks UI baru ditampilkan untuk persetujuan pemilik.
