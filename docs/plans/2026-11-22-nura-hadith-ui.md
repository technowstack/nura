# Nura Tampilan Hadis (Varian A): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menerapkan varian A ("Kartu") untuk daftar hadis dan detail hadis, ditambah nama Arab kitab, aturan pratinjau daftar dari kutipan sabda, perbaikan kecil kartu hadis harian, dan perbaikan tes audio yang flaky.

**Architecture:** Hanya lapisan tampilan dan satu konstanta; tidak ada perubahan skema `content.db`, `data-source/`, atau repository. Pratinjau dihitung di view-model daftar (fungsi murni), detail tetap memakai teks lengkap. Komponen yang dipakai ulang: `NuraCard`, `OrnamentBadge`, `NuraIcons`, sel aksi gaya `AyahActionBar`, kartu hero gaya `SurahHeaderCard`.

**Tech Stack:** Flutter, GetX; font Plus Jakarta Sans dan Scheherazade New (sudah ada). Tidak ada paket baru.

**Spec:** gambar acuan `docs/review/hadith-variants/{light,dark}/{kitab,daftar-A,detail-A,harian}-*.png` dan `docs/review/hadith-variants/README.md` (varian A dipilih pemilik 2026-11-22, termasuk paritas fungsi), `docs/design/HANDOFF-flutter.md`, `docs/design/tokens.json`, `AGENTS.md`.

## Global Constraints

- Kode Inggris, teks pengguna Indonesia. Tanpa `ignore_for_file`, hindari `!`. `flutter analyze` bersih dan `flutter test` lulus sebelum tiap commit. Satu topik per commit (Conventional Commits Inggris). Jangan merge, jangan push.
- Nilai warna/ukuran hanya dari token. Teks Arab dan terjemahan dari data tidak diubah (Aturan Mutlak 3); pratinjau hanya memotong untuk tampilan. Tanpa perubahan skema, tanpa jaringan baru, tanpa paket baru.
- Teks UI baru hanya yang tertulis di task (label hero "Kitab", "Nomor", "Jumlah hadis" sudah ada di README varian); laporkan sisanya.
- Fungsi yang ada tidak berubah: bookmark (toggle), salin (+ rujukan "HR. Kitab No. n"), Sebelumnya/Berikutnya (nonaktif di ujung), catatan "Teks hadis ini terpotong di sumber data", loading/kosong/error. "Bagikan" tidak dibuat (Fase 8). 48 dp, skala teks 130% tanpa overflow.

## Keputusan pemilik (2026-11-22)

1. Varian A untuk daftar dan detail. 2. Nama Arab kitab sebagai konstanta (bukhari صحيح البخاري, muslim صحيح مسلم, abu-daud سنن أبي داود, tirmidzi سنن الترمذي, nasai سنن النسائي, ibnu-majah سنن ابن ماجه, ahmad مسند أحمد, malik موطأ مالك, darimi سنن الدارمي), sejajar dengan nama Latin, di daftar kitab dan header detail. 3. Pratinjau daftar: bila terjemahan memuat "bersabda:" diikuti tanda kutip, mulai dari isi kutipan; bila tidak, dari awal teks; hanya di lapisan tampilan; tes untuk kedua kasus dan untuk 19 hadis terpotong (Q12: daftar di STATUS); detail tetap teks lengkap. 4. Usulan kartu harian di README: kerjakan bila tidak mengubah perilaku, laporkan bila mengubah. 5. Selidiki `audio_player_service_test` yang gagal sekali saat paralel; perbaiki penyebab, bukan jeda atau retry.

## Review Focus

