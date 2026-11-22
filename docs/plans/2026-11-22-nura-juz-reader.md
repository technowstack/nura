# Nura Pembaca per Juz: Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengetuk sebuah juz di tab Juz menampilkan seluruh ayat juz itu, dari ayat awal sampai akhir, menyeberang antar surah, dengan header surah (dan Basmalah sesuai aturan yang sudah ada) setiap kali masuk surah baru; memakai ulang komponen layar baca surah (kartu ayat, penanda ۝, menu ⋯, bilah aksi, bookmark, tafsir); last read menyimpan surah dan ayat yang sebenarnya; audio "Putar" memutar sampai akhir juz.

**Architecture:** Query rentang `(surah, ayat)` sampai `(surah, ayat)` dijalankan di worker isolate (pola `IsolateHadithRepository`/`IsolateSearchRepository`, dimulai di `app_bootstrap.dart`), memakai tabel `juz` (`start_surah/start_ayah/end_surah/end_ayah`) sebagai sumber rentang. `JuzReaderController` menyusun daftar datar item (header surah, Basmalah, ayat) dan layar `JuzReaderView` merakit komponen yang sama dengan `QuranDetailView`. Audio diperluas agar antrean menyeberang surah.

**Tech Stack:** Flutter, GetX, `sqlite3` (isolate), `super_sliver_list` (sudah ada) untuk daftar panjang. Tanpa paket baru, tanpa perubahan skema.

**Spec:** `docs/PRD.md` (5.1 tab Juz, baca surah), `docs/specs/2026-11-09-nura-v1-design.md` (baca surah, last read, 6.2 audio), `docs/design/HANDOFF-flutter.md`, kode `lib/app/modules/quran_detail/**` (acuan perilaku), `lib/app/modules/quran_list/**`, `AGENTS.md`.

## Global Constraints

- Kode Inggris, teks pengguna Indonesia. Tanpa `ignore_for_file`, hindari `!`. `flutter analyze` bersih, `flutter test` lulus sebelum tiap commit. Satu topik per commit (Conventional Commits Inggris). Jangan push.
- Teks ayat dari data tidak diubah; `content.db` read-only; query besar memakai isolate dan paging/lazy list; setiap layar menangani loading, kosong, galat; target sentuh 48 dp; 130% teks pada 360×640 tanpa overflow. Tanpa perubahan skema, tanpa paket baru, tanpa jaringan baru (audio tetap lewat `AudioPlayerService`/OnlineService).
- Pakai ulang, jangan menyalin: `AyahCard`, `SurahHeaderCard`, `BismillahHeader`/kartu Basmalah, sheet tafsir, `AyahActionBar` dan aturan penanda ۝. Aturan Basmalah yang sudah ada: tampil di awal surah (sebelum ayat 1) kecuali Al-Fatihah (1) dan At-Taubah (9).
- Teks UI baru hanya yang tertulis di task; laporkan semuanya.

## Keputusan pemilik (2026-11-22)

Mengetuk juz menampilkan seluruh ayat juz itu lintas surah dengan header surah tiap masuk surah baru (Basmalah sesuai aturan); komponen layar baca dipakai ulang (kartu ayat, ۝, ⋯, bilah aksi, bookmark, tafsir); last read menyimpan surah dan ayat sebenarnya; audio "Putar" sampai akhir juz; query di isolate dengan rentang (surah, ayat) dari tabel juz; tes 130% di 360×640.
Keputusan saya (asumsi, ditinjau pemilik): bila juz dimulai di tengah surah (mis. juz 2 di 2:142) header surah itu tetap tampil sekali di awal (konteks) tanpa Basmalah (Basmalah hanya mendahului ayat 1); Basmalah dan header muncul bila juz memuat ayat 1 surah (mis. juz 15 di 17:1) sesuai aturan.

## Review Focus

