# Nura Fase 8 Lanjutan: Tab Pengaturan, Rujukan Hadis, Pratinjau, url_launcher: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menjadikan Pengaturan tab kelima di bilah bawah (menghapus ikon pengaturan di Beranda), memakai nama pendek kitab di semua rujukan hadis, memperluas aturan pratinjau ke kutip tunggal (hanya bila kutip penutupnya ada), dan membuat tautan lisensi dan sumber dapat dibuka dengan `url_launcher` (dengan cadangan: URL ditampilkan agar bisa disalin).

**Architecture:** Hanya lapisan tampilan, konstanta, dan satu paket baru yang disetujui (`url_launcher`). Perubahan `AndroidManifest.xml` (deklarasi `queries`) dipisah di commit platform tersendiri (AGENTS.md aturan 8).

**Tech Stack:** Flutter, GetX, `url_launcher` (baru, disetujui pemilik 2026-11-23).

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` 5.3 (navigasi; diperbarui), `docs/design/HANDOFF-flutter.md` dan brief (4 tab; penyimpangan dicatat), `docs/plans/2026-11-22-nura-hadith-ui.md`, `docs/plans/2026-11-17-nura-phase8-polish.md`, `AGENTS.md`.

## Global Constraints

- Kode Inggris, teks pengguna Indonesia. Tanpa `ignore_for_file`, hindari `!`. `flutter analyze` bersih, `flutter test` lulus sebelum tiap commit. Satu topik per commit (Conventional Commits Inggris); **perubahan `android/` di commit terpisah**. Jangan push.
- Teks Arab/terjemahan dari data tidak diubah; tanpa perubahan skema; tidak ada akses jaringan baru dari aplikasi (membuka tautan dilakukan pengguna lewat aplikasi lain).
- Teks UI baru hanya yang tertulis di task; laporkan semuanya.

## Keputusan pemilik (2026-11-23)

1. Tab kelima "Pengaturan" setelah Sholat berisi layar Pengaturan yang ada; ikon pengaturan di Beranda dihapus (tidak dobel); uji label di 360×640 dengan teks 130%; bila terpotong pakai "Setelan" dan laporkan; catat penyimpangan dari desain Putaran 1.5 (4 tab) di STATUS dan spec 5.3.
2. Rujukan hadis memakai nama pendek: HR. Bukhari, HR. Muslim, HR. Abu Daud, HR. Tirmidzi, HR. Nasa'i, HR. Ibnu Majah, HR. Ahmad, HR. Malik, HR. Darimi.
3. Pratinjau: kutip tunggal diperlakukan sama dengan kutip ganda, hanya bila kutip penutupnya ada; bila tidak, pratinjau dari awal teks. Dengan tes.
4. `url_launcher` disetujui untuk tautan lisensi dan sumber; tambahkan deklarasi `queries` di AndroidManifest untuk Android 11+; bila tautan tidak bisa dibuka, tampilkan URL agar bisa disalin.

## Review Focus

1. **Tab Pengaturan**: indeks tab dan `IndexedStack` benar; `SettingsController` hidup lintas rute (fenix; kelas bug controller yang dibuat saat rute lain aktif); membuka Pengaturan dari layar baca (rute `/settings`) dan dari tab tidak saling mengganggu; kembali dari Pengaturan menyegarkan layar baca; tidak ada tombol kembali palsu di tab; label tidak terpotong di 360×640 pada 130%; ikon Beranda benar-benar hilang (termasuk tes lama).
2. **Rujukan hadis**: SATU sumber untuk "HR. <nama pendek> No. <n>" dipakai di semua tempat yang menampilkan atau menyalin rujukan (detail, salin ke papan klip, kartu harian, widget, notifikasi harian, hasil pencarian/bookmark bila ada); slug tak dikenal tidak melempar; "Nasa'i" memuat apostrof persis.
3. **Pratinjau kutip tunggal**: apostrof di dalam kata (Ya'qub, 'Ulayyah) bukan kutip penutup; kutip penutup berupa kutip tunggal yang tidak di antara dua huruf; kutip ganda tidak berubah perilaku; hitung dampak pada data nyata (berapa dari 796 hadis kini berpratinjau dari kutipan).
4. **url_launcher**: tidak ada pembukaan tanpa ketukan pengguna; hanya skema `https`; kegagalan (tidak ada browser, `canLaunchUrl` false, galat) menampilkan URL yang bisa disalin, bukan galat mentah; deklarasi `queries` minimal dan benar untuk Android 11+.

---

### Task 1: Tab kelima Pengaturan

**Files:** Modify `lib/app/modules/shell/views/shell_view.dart` (+ controller/binding bila perlu), `lib/app/modules/home/widgets/home_hero.dart`/`home_view.dart` (hapus ikon Pengaturan dan `_openSettings`), `lib/app/modules/settings/**` (tampil sebagai tab: tanpa tombol kembali; tetap bisa dibuka sebagai rute dari layar baca), `lib/app/core/nura_icons.dart` bila perlu, `docs/specs/2026-11-09-nura-v1-design.md` 5.3, `docs/STATUS.md`; Test `test/app/modules/shell/`, `test/app/modules/settings/`, `test/app/modules/home/`.

**Interfaces:** Produces: destinasi kelima `NavigationDestination(label: 'Pengaturan', icon: NuraIcons.settings)`; bila label terpotong pada 360×640 dengan teks 130% (ukur lewat tes layout dengan font tema, bukan hanya Ahem: lebar sel `NavigationBar` 360/5 = 72 dp), gunakan "Setelan" dan laporkan; `SettingsView` dipakai di tab (tanpa AppBar yang menampilkan panah kembali; judul halaman tetap) dan di rute `/settings`.

- [ ] **Step 1: Write failing tests**: bilah bawah punya 5 destinasi berurutan Beranda, Al-Qur'an, Hadis, Sholat, Pengaturan; memilih tab kelima menampilkan layar Pengaturan; label tidak terpotong pada 360×640 dengan teks 130% (jika gagal pakai "Setelan" dan tes yang sama lulus dengan label itu); ikon Pengaturan di hero Beranda tidak ada; membuka rute `/settings` dari layar baca surah dan juz masih berfungsi dan kembali ke layar baca dengan prefs baru; perubahan di tab Pengaturan langsung terlihat di tab lain (Sholat, Beranda) tanpa duplikasi controller; GetX: `SettingsController` tidak terhapus saat rute lain ditutup (tes navigasi nyata seperti `tab_controllers_lifetime_test.dart`); skala teks 130% tanpa overflow pada tab.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5:** Perbarui spec 5.3 (lima tab; keputusan pemilik 2026-11-23; penyimpangan dari Putaran 1.5 yang 4 tab) dan STATUS (catat penyimpangan desain; label yang dipakai; hasil uji lebar label).
- [ ] **Step 6: Commit** `feat: add settings as fifth bottom tab`.

### Task 2: Rujukan hadis dengan nama pendek dan pratinjau kutip tunggal

**Files:** Modify tempat `hadithBookNames` berada (`lib/content_pipeline/content_schema.dart`) atau helper baru di `lib/app/core/hadith_reference.dart`; semua pemakai rujukan: grep `HR\.` dan `referenceLabel` di `lib/` (detail hadis + salin, `sqlite_daily_content_repository.dart`, kartu harian, widget, notifikasi harian, pencarian/bookmark), `lib/app/modules/hadith_list/hadith_preview.dart`; Test `test/app/**` terkait.

**Interfaces:** Produces: `const Map<String, String> hadithBookNamesShort` (bukhari 'Bukhari', muslim 'Muslim', abu-daud 'Abu Daud', tirmidzi 'Tirmidzi', nasai "Nasa'i", ibnu-majah 'Ibnu Majah', ahmad 'Ahmad', malik 'Malik', darimi 'Darimi') dan `String hadithReference(String slug, int number)` = `HR. <nama pendek> No. <n>` (slug tak dikenal → slug apa adanya, tanpa melempar); `hadithPreview` menerima pembuka kutip tunggal (`'` dan `‘`) hanya bila ada kutip penutup tunggal setelahnya yang bukan apostrof di dalam kata (tidak di antara dua huruf); jika tidak ada penutup, pratinjau dari awal teks; kutip ganda tidak berubah.

- [ ] **Step 1: Write failing tests**: sembilan nama pendek persis (termasuk "Nasa'i"); `hadithReference` untuk semua slug dan slug tak dikenal; setiap tempat yang menampilkan atau menyalin rujukan memakainya (tes salin detail: teks asli + `HR. Bukhari No. 1`, mengganti string lama yang dikunci tes; kartu harian; notifikasi harian bila memuat rujukan); pratinjau: `bersabda: 'Isi hadis.'` mulai dari isi; kutip tunggal tanpa penutup → dari awal; apostrof dalam kata (`Ya'qub`) tidak dianggap penutup (pratinjau dari awal bila tidak ada penutup lain); kutip penutup `’`; kutip ganda tidak berubah; teks terpotong di dalam kutipan tunggal → dari awal; dampak pada data nyata: hitung dan lampirkan di laporan berapa hadis (dari 796) kini berpratinjau dari kutipan; 19 hadis terpotong tidak melempar.
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: use short book names in hadith references` dan `feat: treat single quotes as quotation in hadith preview`.

### Task 3: url_launcher untuk tautan lisensi dan sumber

**Files:** Modify `pubspec.yaml` (`url_launcher`), `lib/app/modules/settings/views/attribution_view.dart` (+ widget tautan), `lib/app/core/attributions.dart` bila perlu; **commit platform terpisah**: `android/app/src/main/AndroidManifest.xml` (blok `<queries>` dengan intent `VIEW` skema `https` sesuai dokumentasi url_launcher untuk Android 11+); Test `test/app/modules/settings/`.

**Interfaces:** Produces: widget tautan: ketukan memanggil `launchUrl(uri, mode: LaunchMode.externalApplication)` hanya untuk skema `https`; bila `canLaunchUrl` false, `launchUrl` mengembalikan false atau melempar → tampil URL yang bisa disalin (bottom sheet atau snackbar berisi `SelectableText` + tombol salin; pakai teks UI yang sudah ada bila ada, selain itu laporkan); tetap menampilkan URL sebagai teks yang bisa dipilih. Peluncur diinjeksi lewat antarmuka tipis (`UrlOpener`) agar diuji tanpa platform.

- [ ] **Step 1: Write failing tests** (`UrlOpener` tiruan): ketukan tautan memanggil peluncur sekali dengan URL benar dan mode eksternal; skema bukan `https` tidak diluncurkan; gagal (false/lempar) menampilkan URL yang bisa disalin dan tombol salin menyalin ke papan klip; tidak ada peluncuran tanpa ketukan; semua tautan di entri atribusi (Tanzil lisensi CC, equran terms, dst.) terhubung; 130% tanpa overflow, target sentuh ≥ 48 dp.
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: open attribution links with url_launcher` (pubspec + kode) dan **terpisah** `build: declare https queries for url launcher` (manifest). Verifikasi manifest hasil gabungan memuat `queries` dengan `flutter build apk --debug` dan catat dampak ukuran paket.

### Task 4: Penyelesaian

- [ ] **Step 1:** `flutter analyze`, `flutter test`, `flutter build apk --debug`.
- [ ] **Step 2:** STATUS: hasil uji perangkat pemilik (Pengaturan, Sumber & Atribusi, pembaca juz, layar hadis sesuai, 2026-11-23), keputusan 1–4, penyimpangan desain 5 tab, teks UI baru, checklist uji perangkat (tab Pengaturan di 360 dp dan teks 130%; ikon Beranda hilang; rujukan hadis nama pendek di detail, salinan, kartu harian, notifikasi; pratinjau kutip tunggal; tautan lisensi dan sumber terbuka di browser dan cadangan URL bila tidak ada browser).
- [ ] **Step 3: Commit** `docs: update status after phase 8 follow-ups`.
