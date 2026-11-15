# Nura Fase 6 (1 Hari 1 Ayat/Hadis): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ayat dan hadis harian di tiga tempat: kartu Beranda, widget Android (gambar dari Flutter), dan notifikasi harian. Bagian hadis jalan tanpa daftar kurasi ayat (Q9); bagian ayat aktif otomatis saat `data-source/meta/daily_ayah.json` ditambahkan.

**Architecture:** Builder `content.db` memilih kandidat hadis dengan aturan matan (usulan D1) dan menyimpan **offset** matan (bukan salinan teks) dalam `daily_hadith`, dengan dua urutan deterministik (setelan Bukhari-Muslim dan 9 kitab). `DailyContentRepository` membaca konten untuk satu tanggal lokal dan merujuk teks asli lewat offset. Tiga penyaji memakainya: `DailyCard` di Beranda, `HomeWidgetService` (render PNG 7 hari saat aplikasi dibuka, disimpan lewat `home_widget`, provider native Kotlin memilih gambar menurut tanggal), dan `DailyNotifier` (memakai `NotificationScheduler` Fase 5, ruang id terpisah).

**Tech Stack:** Flutter, GetX, `sqlite3`, `flutter_local_notifications` (sudah ada), Kotlin (AppWidgetProvider). Paket baru yang diusulkan: `home_widget` (D3, perlu persetujuan). Perubahan skema `daily_hadith` (D2) perlu persetujuan pemilik.

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (3.2, 3.3, 8, 9, 10, 11 Fase 6), `docs/PRD.md` 5.5, `docs/STATUS.md` (Q9, Q12), desain: `docs/design/2026-11-09-nura-ui-design-brief.md` bagian 5 (Beranda) dan 12 (keputusan produk harian), `docs/design/HANDOFF-flutter.md` (`DailyCard`, `DailyWidget`, `DailyNotification`). Baca juga `AGENTS.md`.

## Global Constraints

- Kode dan komentar teknis Inggris; teks pengguna Indonesia. Tanpa `ignore_for_file`. Hindari `!` (komentar alasan bila terpaksa). `flutter analyze` bersih, `flutter test` lulus sebelum tiap commit. Satu topik per commit (Conventional Commits Inggris). Jangan push, dan sebelum push konfirmasi langsung dari pemilik bahwa repo privat.
- Jangan mengubah kolom teks asli (`arab`, `translation_id`) dan jangan mengedit `data-source/` (satu-satunya penambahan yang diharapkan adalah `meta/daily_ayah.json` dari pemilik). `content.db` dibangun oleh `tool/prepare_content.sh`, tidak di-commit.
- Perubahan skema `content.db`, paket baru, dan sumber data baru **diminta persetujuan dulu**. Perubahan folder platform (`android/`) di commit terpisah.
- Matan yang ditampilkan adalah **substring persis** dari teks asli; ekstraksinya diuji terhadap teks sumber. Notifikasi harian: terjemahan dan rujukan saja, tanpa teks Arab. Widget statis (gambar), satu area ketuk, tanpa tombol.
- Rujukan: `QS. <Nama Latin>: <ayat>` dan `HR. <Kitab> No. <nomor>` (nama kitab dari `hadithBookNames`). "Hari" = tanggal lokal perangkat; `dayIndex` = jumlah hari sejak 2026-01-01 (spec 8.1).
- Semua string UI baru dikumpulkan dan diajukan ke pemilik untuk persetujuan sebelum rilis.

## Fakta yang diukur (`assets/db/content.db`, 2026-11-15)