1. **Aturan pratinjau**: "bersabda:" tanpa kutip, kutip pembuka berbagai bentuk (`"`, `“`), kutipan kosong, "bersabda:" di ujung teks terpotong, beberapa kemunculan (pakai yang pertama), spasi/baris baru setelah ":", 19 hadis terpotong (tidak boleh melempar atau menghasilkan pratinjau kosong; bila kutipan kosong/terpotong jatuh ke awal teks).
2. **Nama Arab**: sama persis dengan teks pemilik (periksa titik kode); sembilan slug tercakup; slug tak dikenal tidak melempar (Arab disembunyikan); font dari tema, bukan literal.
3. **Paritas detail**: aksi pindah dari app bar ke sel aksi tanpa menghilangkan fungsi; salin tetap berisi teks asli + rujukan; teks panjang (Bukhari No. 3, ±3.329 karakter Arab) tidak overflow dan menggulir.
4. **Tes audio**: akar penyebab flaky (memindai direktori temp bersama), perbaikan dengan isolasi, bukan jeda/retry.

---

### Task H1: Nama Arab kitab dan daftar kitab

**Files:** Modify tempat `hadithBookNames` berada (grep), `lib/app/modules/hadith_books/widgets/hadith_book_tile.dart`, `views/hadith_books_view.dart`; Test `test/app/modules/hadith_books/`.

**Interfaces:** Produces: `const Map<String, String> hadithBookNamesArab` (slug → nama Arab, sembilan entri persis) dan `String? hadithBookNameArab(String slug)`; `HadithBookTile` = `NuraCard`: kiri ikon `NuraIcons.menuBook` (iconAccent; tambah konstanta bila belum ada), tengah nama Latin (titleMedium) dan "N hadis" (format ribuan yang ada), kanan nama Arab (`arabicTitle`, iconAccent, RTL, Flexible) + chevron. Acuan: `kitab-light.png`/`kitab-dark.png`.

