# Nura Fase 7 (Fitur Online: Audio Murottal): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sakelar "Fitur Online" (mati secara default) yang membuka audio murottal per ayat dan per surah: streaming, unduhan per surah, dan pemutaran offline dari unduhan, tanpa pernah melempar error ke UI saat offline, sakelar mati, unduhan terputus, atau penyimpanan penuh.

**Architecture:** `OnlineService.audioEnabled` (setting `online_enabled`) menjadi satu-satunya gerbang. `AudioApiClient` mengambil URL audio per ayat dari API (satu permintaan per surah, divalidasi). `AudioDownloadRepository` mengunduh ayat demi ayat ke `audio/<qari>/<surah>/<ayat>.mp3` dan mencatat kemajuan di `audio_download` (`user.db`, tabel sudah ada). `AudioPlayerService` (di atas antarmuka `AudioEngine` yang membungkus `just_audio`) memutar satu ayat atau antrian sampai akhir surah, memilih berkas lokal bila ada dan streaming bila tidak. Layar baca surah menampilkan state dari controller saja.

**Tech Stack:** Flutter, GetX, `sqlite3` (`user.db`), `dart:io` `HttpClient` untuk API dan unduhan, `connectivity_plus` (sudah ada). Paket baru yang diusulkan dan **menunggu persetujuan pemilik** (D2): `just_audio`. Tidak ada perubahan `content.db`, tidak ada migrasi `user.db` (tabel `audio_download` dan kunci `online_enabled`, `qari_id` sudah ada sejak v1).

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (4, 6.1, 6.2, 9, 10, 11 Fase 7), `docs/PRD.md` 5.2, `docs/STATUS.md` (Q3), desain: `docs/design/HANDOFF-flutter.md` (`AyahActionBar` audio: Mati/Siap streaming/Tersimpan offline/Sedang memutar) dan brief (prinsip 4 "jujur soal offline/online"). Baca juga `AGENTS.md`.

## Global Constraints

- Kode dan komentar teknis Inggris; teks pengguna Indonesia. Tanpa `ignore_for_file`. Hindari `!` (komentar alasan bila terpaksa). `flutter analyze` bersih, `flutter test` lulus sebelum tiap commit. Satu topik per commit (Conventional Commits Inggris). Jangan push; sebelum push, konfirmasi langsung dari pemilik bahwa repo privat.
- Semua akses jaringan audio lewat repository/layanan yang lebih dulu memeriksa `OnlineService.audioEnabled` dan koneksi (AGENTS aturan 5). Sakelar mati = nol permintaan jaringan audio. Kegagalan jaringan bukan error layar: kontrol dinonaktifkan atau diberi keterangan, audio yang gagal berhenti dengan snackbar (spec 9).
- Hanya satu penyedia API audio (PRD 5.2). Paket baru dan penyedia audio (Q3) butuh persetujuan pemilik. Perubahan `android/` di commit terpisah.
- Unduhan hanya berjalan saat aplikasi terbuka (spec 6.2, tanpa unduhan latar belakang di v1), berurutan, bisa dilanjutkan.
- View hanya menampilkan state controller; tidak ada future di `build()`; setiap layar menangani loading, kosong, dan error; `null` tidak sampai ke UI.
- Semua string UI baru dikumpulkan untuk persetujuan pemilik.

## Fakta yang diukur (equran.id, 2026-11-16)