| Hal | Nilai |
|---|---|
| `daily_hadith` sekarang | 8.421 baris (filter sementara: `translation_length` ≤ 400, acak seed 20261109), `daily_ayah` kosong |
| Bentuk data hadis | `arab` = sanad + matan tanpa pemisah (kadang kata menempel, mis. Bukhari 34: "قَالَقَالَ رَسُولُ اللَّهِ"); `translation_id` = sanad dengan nama perawi dalam `[...]` lalu `bersabda: "…"`; tanda kutip ASCII `"` dan kadang `”` |
| Hadis memuat "bersabda" (Bukhari + Muslim) | 6.151 dari 11.568; yang berbentuk `bersabda: "` ada 4.870 |
| Hadis terpotong (Q12) | 19 hadis (`length(CAST(arab AS BLOB)) >= 16374`), dikecualikan dari kandidat harian |
| Kandidat lolos aturan D1 (semua syarat, tanpa 19 terpotong) | **Bukhari 1.051 · Muslim 674 · Abu Daud 773 · Tirmidzi 372 · Nasa'i 942 · Ibnu Majah 1.566 · Ahmad 457 · Malik 200 · Darimi 563 = 6.598** sebelum batas panjang |
| Setelah batas N (terjemahan matan ≤ 300 code unit, Arab ≤ 300 karakter, rasio panjang terjemahan/Arab 0,8–3,0) | **Bukhari + Muslim 1.271; 9 kitab 5.102** (N=250: 1.119 / 4.596; N=400 dengan Arab ≤ 300: 1.441 / 5.626) |
| Dibuang aturan, alasan utama (semua 9 kitab) | tidak ada `bersabda: "` 20.357; `bersabda` tidak tepat setelah *shallallahu 'alaihi wasallam* pertama 8.569; teks sesudah tanda kutip penutup 1.427; nama perawi `[...]` di dalam matan 627; "bersabda:" kedua di dalam 369; tanpa tanda kutip penutup 129 (satu hadis bisa kena lebih dari satu alasan) |

### Contoh nyata (diambil dari `content.db`; sampel acak dari kandidat Bukhari + Muslim)

| Hadis | Matan Arab (potongan) | Matan terjemahan |
|---|---|---|
| Bukhari 34 | مَنْ يَقُمْ لَيْلَةَ الْقَدْرِ إِيمَانًا وَاحْتِسَابًا غُفِرَ لَهُ مَا تَقَدَّمَ مِنْ ذَنْبِهِ | Barangsiapa menegakkan lailatul qodar karena iman dan mengharap pahala, maka diampuni dosa-dosanya yang telah lalu |
| Bukhari 576 | إِذَا سَمِعْتُمْ النِّدَاءَ فَقُولُوا مِثْلَ مَا يَقُولُ الْمُؤَذِّنُ | Apabila kalian mendengar adzan, maka jawablah seperti apa yang diucapkan mu'adzin. |
| Bukhari 588 | بَيْنَ كُلِّ أَذَانَيْنِ صَلَاةٌ ثَلَاثًا لِمَنْ شَاءَ | Di dua adzan (adzan dan iqamat) ada shalat sunah -beliau ucapkan tiga kali- bagi yang mau. |
| Bukhari 1945 | الْحَلِفُ مُنَفِّقَةٌ لِلسِّلْعَةِ مُمْحِقَةٌ لِلْبَرَكَةِ | Sumpah itu melariskan dagangan jual beli namun menghilangkan barakah |
| Bukhari 2052 | مَنْ بَاعَ نَخْلًا قَدْ أُبِّرَتْ فَثَمَرُهَا لِلْبَائِعِ إِلَّا أَنْ يَشْتَرِطَ الْمُبْتَاعُ | Siapa yang menjual pohon kurma yang telah dikawinkan maka buahnya nanti menjadi hak penjual kecuali disyaratkan oleh pembeli |
| Bukhari 1934 | رَحِمَ اللَّهُ رَجُلًا سَمْحًا إِذَا بَاعَ وَإِذَا اشْتَرَى وَإِذَا اقْتَضَى | Allah merahmati orang yang memudahkan ketika menjual dan ketika membeli dan juga orang yang meminta haknya |

Contoh yang **ditolak** aturan: versi awal tanpa syarat penjajaran meloloskan Bukhari 112, 274, 660, 915, dan 1175 dengan pasangan yang tidak sejajar (Arab memuat narasi, terjemahan hanya kutipan terakhir); aturan akhir menolak kelimanya dan Task 1 mengujinya. Dari 400 pasangan Bukhari + Muslim yang diperiksa, 7 punya rasio panjang di luar 0,8–2,5, tetapi rasio sah bisa sampai sekitar 2,7 (mis. Bukhari 2184), jadi batas atas diusulkan 3,0.

## Review Focus

