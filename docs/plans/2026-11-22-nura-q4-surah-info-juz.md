# Nura Q4: Tempat Turun dan Juz: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengisi tempat turun 114 surah (equran.id, data Kemenag) dan pemetaan 30 juz (metadata Tanzil, CC BY 3.0) lewat berkas meta di `data-source/meta/`, memverifikasinya otomatis di skrip dan verifier, lalu menampilkannya di header surah, daftar surah, dan tab Juz. Plus verifikasi perilaku timer `HomeController` saat controller dihapus dan dibuat ulang (fenix).

**Architecture:** Dua skrip pengambil data (`tool/fetch_surah_info.dart`, `tool/fetch_juz.dart`) mengikuti pola `tool/fetch_prayer_regions.dart` (snapshot ber-`fetched_at`, transport HTTP yang diuji dengan server loopback). Builder `lib/content_pipeline/content_db_builder.dart` sudah membaca `meta/surah_info.json` (`number`, `revelation`) dan `meta/juz.json` (`number`, `start_surah`, `start_ayah`, `end_surah`, `end_ayah`) ke tabel `surah.revelation` dan `juz`; **skema `content.db` tidak berubah**. Verifier diperketat. UI hanya membaca data yang sudah ada di repository (`Surah.revelation`, daftar juz).

**Tech Stack:** Dart (skrip tool, `HttpClient`), SQLite, Flutter/GetX. Tanpa paket baru.

**Spec:** `docs/PRD.md` (bagian 6 sumber data, 5.1 daftar surah dan tab Juz), `docs/STATUS.md` (Q4), `data-source/README.md`, `AGENTS.md` (aturan 1, 2, 5, 6, 7), `docs/plans/2026-11-17-nura-phase8-polish.md` (daftar Sumber & Atribusi).

## Keputusan pemilik (2026-11-22)

a. Tempat turun: sumber equran.id (data Kemenag), `GET https://equran.id/api/v2/surat`. Diperiksa 2026-11-22: ada field `tempatTurun` untuk 114 surah, nilai `Mekah` (84) dan `Madinah` (30). Petakan ke `makkiyah`/`madaniyah` (nilai yang diterima builder), simpan snapshot `data-source/meta/surah_info.json` dengan `fetched_at`, laporkan jumlah masing-masing; berhenti dan laporkan bila ada surah tanpa nilai.
b. Juz: equran.id tidak menyediakan batas juz (`/api/v2/juz` 404; `surat/{n}` tanpa field juz). Dipakai metadata Tanzil `https://tanzil.net/res/text/metadata/quran-data.xml` (30 elemen `<juz index sura aya>`; header: `copyright="(C) 2008-2009 Tanzil.info" license="cc-by"`, `quran-data.js`: "License: Creative Commons Attribution 3.0"). Catat teks lisensi dan syarat atribusi di `data-source/README.md`. Simpan `data-source/meta/juz.json` (format builder). Verifikasi otomatis di skrip dan verifier: tepat 30 juz, tidak tumpang tindih, menutup 6.236 ayat berurutan, batas acuan juz 2 = 2:142, juz 15 = 17:1, juz 30 = 78:1.
c. Untuk keduanya: perbarui `CHECKSUMS.sha256`, jalankan `tool/prepare_content.sh`, `verify --full` lulus tanpa warning revelation, isi header surah dan tab Juz, tambahkan sumber ke daftar Sumber & Atribusi Fase 8. **Bila skema `content.db` harus berubah, berhenti dan tanya pemilik.**
d. Verifikasi perilaku timer `HomeController` saat dihapus lalu dibuat ulang (fenix): timer lama dibatalkan di `onClose` dan tidak berjalan ganda; tambahkan tes.

## Global Constraints

- Kode Inggris, teks pengguna Indonesia. Tanpa `ignore_for_file`, hindari `!`. `flutter analyze` bersih, `flutter test` lulus sebelum tiap commit. Satu topik per commit (Conventional Commits Inggris; commit data memakai tipe `data:`). Jangan merge, jangan push.
- Aturan Mutlak: jangan edit file sumber yang sudah ada di `data-source/` (hanya berkas meta baru atas keputusan pemilik di atas, dan baris README/CHECKSUMS); jangan edit atau meng-commit `assets/db/content.db`/`content.version` (dihasilkan `tool/prepare_content.sh`); jangan mengarang data (nilai hanya dari sumber yang disebut; nilai tak dikenal = berhenti dan laporkan); atribusi sumber tidak dihapus.
- Setiap klien HTTP baru wajib punya minimal satu tes terhadap transport asli (server loopback `HttpServer`, tanpa internet) yang memeriksa metode, header, dan penanganan status (AGENTS.md).
- Akses jaringan hanya di skrip `tool/` (dijalankan manual pengembang), bukan di aplikasi.
- Teks UI baru hanya "Makkiyah" dan "Madaniyah" (nilai tempat turun) dan teks rentang juz yang tertulis di Task 2; laporkan semuanya.