- [ ] **Step 1: Write failing tests**: kesembilan nama Arab sama persis dengan daftar pemilik (bandingkan literal pada tes); slug tak dikenal → null dan tile tanpa teks Arab tanpa error; tile memuat nama Latin, jumlah, nama Arab (font dari tema), chevron; ketuk membuka daftar kitab itu; token Light dan Dark; 130% tanpa overflow pada 360×640.
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: add arabic book names and restyle hadith books`.

### Task H2: Daftar hadis varian A dan aturan pratinjau

**Files:** Modify `lib/app/modules/hadith_list/controllers/hadith_list_controller.dart` (pratinjau di `HadithListItem`), `widgets/hadith_list_tile.dart`, `views/hadith_list_view.dart`; Create `lib/app/modules/hadith_list/hadith_preview.dart`; Test `test/app/modules/hadith_list/`.

**Interfaces:** Produces: `String hadithPreview(String translation, {int maxChars = 200})` (aturan pemilik; memotong dengan elipsis seperti pratinjau sekarang; tidak mengubah teks sumber). Kartu: `NuraCard`: kiri `OrnamentBadge(label: nomor)`, nama kitab kecil (iconAccent, labelMedium), pratinjau 3 baris, ikon bookmark terisi (primary) di kanan bila ditandai (slot bookmark dicadangkan di semua kartu). Acuan: `daftar-A-light.png`/`daftar-A-dark.png`.

- [ ] **Step 1: Write failing tests** (fungsi murni): "…bersabda: \"Tidaklah beriman…\"" mulai dari isi kutipan; kutip `“…”`; tanpa "bersabda:" → dari awal; "bersabda:" tanpa kutip → dari awal; kutipan kosong; kemunculan ganda memakai yang pertama; "Bersabda:" huruf besar; spasi/baris baru setelah titik dua; teks terpotong tepat di "bersabda:" atau di dalam kutipan; panjang maksimum dan elipsis; **19 hadis terpotong**: ambil daftarnya dari STATUS Q12 (dan berkas yang dirujuknya), muat teks dari `data-source/hadith/*.json`, pastikan `hadithPreview` tidak melempar, tidak kosong, dan substring dari terjemahan (kecuali elipsis); widget: kartu memuat badge, nama kitab, pratinjau, bookmark terisi; 130% tanpa overflow; detail tetap menerima teks lengkap (controller detail tidak memakai fungsi ini).
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: restyle hadith list as cards with matan preview`.

### Task H3: Detail hadis varian A

**Files:** Modify `lib/app/modules/hadith_detail/views/hadith_detail_view.dart`, `widgets/hadith_text_card.dart`, controller bila perlu; Create bila perlu `widgets/hadith_hero_card.dart`; Test `test/app/modules/hadith_detail/`.

**Interfaces:** Produces: kartu hero (`hero`/`onHero`/`onHeroAccent`, gaya `SurahHeaderCard`): kiri label "Kitab", "Nomor", "Jumlah hadis" dengan nilai onHeroAccent, kanan nama Arab kitab (`arabicHero`, bila ada); lalu kartu Arab (RTL, ukuran pembaca), kartu terjemahan, baris rujukan "HR. <Kitab singkat> No. <n>" (iconAccent), sel aksi salin dan bookmark (sama lebar, tinggi 48, latar surfaceContainerLow, radius md, ikon iconAccent; bookmark terisi primary; tooltip/semantik yang ada), lalu Sebelumnya/Berikutnya (nonaktif di ujung), catatan teks terpotong di bawah kartu terjemahan. Aksi di app bar pindah ke sel aksi; app bar tetap judul + nomor. Acuan: `detail-A-light.png`/`detail-A-dark.png`.

- [ ] **Step 1: Write failing tests**: hero memuat kitab/nomor/jumlah dan nama Arab; slug tak dikenal tanpa Arab; salin menyalin teks asli + "HR. Kitab No. n" persis seperti sebelum perubahan; bookmark toggle dan keadaan terisi; prev/next dan nonaktif di ujung; catatan terpotong hanya bila terpotong; teks panjang (Bukhari No. 3) menggulir tanpa overflow pada 360×640 dan 130%; token Light dan Dark; loading/kosong/error tidak berubah. Tes yang ada tidak dilemahkan.
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: restyle hadith detail as cards`.

### Task H4: Kartu hadis harian dan tes audio flaky

**Files:** Modify `lib/app/modules/home/widgets/daily_card.dart` (hanya kartu Hadis), tes audio ("no files are written", cari dengan grep); Test terkait.

- [ ] **Step 1 (kartu harian):** usulan README: rujukan dan "Baca selengkapnya" dalam satu baris (rujukan kiri memotong dengan elipsis, tautan kanan). Kerjakan bila tidak mengubah perilaku (ketuk, teks, semantik); bila mengubah, jangan kerjakan dan laporkan. Tes: kedua elemen ada, satu baris pada 360 dp, rujukan panjang tidak overflow, 130%.
- [ ] **Step 2 (audio flaky):** buktikan penyebab (tes memindai direktori temp sistem yang dipakai bersama tes lain secara paralel), lalu perbaiki dengan isolasi (mis. `IOOverrides.runZoned` dengan `getSystemTempDirectory` ke direktori privat tes) agar tulisan tes lain tidak terhitung; jangan menambah jeda atau retry; uji negatif: tes harus gagal bila layanan benar-benar menulis berkas ke temp yang diisolasi.
- [ ] **Step 3: Commit** `feat: put daily hadith reference and read-more on one line` (bila dikerjakan) dan `test: isolate temp directory in audio player service test`.

### Task H5: Penyelesaian

**Files:** `docs/STATUS.md`, `docs/review/hadith-variants/README.md` (catatan: varian A dipilih).

- [ ] **Step 1:** `flutter analyze`, `flutter test`, `flutter build apk --debug`.
- [ ] **Step 2:** STATUS: keputusan pemilik, teks UI baru, checklist uji perangkat layar hadis (daftar kitab Arab/Latin; daftar hadis kartu dan pratinjau dari kutipan untuk beberapa kitab dan satu hadis terpotong; detail hadis pendek dan panjang, hero, salin, bookmark, prev/next; kartu harian satu baris; Light dan Dark; 130%).
- [ ] **Step 3: Commit** `docs: update status after hadith ui`.