1. **Matan Arab dan terjemahan tidak sejajar** (Arab memuat narasi, terjemahan hanya kutipan, atau sebaliknya): kandidat harus lolos syarat penjajaran, rasio panjang, dan substring persis; ada tes pada kelima hadis tolakan di atas dan pada fixture kecil (Task 1).
2. **Pergantian hari dan zona**: konten, kartu, gambar widget, dan notifikasi memakai tanggal lokal perangkat; tepat setelah tengah malam kartu Beranda dan widget beralih ke hari baru, dan perangkat yang pindah zona tidak memilih entri hari lalu (Task 2, 3, 5).
3. **`daily_ayah` kosong**: kartu ayat disembunyikan tanpa celah, widget "Ayat hari ini" menampilkan keterangan (bukan gambar kosong atau crash), notifikasi hanya memuat hadis; saat `daily_ayah.json` ditambahkan lalu `prepare_content.sh` dijalankan, ayat tampil tanpa perubahan kode aplikasi (Task 1, 2, 3).
4. **Ganti setelan sumber hadis (Bukhari-Muslim ↔ 9 kitab)**: hasil hari ini stabil untuk setelan yang sama, berbeda antar setelan, dan kartu, gambar widget, serta notifikasi ikut diperbarui; urutan kedua daftar deterministik antar build (Task 1, 2, 4, 6).
5. **Widget basi atau gagal render**: aplikasi tidak dibuka > 7 hari (entri hari ini tidak ada) menampilkan "Buka Nura untuk memperbarui"; gagal merender (font belum termuat, penyimpanan penuh) tidak menghapus gambar lama dan tidak membuat widget kosong (Task 4, 5).

## Keputusan terbuka dan asumsi

D1, D2, dan D3 mengubah aturan seleksi, skema, dan dependensi dan **perlu persetujuan pemilik sebelum Task 1 dan 4 dikerjakan**; sisanya diasumsikan.