| Hal | Nilai |
|---|---|
| Dokumentasi | `https://equran.id/apidev` (hub) dan `/apidev/v2`. Base URL `https://equran.id/api/v2`, publik, tanpa API key |
| Endpoint | `GET /api/v2/surat` (daftar surat + `audioFull`), `GET /api/v2/surat/{id}` (detail surat, ayat, audio per ayat), `GET /api/v2/tafsir/{id}`. Respons dibungkus `{code, message, data}` |
| Audio per ayat | `data.ayat[].audio` = peta id qari → URL, mis. `"05": "https://cdn.equran.id/audio-partial/Misyari-Rasyid-Al-Afasi/094001.mp3"` (pola `<surah 3 digit><ayat 3 digit>.mp3`). Audio satu surah penuh: `data.audioFull` → `https://cdn.equran.id/audio-full/<Qari>/094.mp3` |
| Qari (6) | `01` Abdullah Al-Juhany · `02` Abdul Muhsin Al-Qasim · `03` Abdurrahman As-Sudais · `04` Ibrahim Al-Dossari · `05` Misyari Rasyid Al-Afasi · `06` Yasser Al-Dosari |
| Berkas (HEAD) | `audio/mpeg`, `accept-ranges: bytes`, ada `etag` dan `content-length`, dilayani Cloudflare. Contoh ukuran: 094001 = 57.805 byte; 002286 = 849.838 byte; Al-Baqarah penuh (Afasi) = 60.326.677 byte; Asy-Syarh penuh = 0,44–1,09 MB tergantung qari |
| Basmalah | `001001.mp3` ada (Basmalah = ayat 1 Al-Fatihah); `009001.mp3` ada. Tidak ada berkas Basmalah terpisah untuk surah lain (`094000`, `002000`, `001000` → 404). Apakah rekaman ayat 1 memuat Basmalah belum diperiksa dengan mendengar |
| Ayat di luar rentang | `094009.mp3` → HTTP 404 `text/plain` |
| Syarat layanan (`https://equran.id/terms`, versi 1.0, berlaku 15 Juni 2025) | Diizinkan: "Menggunakan API untuk pengembangan aplikasi", membagikan konten dengan mencantumkan sumber EQuran.id. Dilarang: "bot atau script otomatis yang berlebihan", melanggar hak cipta. Bagian API: "gratis untuk penggunaan yang wajar", "Terdapat rate limiting", "berhak membatasi akses jika terjadi penyalahgunaan", "Data yang diperoleh tidak boleh dijual atau diperjualbelikan". Hak kekayaan intelektual: teks Al-Qur'an bebas digunakan, tetapi "terjemahan, tafsir, audio, dan fitur aplikasi yang dikembangkan oleh EQuran.id dilindungi hak cipta" |
| Sumber audio menurut situs | Footer "Audio murottal: Verse By Verse Quran". Lisensi sumber asal itu tidak dinyatakan di equran.id |
| Rate limit | Hanya Vector Search yang disebut angkanya (30 permintaan/menit/IP); untuk API lain dan CDN tidak ada angka ("Publik, bukan berarti tanpa batas") |
| Kode saat ini | `OnlineService` hanya punya `prayerSyncEnabled`; `SettingKeys.onlineEnabled` dan `qariId` sudah ada tetapi belum dipakai; tabel `audio_download(qari_id, surah_number, status 'partial'/'complete', ayah_done, bytes, updated_at)` sudah ada; `AyahActionBar` belum punya tombol audio; belum ada layar Pengaturan (desain putaran 2) |

### Yang belum jelas dari syarat layanan (untuk keputusan Q3 audio oleh pemilik)

1. Mengunduh audio untuk diputar offline di aplikasi pihak ketiga tidak disebut boleh maupun dilarang; audio dinyatakan "dilindungi hak cipta" dan penggunaannya "harus sesuai dengan ketentuan yang berlaku".
2. Mengunduh satu surah = puluhan sampai 286 permintaan berurutan ke CDN; "penggunaan yang wajar" dan "script otomatis yang berlebihan" tidak didefinisikan.
3. "Tidak boleh dijual" berdampak bila aplikasi nanti berbayar atau beriklan.
4. Lisensi sumber asal audio (Verse By Verse Quran) tidak tercantum.

Rekomendasi: sebelum rilis, minta izin tertulis ke equran.id (kontak di halaman syarat layanan) untuk streaming dan unduhan offline di Nura, dan tanyakan lisensi sumber audionya. Keputusan Q3 audio tetap di pemilik.

## Review Focus