1. **Batas rentang**: juz 1 (1:1–2:141), juz 2 (2:142–2:252, mulai di tengah surah), juz 15 (17:1–18:74), juz 30 (78:1–114:6, banyak surah pendek), juz yang memuat At-Taubah (tanpa Basmalah) dan Al-Fatihah; jumlah ayat total seluruh 30 juz = 6.236 tanpa tumpang tindih; urutan ayat benar lintas surah.
2. **Last read**: ayat yang terlihat dipetakan ke `(surah, ayat)` yang benar, termasuk saat daftar memuat header di antara ayat; membuka ulang dari Beranda menuju surah dan ayat itu (rute surah yang ada).
3. **Bookmark dan tafsir per (surah, ayat)**: status bookmark tidak tertukar antar surah yang nomor ayatnya sama; kembali dari layar lain menyegarkan penanda.
4. **Performa**: juz besar (mis. juz 30 ±564 ayat) memakai lazy list dan isolate; tidak ada query di `build()`; kegagalan worker ditangani (state galat dengan coba lagi, bukan crash).
5. **Audio lintas surah**: "Putar" dari awal juz atau dari satu ayat memutar sampai akhir juz melewati batas surah (URL per surah diambil saat dibutuhkan, tetap hanya saat Fitur Online hidup; Fitur Online mati = kontrol audio tersembunyi; offline = "Butuh internet"); pause/stop/latar belakang seperti perilaku Fase 7; ayat yang sedang diputar tersorot dan tergulir.

---

### Task 1: Query rentang ayat di isolate dan data juz

**Files:** Create `lib/app/data/repositories/isolate_quran_range_repository.dart` (atau perluasan worker yang ada bila lebih sederhana), `lib/app/data/repositories/quran_range_repository.dart` (antarmuka); Modify `lib/app/app_bootstrap.dart` (start worker, daftarkan, tutup saat gagal), `lib/app/data/repositories/quran_repository.dart` bila perlu (`Juz getJuz(int number)`); Test `test/app/data/repositories/`.

**Interfaces:** Produces: `Future<List<Ayah>> getAyahRange(AyahRef start, AyahRef end)` (urut, termasuk kedua ujung, lintas surah; galat bila ujung tidak valid) dan `Future<void> close()`; `Juz` memberi `AyahRef` awal dan akhir. Worker dimulai seperti `IsolateHadithRepository.start(File)` dan ditutup bersama bootstrap.

- [ ] **Step 1: Write failing tests** (pada content.db nyata atau fixture seperti tes repositori lain): rentang dalam satu surah; lintas dua dan banyak surah (juz 30); awal di tengah surah (2:142); jumlah ayat per juz dijumlahkan untuk 30 juz = 6.236 dan tiap rentang sama dengan jumlah dari tabel; ujung tidak valid (surah 115, ayat 0, awal setelah akhir) → galat tipe domain; worker ditutup → galat yang jelas (bukan hang); hasil identik dengan `listAyah` sinkron untuk satu surah penuh (paritas); tes bootstrap: worker dimulai dan ditutup saat kegagalan (pola tes hadis).
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: add ayah range query in isolate`.

### Task 2: Layar pembaca juz (membaca, bookmark, tafsir, last read)

**Files:** Create `lib/app/modules/juz_reader/{bindings,controllers,views,widgets}/…` (`JuzReaderController`, `JuzReaderView`, `JuzArgs(number)`), Modify `lib/app/routes/app_routes.dart`, `app_pages.dart`, `lib/app/modules/quran_list/views/quran_list_view.dart` (tap juz → rute baru; navigasi yang ada ke ayat awal diganti), mungkin ekstraksi widget bersama dari `quran_detail` (header+Basmalah, daftar ayat) tanpa mengubah perilaku layar surah; Test `test/app/modules/juz_reader/`.

**Interfaces:** Consumes: `getAyahRange`, `listJuz`/`getJuz`, `QuranRepository` (nama surah, Basmalah), `UserRepository` (bookmark, last read), `AyahCard`, `SurahHeaderCard`, sheet tafsir. Produces: `JuzReaderController` dengan state `UiState<List<JuzItem>>` (`sealed JuzItem`: `SurahHeaderItem(surah, withBasmalah)`, `AyahItem(ayah)`), `onInit` memuat rentang lewat worker; bookmark toggle per `(surah, ayat)`; last read menyimpan `(surah, ayat)` ayat terlihat (aturan yang sama dengan layar surah); app bar "Juz N" dengan subtitle rentang; pengaturan baca (ukuran Arab, terjemahan) dari store yang sama; menu ⋯ dan bilah aksi sama; teks 130% dan Arab 36 tanpa overflow; loading/kosong/galat dengan coba lagi.

- [ ] **Step 1: Write failing tests**: juz 1 (header Al-Fatihah tanpa Basmalah, lalu header Al-Baqarah dengan Basmalah, ayat 2:1…2:141), juz 2 (header Al-Baqarah satu kali di awal tanpa Basmalah, dimulai ayat 142, berakhir 2:252), juz 15 (header+Basmalah Al-Isra di 17:1), juz 30 (banyak header berurutan), juz yang memuat At-Taubah (9) menegaskan tanpa Basmalah; jumlah item ayat per juz = jumlah rentang; bookmark pada 2:255 dan 3:255 tidak tertukar; last read tersimpan sebagai surah dan ayat yang sebenarnya setelah gulir (fake visibility seperti tes last read yang ada); membuka tafsir dan salin berfungsi; kembali dari tafsir/layar lain tidak mereset gulir; galat worker → state galat dengan coba lagi; 130% dan Arab 36 pada 360×640 tanpa overflow; tap juz di daftar membuka layar ini.
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: add juz reader screen`.