| ID | Pertanyaan | Asumsi / usulan |
|---|---|---|
| D1 | Aturan seleksi matan hadis harian (usulan, **perlu persetujuan**) | Kandidat = hadis bukan salah satu dari 19 terpotong, yang memenuhi semua: (a) **terjemahan**: `shallallahu 'alaihi wasallam` pertama diikuti dalam ≤ 14 karakter oleh `bersabda: "` (atau tanda kutip lengkung); matan = isi antara tanda kutip pembuka itu dan tanda kutip **terakhir**; sesudah tanda kutip penutup hanya boleh spasi, titik, titik koma, koma, kurung penutup; tanpa `[` atau `]` di dalam; tanpa "bersabda:" kedua di dalam; minimal 10 karakter; spasi tepi dibuang lewat offset, bukan mengubah teks; (b) **Arab**: pada bentuk ternormalisasi, matan dimulai tepat setelah `صلى الله عليه وسلم` pertama, melewati satu kata kerja ucap opsional (قال، يقول، قالت، فقال), sampai akhir teks; minimal 10 karakter; offset dipetakan ke teks asli bervokal (pemetaan offset yang sudah ada di kode pencarian); (c) **batas panjang**: terjemahan matan ≤ **N = 300** UTF-16 code unit, Arab ≤ 300 karakter; (d) rasio panjang terjemahan/Arab (karakter) antara 0,8 dan 3,0. Hasil pada data: lihat tabel fakta (1.271 untuk Bukhari-Muslim dan 5.102 untuk 9 kitab; 1.271 hari ≈ 3,5 tahun sebelum berulang). Kelemahan: aturan sengaja ketat, sehingga hadis tanpa bentuk `bersabda: "` (narasi, perbuatan) tidak masuk; tidak ada pengecekan makna, hanya struktur dan panjang. Pemilik memeriksa contoh di atas dan bisa mengubah N atau menambah/menghapus syarat |
| D2 | Skema `daily_hadith` (perlu persetujuan) | Ganti tabel dengan `daily_hadith(list TEXT CHECK (list IN ('default','all')), seq INTEGER, hadith_id INTEGER REFERENCES hadith(id), arab_start INTEGER, arab_end INTEGER, tr_start INTEGER, tr_end INTEGER, PRIMARY KEY (list, seq))`. `default` = kandidat Bukhari + Muslim, `all` = kandidat semua 9 kitab, masing-masing diacak dengan seed tetap `20261109` dari urutan `(sort_order kitab, number)` (pengacak yang sudah ada). Offset = indeks UTF-16 pada kolom aslinya, jadi tidak ada teks ganda dan kolom asli tak berubah (aturan 3 AGENTS). Verifikasi `--full` memeriksa: offset di dalam teks, substring tidak kosong, lolos aturan D1, 19 terpotong tidak ada, `seq` rapat dari 0. Alternatif: dua tabel terpisah (sama secara fungsi) |
| D3 | Paket (perlu persetujuan) | `home_widget` (disebut spec dan desain): menyimpan gambar/entri dan menangani ketukan widget → tautan. Tanpa paket lain: notifikasi memakai `flutter_local_notifications` yang sudah ada. Alternatif tanpa paket: platform channel sendiri (lebih banyak kode native) |
| D4 | Tanggal | Tanggal lokal perangkat (spec 8.1); `dayIndex` = hari sejak 2026-01-01; hasil `seq = dayIndex mod count` (daftar yang dipakai menurut setelan). Tanggal sebelum 2026-01-01 menghasilkan indeks negatif yang dibungkus ke rentang valid (tes) |
| D5 | Ayat belum ada (Q9) | `daily_ayah` kosong → kartu ayat tidak dirender, widget "Ayat hari ini" memakai keterangan "Ayat harian belum tersedia. Buka Nura." (string native), notifikasi hanya hadis. Format `daily_ayah.json` (usulan untuk pemilik, dicatat di spec 3.3): `[{"surah": 94, "ayah": 6}, …]`; builder menolak pasangan yang tidak ada, duplikat, atau berformat salah, dan mengacak dengan seed tetap yang sama. Tanpa perubahan kode aplikasi saat berkas ditambahkan |
| D6 | Render widget | Kartu Beranda dan widget memakai satu widget Flutter (`DailyCard`, bahasa visual sama). Render PNG untuk 7 tanggal ke depan: dua jenis (ayat, hadis) × terang/gelap, pada ukuran widget yang terpasang (provider menyimpan ukuran per widget id; bila belum ada, ukuran bawaan 4×2 ≈ 320×152 dan 4×3 ≈ 320×240 dp, radius 24). Elipsis: Arab 1 baris (4×2) atau 2 baris (4×3), terjemahan 1 atau 3 baris. Gambar ditulis ke berkas sementara lalu diganti atomik; gagal render tidak menghapus gambar lama |
| D7 | Provider native | `DailyAyahWidgetProvider` dan `DailyHadithWidgetProvider` (Kotlin), `updatePeriodMillis` ≈ 3 jam, plus `ACTION_DATE_CHANGED` dan `BOOT_COMPLETED`; memilih entri sesuai tanggal lokal; ketuk = `PendingIntent` ke tautan `nura://ayah/<surah>/<ayat>` atau `nura://hadith/<slug>/<nomor>`; entri hari ini tidak ada → "Buka Nura untuk memperbarui". Dikerjakan di commit platform terpisah dan hanya bisa diuji penuh di perangkat |
| D8 | Notifikasi harian | Satu per hari pukul 06.00 waktu perangkat (default, bisa diubah dan dimatikan), dijadwalkan untuk 7 hari ke depan saat aplikasi dibuka dan saat setelan berubah; judul "Ayat hari ini" / "Hadis hari ini" (dengan `daily_ayah` kosong selalu hadis), isi terjemahan matan (BigText) + rujukan, tanpa Arab; ketuk membuka Beranda. Id: `yyyymmdd*10 + 7` (ruang id Fase 5 memakai k = 0–4 dan 9; pembatalan difilter per k agar tidak saling membatalkan). Memakai `NotificationScheduler` dan izin notifikasi Fase 5 |
| D9 | Setelan | Kunci setting baru: `daily_notify_enabled` (default mati), `daily_notify_time` (`HH:mm`, default `06:00`), `daily_hadith_source` (`default`/`all`). UI sementara: satu bottom sheet "Pengaturan harian" dari kartu Beranda (sakelar, jam, pilihan sumber hadis). Onboarding dan layar Pengaturan lengkap tetap Fase 8 / desain putaran 2 |
| D10 | Beranda | Fase 6 hanya menambah kartu harian ke `HomeView` (kartu waktu sholat berikutnya dan `LastReadCard` bukan bagian Fase 6): urutan kartu ayat (bila ada) lalu hadis; "Baca selengkapnya" membuka detail hadis yang sudah ada; ketuk kartu ayat membuka surah di ayat itu. Tombol bagikan di desain ditunda (tidak ada di spec 8) |

---