1. **Sakelar dimatikan di tengah pemutaran atau unduhan**: streaming dan unduhan berhenti seketika, tidak ada permintaan jaringan sesudahnya, berkas yang sudah lengkap tetap ada, kontrol hilang tanpa error (Task 1, 3, 4, 5).
2. **Koneksi putus di tengah jalan**: streaming berhenti dengan snackbar dan tidak macet di "memuat"; unduhan berhenti sebagai `partial` dan dilanjutkan dari ayat berikutnya yang belum ada; berkas setengah jadi tidak pernah dianggap lengkap (Task 3, 4).
3. **Penyimpanan penuh atau tidak bisa ditulis**: unduhan berhenti dengan keterangan, status `partial` konsisten dengan berkas di disk, tidak ada berkas rusak; hapus unduhan benar-benar membebaskan ruang (Task 3, 6).
4. **Ganti qari dan antrian campuran**: unduhan qari A tidak ditampilkan sebagai "tersimpan" untuk qari B; antrian surah yang sebagian lokal sebagian streaming tetap berurutan; offline di tengah antrian berhenti rapi di ayat lokal terakhir (Task 2, 4, 5).
5. **Respons janggal dari API/CDN**: jumlah ayat API tidak sama dengan `content.db`, satu ayat 404, halaman HTML portal Wi-Fi tersimpan sebagai mp3, URL bukan `https://cdn.equran.id/...`: ditolak, tidak disimpan, tidak crash (Task 2, 3).

## Keputusan terbuka dan asumsi

D1 dan D2 (penyedia dan paket) **perlu persetujuan pemilik sebelum implementasi**. D3 dan D6 mengubah perilaku yang dilihat pengguna dan sebaiknya dikonfirmasi; sisanya asumsi.