### Task 3: Audio lintas surah di pembaca juz

**Files:** Modify `lib/app/services/audio_player_service.dart` (dan antarmuka antrean/URL bila perlu), `lib/app/modules/juz_reader/**`; Test `test/app/services/audio_player_service_test.dart`, `test/app/modules/juz_reader/`.

**Interfaces:** Produces: antrean audio yang menerima rentang ayat lintas surah (URL per surah diambil dari `AudioApiClient` saat dibutuhkan dan di-cache per sesi seperti yang sudah ada), "Putar" memutar dari ayat pertama juz sampai ayat terakhir, "Putar dari sini" dari ayat tertentu sampai akhir juz; ayat yang diputar tersorot dan tergulir (perilaku layar surah); Fitur Online mati = kontrol audio tersembunyi dan nol permintaan; offline = "Butuh internet"; latar belakang menjeda (Fase 7).

- [ ] **Step 1: Write failing tests** (fake engine/API seperti tes yang ada): antrean melintasi batas surah (juz 1: 1:7 → 2:1 dalam satu antrean); URL surah berikutnya diambil lazily (tepat satu permintaan per surah, tidak sebelum dibutuhkan); permintaan gagal di tengah → berhenti dengan pesan yang ada, tanpa memutar ayat salah; switch off = tanpa permintaan dan kontrol tersembunyi; offline = disabled; "Putar dari sini" di ayat tengah juz; selesai di ayat terakhir juz berhenti; layar surah tetap bekerja seperti sebelumnya (regresi).
- [ ] **Step 2–4: Run fail, implement, run pass. Step 5: Commit** `feat: play audio across surahs in juz reader`.

### Task 4: Penyelesaian

- [ ] **Step 1:** `flutter analyze`, `flutter test`, build APK debug.
- [ ] **Step 2:** Perbarui `docs/STATUS.md` (fitur, keputusan saya di atas, teks UI baru, checklist uji perangkat: juz 1, 2, 15, 30 dan juz yang memuat At-Taubah; header/Basmalah; gulir dan last read membuka ulang dari Beranda; bookmark lintas surah; tafsir; audio lintas surah; offline; 130%), PRD 5.1 (tab Juz membuka pembaca per juz).
- [ ] **Step 3: Commit** `docs: update status after juz reader`.