### Task 1: Seleksi matan dan skema `daily_hadith` di builder

*(menunggu persetujuan D1 dan D2)*

**Files:**
- Create: `lib/content_pipeline/matan_extractor.dart`
- Modify: `lib/content_pipeline/content_schema.dart`, `content_db_builder.dart`, `content_db_verifier.dart`, `docs/specs/2026-11-09-nura-v1-design.md` (3.2, 3.3 termasuk format `daily_ayah.json`, 8.1)
- Test: `test/content_pipeline/matan_extractor_test.dart`, `content_db_builder_test.dart`, `content_db_verifier_test.dart`, `test/app/real_daily_content_test.dart`; fixture di `test/fixtures/data-source`

**Interfaces:**
- Produces: `class Matan { int arabStart, arabEnd, trStart, trEnd; }`; `Matan? extractMatan(String arab, String translation)` (null bila tidak lolos aturan D1 a–d); `const int kMatanMaxTranslation = 300`, `kMatanMaxArab = 300`; builder mengisi `daily_hadith` (D2) dan `daily_ayah` dari `meta/daily_ayah.json` bila ada.

- [ ] **Step 1: Write the failing tests**: Bukhari 34, 576, 588, 1945, 2052 menghasilkan matan persis seperti tabel contoh (assert substring); Bukhari 112, 274, 660, 915, 1175 → `null`; 19 hadis terpotong tidak pernah lolos; terjemahan dengan `[nama]` di dalam, "bersabda:" kedua, teks sesudah tanda kutip penutup, atau panjang 301 → `null`, panjang 300 → lolos; kata kerja Arab opsional; tanda kutip lengkung; builder pada fixture: dua urutan `default`/`all` deterministik (dua build identik byte demi byte), `default` hanya Bukhari + Muslim, `seq` rapat dari 0; verifikasi gagal bila offset di luar teks; `daily_ayah.json` fixture berisi pasangan valid → `daily_ayah` terisi dan terurut acak seed tetap, pasangan tidak ada atau duplikat → build gagal dengan pesan jelas, tanpa berkas → tabel kosong; tes data nyata (gagal, bukan skip, tanpa `content.db`): jumlah kandidat pada tabel fakta (Bukhari-Muslim 1.271, 9 kitab 5.102).
- [ ] **Step 2–4: Run fail, implement, run pass.** Spec 3.2/3.3/8.1 diperbarui dalam commit `docs:` terpisah.
- [ ] **Step 5: Commit** `feat: select daily hadith by matan in content builder` dan `docs: update spec for daily hadith selection`.

### Task 2: `DailyContentRepository`

**Files:**
- Create: `lib/app/data/models/daily_content.dart`, `lib/app/data/repositories/daily_content_repository.dart`, `sqlite_daily_content_repository.dart`, `lib/app/core/daily_index.dart`
- Modify: `lib/app/data/sources/setting_keys.dart`
- Test: `test/app/data/sqlite_daily_content_repository_test.dart`, `test/app/core/daily_index_test.dart`

**Interfaces:**
- Produces: `int dayIndex(DateTime localDate)`; `enum DailyKind { ayah, hadith }`; `enum HadithSource { defaultBm, allBooks }`; `class DailyContent { DailyKind kind; String arab; String translation; String reference; String deepLink; }` (matan hasil `substring` lewat offset, rujukan dibentuk di sini); `abstract interface class DailyContentRepository { DailyContent? ayahFor(DateTime localDate); DailyContent? hadithFor(DateTime localDate, HadithSource source); bool get hasAyah; }`.