| ID | Pertanyaan | Asumsi / usulan |
|---|---|---|
| D1 | Penyedia audio (Q3 audio, **keputusan pemilik**) | Usulan: equran.id v2 (sudah dipakai untuk jadwal sholat; satu penyedia sesuai PRD). Temuan lengkap di tabel fakta dan daftar "yang belum jelas". Bila disetujui: atribusi "Audio murottal: EQuran.id" (dan sumber asalnya bila diminta) di layar Sumber & Atribusi (Fase 8), dan permintaan izin tertulis sebelum rilis |
| D2 | Paket baru (**perlu persetujuan**) | `just_audio` (pemutar; membawa `audio_session` sebagai dependensi turunan). Tidak diusulkan: `just_audio_background`/`audio_service` (lihat D3), `dio`/`flutter_downloader` (unduhan memakai `dart:io`), plugin ruang disk |
| D3 | Pemutaran saat aplikasi di latar belakang atau layar mati | Usulan v1: **hanya saat aplikasi terlihat**; pemutaran dijeda saat aplikasi ke latar belakang. Alasan: pemutaran latar belakang yang andal butuh `just_audio_background` + foreground service media (izin `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, notifikasi media, deklarasi di Play Console). Alternatif: tambah paket itu sekarang (lebih nyaman untuk mendengar murottal dengan layar mati, tetapi menambah paket, izin, dan pekerjaan platform) |
| D4 | Sumber URL audio | Dari respons `GET /api/v2/surat/{id}` (kontrak yang terdokumentasi), satu permintaan per surah saat pertama kali diputar atau diunduh, disimpan di memori selama sesi. Bukan menyusun URL dari pola nama berkas (pola tidak didokumentasikan sebagai kontrak). Host yang diterima hanya `cdn.equran.id` dengan `https` |
| D5 | Qari | Enam qari dari API; default `05` Misyari Rasyid Al-Afasi; pilihan disimpan di `qari_id`. Nama tampilan dari daftar tetap di kode (API tidak mengirim nama), diverifikasi tes terhadap id `01`–`06` |
| D6 | Arti "sakelar mati" untuk audio yang sudah diunduh | Usulan: sakelar mati menyembunyikan **semua** kontrol audio (desain: state "mati (tersembunyi)"), termasuk untuk surah yang sudah diunduh; berkasnya tetap disimpan. Sakelar hidup + offline: ayat yang sudah diunduh bisa diputar, lainnya nonaktif dengan "Butuh internet". Alternatif: unduhan tetap bisa diputar walau sakelar mati |
| D7 | Letak sakelar dan pengaturan audio (layar Pengaturan belum ada) | Sementara: bagian "Audio" di sheet pengaturan baca surah (sakelar "Fitur Online" dengan penjelasan satu baris, pilihan qari, tautan "Kelola unduhan"). Dipindah ke layar Pengaturan pada Fase 8 |
| D8 | Unduhan | Per ayat, berurutan, satu surah sekaligus, jeda kecil antar berkas, hanya saat aplikasi terbuka, bisa dibatalkan dan dilanjutkan. Sebelum mulai: perkiraan ukuran dari `content-length` `audioFull` surah itu (satu permintaan HEAD) ditampilkan di dialog konfirmasi ("±60 MB"). Tanpa pembatasan Wi-Fi saja di v1 (dialog menyebut ukuran). Berkas ditulis ke berkas sementara lalu di-rename; diterima hanya bila `content-type` audio, ukuran > 0, dan sama dengan `content-length` |
| D9 | Basmalah | Tidak ada berkas Basmalah terpisah. Putar surah = mulai dari ayat yang dipilih sampai akhir surah (spec 6.2), tanpa menyisipkan Basmalah. Apakah rekaman ayat 1 memuat Basmalah dicek pemilik saat uji perangkat |
| D10 | Penyimpanan penuh | Tidak ada pengecekan ruang kosong di muka (butuh paket baru). Kegagalan tulis (`FileSystemException`) menghentikan unduhan dengan keterangan "Penyimpanan penuh atau tidak bisa ditulis", status `partial`, berkas sementara dihapus |
| D11 | Skema | Tidak ada migrasi: `audio_download` v1 cukup (`ayah_done` = jumlah ayat berurutan yang sudah lengkap dari ayat 1, `bytes` = total). Kebenaran akhir tetap berkas di disk: status dicocokkan ulang dengan berkas saat layar dibuka |

---

### Task 1: Gerbang online, pengaturan audio, katalog qari

**Files:**
- Modify: `lib/app/services/online_service.dart`
- Create: `lib/app/data/models/qari.dart`, `lib/app/data/repositories/audio_settings_store.dart`, `sqlite_audio_settings_store.dart`
- Test: `test/app/services/online_service_test.dart`, `test/app/data/sqlite_audio_settings_store_test.dart`

**Interfaces:**
- Produces: `OnlineService.audioEnabled` (getter dari `online_enabled`, default `false`), `setAudioEnabled(bool)`, `Stream<bool>`/`RxBool` perubahan agar pemutar dan pengunduh bisa berhenti; `class Qari { String id; String name; }`, `const List<Qari> kQaris` (6 entri di tabel fakta), `kDefaultQariId = '05'`; `AudioSettingsStore { String get qariId; void setQariId(String id); }` (id tak dikenal → default; setter menolak id di luar daftar).

- [ ] **Step 1: Write the failing tests**: default mati; nyala/mati tersimpan dan terbaca ulang setelah buka ulang db; perubahan dipancarkan sekali per perubahan; `prayerSyncEnabled` tidak terpengaruh (dan sebaliknya); katalog berisi tepat id `01`–`06` dengan nama di tabel fakta; qari default `05`; id tersimpan yang tidak dikenal → default; `setQariId('99')` → `ArgumentError`.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: add online audio switch and qari settings`.

### Task 2: Klien API audio

**Files:**
- Create: `lib/app/data/sources/audio_api_client.dart`, `audio_api_exception.dart`
- Test: `test/app/data/audio_api_client_test.dart`; fixture `test/fixtures/audio/surat_94.json` (rekaman respons nyata, tanggal ambil di README fixture)

**Interfaces:**
- Produces: `class AudioApiClient { AudioApiClient(PrayerHttp-like http); Future<SurahAudio> fetchSurah(int surah, {required int expectedAyahCount}); }`; `class SurahAudio { int surah; Map<String, List<Uri>> ayahUrlsByQari; Map<String, Uri> fullUrlByQari; }`; sealed `AudioApiException`: `AudioNetwork`, `AudioBadResponse(reason)`, `AudioNotFound`. Memakai kembali tipe fungsi HTTP dan `defaultPrayerHttp` yang ada (ganti nama menjadi netral bila perlu, dalam commit `refactor:` terpisah).

- [ ] **Step 1: Write the failing tests** (HTTP tiruan): fixture surah 94 → 8 URL per qari untuk 6 qari; nomor surah di luar 1–114 ditolak tanpa permintaan; jumlah ayat API ≠ `expectedAyahCount` → `AudioBadResponse`; `nomor` di respons ≠ permintaan → `AudioBadResponse`; URL bukan `https`, host bukan `cdn.equran.id`, atau tidak berakhiran `.mp3` → `AudioBadResponse` (seluruh surah ditolak); qari hilang pada salah satu ayat → qari itu tidak tersedia, yang lain tetap; `nomorAyat` tidak berurutan dari 1; JSON rusak, `data: null`, 404, 5xx, timeout, `SocketException`, `HandshakeException` → jenis exception yang benar dan tidak pernah exception lain.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: add equran audio api client`.

### Task 3: Penyimpanan berkas dan unduhan per surah

**Files:**
- Create: `lib/app/data/sources/audio_file_store.dart`, `lib/app/data/repositories/audio_download_repository.dart` (antarmuka), `default_audio_download_repository.dart`, `lib/app/data/models/audio_download.dart`
- Test: `test/app/data/audio_file_store_test.dart`, `test/app/data/audio_download_repository_test.dart` (server HTTP loopback atau pengunduh tiruan; tanpa internet)

**Interfaces:**
- Consumes: `AudioApiClient`, `OnlineService`, `UserDatabase`.
- Produces: `AudioFileStore { File fileFor(String qari, int surah, int ayah); bool has(...); int bytesOf(String qari, int surah); Future<void> deleteSurah(...); Future<void> deleteAll(); }` (akar `audio/` di direktori support aplikasi); `enum DownloadStatus { none, partial, complete }`; `class SurahDownload { DownloadStatus status; int ayahDone; int ayahTotal; int bytes; }`; `AudioDownloadRepository { SurahDownload statusOf(String qari, int surah, int ayahTotal); Stream<DownloadProgress> download(String qari, int surah, int ayahTotal); void cancel(); Future<int?> estimateBytes(String qari, int surah); List<DownloadedSurah> listDownloads(); Future<void> deleteSurah(...); Future<void> deleteAll(); }`; hasil akhir unduhan sebagai nilai (`completed`, `cancelled`, `offline`, `switchedOff`, `storageFull`, `failed(reason)`), bukan exception.

- [ ] **Step 1: Write the failing tests**: unduhan lengkap menulis `audio/05/094/001.mp3`…`008.mp3`, status `complete`, `bytes` = jumlah ukuran; koneksi putus di ayat 4 → status `partial`, `ayahDone = 3`, tidak ada berkas ayat 4 maupun berkas sementara; lanjutkan → hanya ayat 4–8 yang diminta; batal di tengah → `partial` dan bisa dilanjutkan; sakelar dimatikan di tengah → berhenti sebelum permintaan berikutnya dan tidak ada permintaan sesudahnya; sakelar mati atau offline dari awal → nol permintaan, hasil `switchedOff`/`offline`; `FileSystemException` saat menulis → `storageFull`, berkas sementara dihapus, status konsisten; respons 404 atau `text/html` untuk satu ayat, atau ukuran ≠ `content-length`, atau 0 byte → berkas ditolak dan unduhan berhenti `failed`; dua panggilan `download` bersamaan → hanya satu berjalan; baris `audio_download` yang tidak cocok dengan disk (berkas dihapus dari luar) dikoreksi oleh `statusOf`; qari lain tidak terpengaruh; `deleteSurah` dan `deleteAll` menghapus berkas dan baris; `estimateBytes` memakai satu HEAD `audioFull` dan mengembalikan `null` bila gagal.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: download surah audio with resume`.

### Task 4: Layanan pemutar

*(menunggu persetujuan D2; D3 menentukan perilaku latar belakang)*

**Files:**
- Create: `lib/app/services/audio_engine.dart` (antarmuka + `JustAudioEngine`), `lib/app/services/audio_player_service.dart`
- Modify: `pubspec.yaml` (`just_audio`), `android/` bila paket memintanya (commit platform terpisah)
- Test: `test/app/services/audio_player_service_test.dart` (mesin tiruan)

**Interfaces:**
- Consumes: `AudioFileStore`, `AudioApiClient`, `OnlineService`, `AudioSettingsStore`.
- Produces: `abstract interface class AudioEngine { Future<void> setSources(List<AudioSourceRef> items, {int initialIndex}); Future<void> play(); Future<void> pause(); Future<void> stop(); Stream<EngineEvent> get events; Future<void> dispose(); }` (`AudioSourceRef` = berkas lokal atau URL); `AudioPlayerService { Rx<PlaybackState> state; Future<PlayResult> playAyah(int surah, int ayah, int ayahTotal); Future<PlayResult> playFrom(int surah, int ayah, int ayahTotal); Future<void> pause(); Future<void> resume(); Future<void> stop(); }` dengan `PlaybackState { idle | loading | playing(surah, ayah) | paused(surah, ayah) }` dan `PlayResult { ok, switchedOff, needsInternet, failed }`.

- [ ] **Step 1: Write the failing tests**: ayat yang berkasnya ada diputar dari berkas tanpa permintaan jaringan (juga saat offline); ayat tanpa berkas + online → streaming dari URL API; tanpa berkas + offline → `needsInternet` tanpa memanggil mesin; sakelar mati → `switchedOff` dan mesin tidak disentuh; antrian `playFrom(94, 3, 8)` berisi ayat 3–8 berurutan dengan campuran lokal/URL yang benar; state `playing` berpindah ayat mengikuti event mesin dan kembali `idle` di akhir surah; error mesin di tengah antrian → berhenti, state `idle`, hasil `failed` (untuk snackbar), tidak macet di `loading`; offline di tengah antrian campuran → berhenti setelah ayat lokal terakhir; `playAyah` baru saat sedang memutar menggantikan antrian lama; sakelar dimatikan saat memutar → `stop`; aplikasi ke latar belakang → dijeda (D3); ganti qari saat memutar → berhenti; `dispose` membersihkan langganan.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `build: add just_audio` dan `feat: add audio player service`.

### Task 5: Audio di layar baca surah

**Files:**
- Modify: `lib/app/modules/quran_detail/controllers/quran_detail_controller.dart`, `views/quran_detail_view.dart`, `widgets/ayah_action_bar.dart`, `widgets/ayah_card.dart`, `widgets/surah_header_card.dart`, `widgets/reading_settings_sheet.dart`, `lib/app/app_bootstrap.dart`
- Test: `test/app/modules/quran_detail/audio_controls_test.dart`, tambahan di tes controller yang ada

**Interfaces:**
- Consumes: `AudioPlayerService`, `AudioDownloadRepository`, `OnlineService`, `AudioSettingsStore`. Produces: state audio per ayat di controller (`hidden | ready | offline | playing | paused | needsInternet`), aksi `toggleAyahAudio`, `playSurahFrom`, `startDownload`, `cancelDownload`, kemajuan unduhan surah.

- [ ] **Step 1: Write the failing tests**: sakelar mati → tidak ada kontrol audio sama sekali (D6); sakelar hidup + online → tombol putar per ayat "siap streaming"; surah terunduh → ikon "tersimpan offline"; sedang memutar → ayat disorot dan daftar menggulir mengikutinya (spec 6.2); offline tanpa berkas → tombol nonaktif dengan "Butuh internet"; kegagalan pemutaran → snackbar, bukan layar error; tombol unduh di header surah: dialog konfirmasi dengan perkiraan ukuran, kemajuan "n/N ayat", batal, lanjutkan, keterangan untuk `offline`/`storageFull`/`failed`; meninggalkan layar menghentikan pemutaran tetapi unduhan terus berjalan sampai aplikasi ditutup (spec 6.2); bagian "Audio" di sheet pengaturan baca: sakelar "Fitur Online" + penjelasan, pilihan qari (hanya saat sakelar hidup); target sentuh ≥ 48 dp; skala teks 130% pada 360×640 tanpa overflow; ganti qari memperbarui ikon "tersimpan".
- [ ] **Step 2–4: Run fail, implement (UI sementara mengikuti komponen `AyahActionBar` di handoff), run pass.**
- [ ] **Step 5: Commit** `feat: add audio controls to surah reading`.

### Task 6: Kelola unduhan

**Files:**
- Create: `lib/app/modules/quran_detail/widgets/audio_downloads_sheet.dart` (atau modul kecil `audio_downloads`), controller-nya
- Test: `test/app/modules/quran_detail/audio_downloads_test.dart`

**Interfaces:**
- Consumes: `AudioDownloadRepository`. Produces: daftar surah terunduh per qari (nama surah, status lengkap/sebagian, ukuran), hapus per surah, "Hapus semua" dengan konfirmasi, total ukuran.

- [ ] **Step 1: Write the failing tests**: daftar kosong → keadaan kosong dengan teks penjelas; lengkap dan sebagian dibedakan; ukuran diformat (KB/MB); hapus satu surah menghapus berkas dan baris lalu daftar diperbarui; "Hapus semua" meminta konfirmasi; menghapus surah yang sedang diputar menghentikan pemutaran; menghapus surah yang sedang diunduh membatalkan unduhan dulu; kegagalan hapus ditampilkan sebagai keterangan, bukan crash; 130% skala teks tanpa overflow.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: manage downloaded audio`.

### Task 7: Pemasangan dan penyelesaian

**Files:** `lib/app/app_bootstrap.dart`, `docs/STATUS.md`, `docs/PRD.md`, `docs/specs/2026-11-09-nura-v1-design.md` (6.2 sesuai hasil)

- [ ] **Step 1:** Registrasi layanan di bootstrap tanpa melanggar "tidak mendaftarkan apa pun saat gagal"; pemutar dilepas saat aplikasi ditutup; tes bootstrap.
- [ ] **Step 2:** `flutter analyze`, `flutter test`, `flutter build apk --debug`.
- [ ] **Step 3:** Perbarui STATUS (fase, keputusan D1–D11, daftar string UI untuk persetujuan, risiko, daftar uji perangkat: sakelar mati/hidup, streaming satu ayat dan satu surah, sorotan mengikuti, mode pesawat di tengah streaming dan di tengah unduhan, lanjutkan unduhan, putar offline, ganti qari, hapus unduhan, penyimpanan hampir penuh, telepon masuk saat memutar, cek Basmalah di ayat 1), spec 6.2 dan PRD 5.2 sesuai hasil, Q3 audio sesuai keputusan pemilik.
- [ ] **Step 4: Commit** `docs: update status after phase 7`.

## Spec coverage

| Spec / PRD | Task |
|---|---|
| 6.1 `OnlineService.audioEnabled`, klien HTTP hanya lewat repository setelah gerbang | 1, 2, 3, 4 |
| 6.2 penyedia dan URL per ayat | 2 |
| 6.2 putar ayat (lokal → streaming → "Butuh internet") dan putar surah dengan sorotan dan gulir | 4, 5 |
| 6.2 unduh surah berurutan, `audio_download`, bisa dilanjutkan, hanya saat aplikasi terbuka | 3, 5 |
| 6.2 hapus unduhan per surah atau semua | 6 |
| PRD 5.2 sakelar mati secara default, kontrol disembunyikan atau diberi keterangan, tidak error | 1, 5 |
| 9 request audio gagal → berhenti dan snackbar | 4, 5 |
| 10 tes dengan klien tiruan | 2, 3, 4 |