## Review Focus

1. **Pemetaan tempat turun**: hanya `Mekah`→`makkiyah` dan `Madinah`→`madaniyah`; nilai lain atau surah hilang/duplikat menghentikan skrip (tidak ada nilai bawaan); `fetched_at` tercatat; jumlah 84/30 dilaporkan; perbandingan dengan Tanzil (`type` Meccan/Medinan) dicatat sebagai informasi bila berbeda (jangan menimpa).
2. **Batas juz**: ujung juz = ayat sebelum awal juz berikutnya (memakai jumlah ayat per surah dari `data-source/quran`), juz 30 berakhir di 114:6 (akhir data); lintas-surah dan awal surah (ayat 1) benar; urutan 6.236 ayat tanpa celah/tumpang tindih; tes menolak data rusak (celah, tumpang tindih, 29 atau 31 juz, batas acuan salah).
3. **Integritas data**: `CHECKSUMS.sha256` mencakup berkas baru dan berkas lama tidak berubah; `prepare_content.sh` lulus penuh; builder tidak menghasilkan warning revelation; tidak ada perubahan skema.
4. **Lisensi dan atribusi**: teks lisensi CC BY 3.0 Tanzil dan syaratnya (atribusi, tautan) tercatat di README dan di daftar Sumber & Atribusi; sumber tempat turun (equran.id, data Kemenag) juga.
5. **UI tanpa placeholder**: header, daftar surah, dan tab Juz tidak lagi menampilkan "[Q4]" untuk data yang kini ada; keadaan kosong tetap ditangani (data tidak ada → teks aman, tidak crash); mengetuk juz membuka ayat awalnya.
6. **Timer fenix**: tidak ada timer ganda atau bocor setelah delete lalu recreate; `onClose` membatalkan semuanya.

---

### Task 1: Data tempat turun dan juz (skrip, verifier, data, checksum)

**Files:** Create `tool/fetch_surah_info.dart`, `tool/fetch_juz.dart` (pola `tool/fetch_prayer_regions.dart`), `data-source/meta/surah_info.json`, `data-source/meta/juz.json`; Modify `lib/content_pipeline/content_db_verifier.dart` (cek juz, revelation), `lib/content_pipeline/content_db_builder.dart` hanya bila format `fetched_at` memerlukannya, `data-source/README.md`, `data-source/CHECKSUMS.sha256`; Test `test/tool/fetch_surah_info_test.dart`, `fetch_juz_test.dart`, tes verifier/builder yang ada.

**Interfaces:** Produces: fungsi murni untuk mengurai tempat turun dan menyusun juz (mis. `parseSurahInfo(String json)` dan `buildJuz(starts, ayahCounts)`) yang diuji tanpa jaringan; HTTP lewat fungsi dengan transport injeksi dan satu tes loopback tiap skrip (metode GET, header, status non-200, badan rusak, timeout). Format berkas: ikuti `fetch_prayer_regions.dart` untuk penyertaan `fetched_at`; builder membaca `surah_info.json` sebagai daftar `{number, revelation}` dan `juz.json` sebagai daftar `{number, start_surah, start_ayah, end_surah, end_ayah}`; bila `fetched_at` harus ada, letakkan sehingga builder tetap menerima format (ubah pembacaan builder secara minimal dan teruji bila perlu, tanpa mengubah skema).