- [ ] **Step 1: Write the failing tests** (db fixture): `dayIndex(2026-01-01) == 0`, hari berikutnya +1, tanggal sebelum 2026 dibungkus, hanya komponen tanggal yang dipakai (tidak terpengaruh jam atau zona); `seq = dayIndex mod count` untuk kedua daftar; hari berbeda → hadis berbeda, hari yang sama → sama; setelan `all` bisa berbeda dari `default`; matan = substring persis dari kolom asli lewat offset; rujukan `HR. Shahih Bukhari No. 34` dan `QS. Asy-Syarh: 6`; `daily_ayah` kosong → `ayahFor == null` dan `hasAyah == false`; deep link `nura://hadith/bukhari/34` dan `nura://ayah/94/6`.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: add daily content repository`.

### Task 3: Kartu Beranda

**Files:**
- Create: `lib/app/modules/home/controllers/home_controller.dart`, `bindings`, `widgets/daily_card.dart`, `widgets/daily_settings_sheet.dart`
- Modify: `lib/app/modules/home/home_view.dart`, `app_bootstrap.dart` (registrasi)
- Test: `test/app/modules/home/home_controller_test.dart`, `home_view_test.dart`, `daily_card_test.dart`

**Interfaces:**
- Consumes: `DailyContentRepository`, `UiState`. Produces: `HomeController` (`Rx<UiState<DailyCards>>`, `refreshForToday()`, `setHadithSource`), `DailyCard` (varian ayat menonjol dengan font Arab LPMQ, varian hadis sederhana, label, rujukan, "Baca selengkapnya" hanya di hadis).

- [ ] **Step 1: Write the failing tests**: `daily_ayah` kosong → hanya kartu hadis dan tanpa celah; keduanya ada → ayat di atas; pergantian hari (jam tiruan melewati tengah malam) → kartu beralih; ganti sumber hadis → kartu memuat hadis dari daftar lain; "Baca selengkapnya" membuka detail hadis dengan argumen yang benar; ketuk kartu ayat membuka surah di ayat itu; loading/kosong/error; 130% skala teks pada 360×640 tanpa overflow; target sentuh ≥ 48 dp; sheet setelan: sakelar, pemilih jam, pilihan sumber menyimpan setting.
- [ ] **Step 2–4: Run fail, implement (UI sementara, D10), run pass.**
- [ ] **Step 5: Commit** `feat: add daily cards to home`.

### Task 4: Render gambar widget dan penyimpanan 7 hari

*(menunggu persetujuan D3)*

**Files:**
- Create: `lib/app/services/home_widget_service.dart`, `lib/app/core/widgets/daily_widget_image.dart`, `lib/app/data/sources/widget_storage.dart`
- Modify: `pubspec.yaml` (`home_widget`), `app_bootstrap.dart`
- Test: `test/app/services/home_widget_service_test.dart`, `test/app/core/widgets/daily_widget_image_test.dart`

**Interfaces:**
- Produces: `class WidgetEntry { String date; String imagePath; String deepLink; }`; `Future<void> HomeWidgetService.refresh()`; `Future<Uint8List> renderDailyImage(DailyContent c, {required Size dp, required double pixelRatio, required Brightness brightness})` (PNG dari widget Flutter lewat `RepaintBoundary`/offscreen); antarmuka `WidgetStorage` (pembungkus `home_widget`, tiruan di tes).

- [ ] **Step 1: Write the failing tests**: 7 entri bertanggal berurutan mulai hari ini dengan tautan benar; jenis ayat dilewati bila `daily_ayah` kosong; gambar tidak kosong dan berukuran sesuai `dp × pixelRatio` untuk 4×2 dan 4×3, terang dan gelap; teks panjang dipotong dengan elipsis (Arab 1/2 baris, terjemahan 1/3 baris) tanpa overflow; gagal render atau gagal tulis tidak menghapus entri lama (atomik: berkas sementara lalu ganti) dan tidak melempar; entri lebih lama dari hari ini dibersihkan; `refresh` dua kali tidak menggandakan berkas; ganti setelan sumber hadis menulis ulang gambar hadis.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `build: add home_widget` dan `feat: render daily widget images for seven days`.

### Task 5: Provider widget Android (platform)

**Files:**
- Create: `android/app/src/main/kotlin/com/technowstack/nura/DailyAyahWidgetProvider.kt`, `DailyHadithWidgetProvider.kt`, `DailyWidgetSupport.kt`, `res/xml/daily_*_widget_info.xml`, `res/layout/daily_widget.xml`
- Modify: `AndroidManifest.xml`

**Interfaces:**
- Consumes: kunci/berkas yang ditulis `HomeWidgetService` (Task 4). Produces: widget "Ayat hari ini" dan "Hadis hari ini" (4×2 dan 4×3, resizable) yang memilih entri menurut tanggal lokal, fallback "Buka Nura untuk memperbarui" dan "Ayat harian belum tersedia. Buka Nura.", ketuk → `nura://…`.

- [ ] **Step 1:** Logika murni (pemilihan entri menurut tanggal, fallback, zona) dipisah di `DailyWidgetSupport.kt` dan diuji unit bila memungkinkan; selain itu sediakan daftar uji perangkat.
- [ ] **Step 2:** Implement provider dan manifest (`ACTION_DATE_CHANGED`, `BOOT_COMPLETED`, `updatePeriodMillis` ≈ 3 jam) dalam commit platform terpisah.
- [ ] **Step 3:** `flutter build apk --debug` berhasil. Uji penuh di perangkat oleh pemilik (tambah widget, ganti hari, restart, ketuk, tanpa buka aplikasi > 7 hari).
- [ ] **Step 4: Commit** `feat: add daily widget providers` (platform).

### Task 6: Notifikasi harian

**Files:**
- Create: `lib/app/services/daily_notifier.dart`
- Modify: `lib/app/services/notification_scheduler.dart` (`cancelDaily`), `flutter_local_notifications_scheduler.dart`, `prayer_notifier.dart` (filter id), `app_bootstrap.dart`, modul home (sakelar dan jam di sheet)
- Test: `test/app/services/daily_notifier_test.dart`

**Interfaces:**
- Consumes: `NotificationScheduler`, `DailyContentRepository`, setelan D9. Produces: `DailyNotifier.reschedule()` (idempoten, diserialisasi seperti `PrayerNotifier`); `bool isDailyNotificationId(int)` (k = 7).

- [ ] **Step 1: Write the failing tests**: tujuh hari ke depan pada jam yang diset (default 06:00 waktu perangkat), melewati yang sudah lewat; isi terjemahan + rujukan tanpa karakter Arab; mati → semua dibatalkan; ganti jam atau sumber hadis → batal lalu jadwal ulang; `reschedule` dua kali tanpa duplikat; id `yyyymmdd*10+7` tidak bentrok dan pembatalan sholat tidak membatalkannya (dan sebaliknya); izin notifikasi ditolak → tidak menjadwalkan, tanpa error ke UI; `daily_ayah` kosong → hanya hadis; satu kegagalan `schedule()` tidak membatalkan sisanya, gagal semua dilaporkan seperti `PrayerScheduleException`.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: schedule daily content notifications`.

### Task 7: Pemasangan, pemicu, dan penyelesaian

**Files:** `lib/app/app_bootstrap.dart`, `lib/app/modules/home/*`, `docs/STATUS.md`, `docs/PRD.md`, `docs/specs/2026-11-09-nura-v1-design.md`

- [ ] **Step 1:** Saat aplikasi dibuka dan setelah frame pertama (tanpa menahan tampilan, spec 5.4 langkah 4), saat tanggal berganti, dan saat setelan berubah: `HomeWidgetService.refresh()` dan `DailyNotifier.reschedule()`; tes: urutan dan tidak berulang berlebihan pada resume (pola serialisasi Fase 5).
- [ ] **Step 2:** Jalankan `flutter analyze` dan `flutter test`; bangun APK debug.
- [ ] **Step 3:** Perbarui STATUS (fase, keputusan D1–D10, daftar string UI untuk persetujuan, daftar uji perangkat, risiko), spec 8 dan PRD 5.5 sesuai hasil. Daftar uji perangkat: kartu Beranda hadis dan (setelah `daily_ayah.json`) ayat, pergantian hari, ganti sumber hadis, widget ayat dan hadis (4×2, 4×3, terang dan gelap, ketuk → detail), widget tanpa buka aplikasi > 7 hari, notifikasi harian tepat jam dan tanpa Arab, restart perangkat.
- [ ] **Step 4: Commit** `docs: update status after phase 6`.

## Spec coverage

| Spec / PRD | Task |
|---|---|
| 8.1 pemilihan harian, matan substring persis, 19 terpotong, dua urutan, rujukan | 1, 2 |
| 3.3 `daily_ayah` dari `daily_ayah.json` (tanpa berkas = kosong), `daily_hadith` | 1 |
| 5.5 PRD tiga tempat, kartu Beranda | 3 |
| 8.2 widget gambar, 7 hari, provider native, tautan, fallback | 4, 5 |
| 8.3 notifikasi harian, jam bisa diatur, tanpa Arab, ketuk ke Beranda | 6, 3 |
| 10 tes konten harian dan matan | 1, 2 |
| 9 gagal render/izin ditolak tidak melempar error ke UI | 4, 6 |