- [ ] **Step 1: Write failing tests**: parse tempat turun (Mekah, Madinah; nilai asing, hilang, duplikat, 113 atau 115 surah → galat); jumlah 84 dan 30 dari fixture cuplikan respons nyata; `buildJuz` dengan 30 awal juz Tanzil dan jumlah ayat dari `data-source/quran`: 30 juz, tanpa celah/tumpang tindih, menutup 6.236 ayat, juz 2 = 2:142, juz 15 = 17:1, juz 30 = 78:1 dan berakhir di 114:6; data rusak (hilang satu juz, urutan salah, awal melewati akhir surah) ditolak; tes loopback tiap skrip; verifier: gagal bila juz ≠ 30, tumpang tindih, celah, batas acuan salah, revelation kosong/tak dikenal.
- [ ] **Step 2–4: Run fail, implement, run pass.** Jalankan skrip sungguhan sekali (jaringan) untuk menghasilkan berkas data; periksa hasil (jumlah, nilai acuan).
- [ ] **Step 5:** Perbarui `data-source/README.md` (sumber, tanggal ambil, teks lisensi CC BY 3.0 Tanzil dan syaratnya, tautan lisensi, sumber equran.id/Kemenag), `CHECKSUMS.sha256`, jalankan `tool/prepare_content.sh` (lulus, tanpa warning revelation), `flutter test`.
- [ ] **Step 6: Commit** `feat: add surah info and juz fetch tools` (skrip + tes + verifier) dan `data: add surah_info and juz meta sources` (data + README + checksums).

### Task 2: Tampilkan tempat turun dan juz di UI

**Files:** Modify header surah (`lib/app/modules/quran_detail/widgets/surah_header_card.dart`), daftar surah (`lib/app/modules/quran_list/widgets/surah_list_item.dart`), tab Juz (`juz_list_item.dart`, `views/quran_list_view.dart`, controller), repository bila perlu (daftar juz dari tabel `juz`, read-only); Test di `test/app/modules/quran_list/`, `quran_detail/`, repository.

**Interfaces:** Consumes: `Surah.revelation` (`makkiyah`/`madaniyah`), tabel `juz`. Produces: `String revelationLabel(String)` → "Makkiyah"/"Madaniyah" (kosong → teks netral tanpa "[Q4]"); `JuzListItem`: badge nomor juz, "Juz N", rentang (mis. "Al-Fatihah 1 – Al-Baqarah 141" memakai nama Latin surah dari data), chevron; ketuk membuka `Routes.surah` dengan `SurahArgs(surah awal, ayat awal)`. Baris sekunder item surah dan nilai header menampilkan tempat turun menggantikan "[Q4]".

- [ ] **Step 1: Write failing tests**: label tempat turun (kedua nilai; kosong tidak crash); header menampilkan nilai di `onHeroAccent` (bukan "[Q4]"); item surah memuat tempat turun; tab Juz menampilkan 30 item dengan rentang benar untuk juz 1, 2 (2:142), 15 (17:1), 30 (78:1) dari data nyata; ketuk membuka ayat awal; 130% tanpa overflow; keadaan kosong/galat repository ditangani; tidak ada teks "[Q4]" tersisa di `lib/` untuk data ini (grep di tes).
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: show revelation place and juz list`.

### Task 3: Timer HomeController saat fenix, dan dokumen

**Files:** Test `test/app/modules/home/home_controller_fenix_test.dart`; Modify `lib/app/modules/home/controllers/home_controller.dart` hanya bila ada bug yang terbukti; `docs/plans/2026-11-17-nura-phase8-polish.md` (daftar Sumber & Atribusi D3), `docs/PRD.md` (tabel sumber: info surah dan juz), `docs/STATUS.md`.

- [ ] **Step 1: Write failing tests** (fake clock/timer): hapus (`Get.delete<HomeController>(force: true)`) lalu buat ulang lewat `fenix`; timer menit dan tengah malam pada instance lama tidak lagi aktif setelah `onClose` (tidak memicu pemuatan), instance baru punya tepat satu timer menit dan satu timer tengah malam, hero hanya diperbarui oleh instance baru, tidak ada observer lifecycle ganda (pause/resume memicu tepat satu rebuild per instance aktif).
- [ ] **Step 2:** Bila ada tes yang gagal karena bug nyata, perbaiki akar penyebab; bila lulus, itu bukti dan cukup tes.
- [ ] **Step 3:** Dokumen: tambahkan sumber ke daftar Sumber & Atribusi Fase 8 (D3: "Tempat turun surah: EQuran.id (sumber Kemenag)"; "Pemetaan juz: Tanzil (Creative Commons Attribution 3.0)"), PRD bagian 6 (info surah dan juz tidak lagi "belum dipilih"), STATUS (Q4 sebagian tertutup: info surah dan juz selesai; koordinat per kab/kota untuk cadangan offline masih terbuka; hasil verifikasi timer; daftar teks UI baru; checklist uji perangkat: header surah, daftar surah, tab Juz 30 item dan navigasi, atribusi tercatat).
- [ ] **Step 4: Commit** `test: pin home controller timers across fenix recreation` dan `docs: record surah info and juz sources`.
