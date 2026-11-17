# Nura Fase 7 (Fitur Online: Audio Murottal, hanya streaming): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sakelar "Fitur Online" (mati secara default) yang membuka audio murottal per ayat dan per surah **hanya lewat streaming** (keputusan pemilik 2026-11-16: tanpa unduhan, tanpa berkas audio di penyimpanan), tanpa pernah melempar error ke UI saat offline, sakelar mati, atau streaming gagal.

**Architecture:** `OnlineService.audioEnabled` (setting `online_enabled`) menjadi satu-satunya gerbang. `AudioApiClient` mengambil URL audio per ayat dari API (satu permintaan per surah per sesi, divalidasi). `AudioPlayerService` (di atas antarmuka `AudioEngine` yang membungkus `just_audio`) memutar satu ayat atau antrian sampai akhir surah dengan streaming; pemutaran dijeda saat aplikasi ke latar belakang. Layar baca surah menampilkan state dari controller saja. Tidak ada penulisan berkas audio (cache buffer bawaan pemutar boleh); tabel `audio_download` tidak dipakai.

**Tech Stack:** Flutter, GetX, `sqlite3` (`user.db`, hanya setting), `dart:io` `HttpClient` untuk API, `connectivity_plus` (sudah ada), `just_audio` (disetujui pemilik 2026-11-16; membawa `audio_session`). Tidak ada `just_audio_background`, tidak ada izin foreground service. Tidak ada perubahan `content.db`, tidak ada migrasi `user.db` (kunci `online_enabled` dan `qari_id` sudah ada sejak v1).

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (4, 6.1, 6.2, 9, 10, 11 Fase 7), `docs/PRD.md` 5.2, `docs/STATUS.md` (Q3), desain: `docs/design/HANDOFF-flutter.md` (`AyahActionBar` audio: Mati/Siap streaming/Tersimpan offline/Sedang memutar) dan brief (prinsip 4 "jujur soal offline/online"). Baca juga `AGENTS.md`.

## Global Constraints

- Kode dan komentar teknis Inggris; teks pengguna Indonesia. Tanpa `ignore_for_file`. Hindari `!` (komentar alasan bila terpaksa). `flutter analyze` bersih, `flutter test` lulus sebelum tiap commit. Satu topik per commit (Conventional Commits Inggris). Jangan push; sebelum push, konfirmasi langsung dari pemilik bahwa repo privat.
- Semua akses jaringan audio lewat layanan yang lebih dulu memeriksa `OnlineService.audioEnabled` dan koneksi (AGENTS aturan 5). Sakelar mati = nol permintaan jaringan audio dan semua kontrol audio tersembunyi; sakelar nyala tetapi offline = kontrol tampil nonaktif "Butuh internet". Kegagalan streaming berhenti dengan snackbar (spec 9), bukan layar error.
- **Tidak ada unduhan dan tidak ada penulisan berkas audio ke penyimpanan perangkat** (cache buffer bawaan `just_audio` boleh). `audio_download` tidak disentuh dan tidak ada migrasi.
- Hanya satu penyedia API audio: equran.id v2 (diputuskan 2026-11-16). Perubahan `android/` di commit terpisah. Paket lain di luar `just_audio` dan keputusan skema/spec baru: berhenti dan tanya pemilik.
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
| Kode saat ini | `OnlineService` hanya punya `prayerSyncEnabled`; `SettingKeys.onlineEnabled` dan `qariId` sudah ada tetapi belum dipakai; tabel `audio_download` ada di `user.db` v1 tetapi **tidak dipakai** (keputusan 2026-11-16); `AyahActionBar` belum punya tombol audio; belum ada layar Pengaturan (desain putaran 2) |

### Catatan syarat layanan untuk keputusan streaming (D1 diputuskan; konfirmasi tertulis dianjurkan, tidak wajib)

1. Streaming audio dari CDN equran.id lewat API publik termasuk "menggunakan API untuk pengembangan aplikasi" (diizinkan), tetapi audio dinyatakan "dilindungi hak cipta" dan penggunaannya "harus sesuai dengan ketentuan yang berlaku"; lisensi sumber asal (Verse By Verse Quran) tidak tercantum.
2. "Penggunaan yang wajar", "script otomatis yang berlebihan", dan rate limit tidak didefinisikan untuk API audio: pemutaran hanya mengambil satu permintaan JSON per surah per sesi dan satu berkas per ayat yang diputar, tanpa prefetch massal.
3. "Data tidak boleh dijual" berdampak bila aplikasi nanti berbayar atau beriklan.
4. Tanpa unduhan, tidak ada penyalinan audio ke perangkat, yang mengurangi risiko hak cipta dibanding opsi unduhan.

Rekomendasi (tidak wajib): sebelum rilis, minta konfirmasi tertulis ke equran.id (kontak di halaman syarat layanan) untuk streaming di Nura dan tanyakan lisensi sumber audionya.

## Review Focus

1. **Sakelar dimatikan di tengah pemutaran**: pemutaran berhenti seketika, tidak ada permintaan jaringan audio sesudahnya (termasuk pengambilan URL surah berikutnya), semua kontrol audio hilang tanpa error (Task 1, 3, 4).
2. **Koneksi putus di tengah antrian surah**: streaming berhenti dengan snackbar dan tidak macet di "memuat"; state kembali `idle`; kontrol menampilkan "Butuh internet" sampai koneksi kembali (Task 3, 4).
3. **Respons janggal dari API/CDN**: jumlah ayat API tidak sama dengan `content.db`, satu ayat 404, URL bukan `https://cdn.equran.id/...` atau bukan `.mp3`, halaman HTML portal Wi-Fi: ditolak atau berhenti rapi, tidak crash, tidak menulis apa pun ke disk (Task 2, 3).
4. **Ganti qari, ganti ayat, dan aplikasi ke latar belakang**: memutar ayat baru menggantikan antrian lama tanpa dua suara bersamaan; ganti qari menghentikan pemutaran; ke latar belakang menjeda (tidak memutar diam-diam), kembali ke aplikasi tidak melanjutkan otomatis; telepon masuk (audio focus) menjeda (Task 3, 4).
5. **Tidak ada jejak penyimpanan**: tidak ada kode yang menulis berkas audio atau memakai `audio_download`; tes memastikan direktori aplikasi tidak bertambah berkas audio setelah memutar (Task 3).

## Keputusan dan asumsi

Keputusan pemilik 2026-11-16: audio hanya streaming (tanpa unduhan), D1, D2, D3; keputusan lain memakai asumsi plan dan disetujui.

| ID | Pertanyaan | Keputusan / asumsi |
|---|---|---|
| D1 | Penyedia audio (Q3 audio) | **Diputuskan:** equran.id v2. Atribusi "Audio: EQuran.id (sumber: Verse By Verse Quran)" masuk daftar Sumber & Atribusi (Fase 8). Konfirmasi tertulis ke equran.id (permintaan izin streaming dan pertanyaan lisensi sumber audio) dianjurkan sebelum rilis, tidak wajib. Temuan API dan syarat layanan ada di tabel fakta |
| D2 | Paket baru | **Disetujui:** `just_audio` (+ `audio_session` turunan). Tidak ada paket lain |
| D3 | Latar belakang | **Diputuskan:** v1 memutar hanya saat aplikasi terlihat dan menjeda di latar belakang. Tanpa `just_audio_background`, tanpa izin foreground service |
| D4 | Sumber URL audio | **Diperbarui:** dari respons `GET /api/v2/surat/{id}` (kontrak terdokumentasi), satu permintaan per surah per sesi, disimpan di memori selama sesi (tidak ke disk). Bukan menyusun URL dari pola nama berkas. Hanya `https` dan host `cdn.equran.id`. Tidak ada HEAD/estimasi ukuran dan tidak ada `audioFull` (audio satu surah penuh tidak dipakai; "putar surah" = antrian per ayat sesuai spec) |
| D5 | Qari | Enam qari dari API; default `05` Misyari Rasyid Al-Afasi; pilihan disimpan di `qari_id`. Nama tampilan dari daftar tetap di kode, diverifikasi tes terhadap id `01`–`06` |
| D6 | Sakelar mati / offline | **Diputuskan:** sakelar mati = nol permintaan jaringan audio dan semua kontrol audio tersembunyi; sakelar nyala tetapi offline = kontrol tampil nonaktif "Butuh internet" |
| D7 | Letak sakelar dan pengaturan audio (layar Pengaturan belum ada) | Sementara: bagian "Audio" di sheet pengaturan baca surah (sakelar "Fitur Online" dengan penjelasan satu baris, pilihan qari). Dipindah ke layar Pengaturan pada Fase 8 |
| D8 | Basmalah | Tidak ada berkas Basmalah terpisah; putar surah = ayat yang dipilih sampai akhir surah, tanpa menyisipkan Basmalah. Apakah rekaman ayat 1 memuat Basmalah dicek pemilik saat uji perangkat |
| D9 | Skema | Tidak ada migrasi. `audio_download` tidak dipakai dan ditandai "tidak dipakai" di spec bagian 4 |

---

### Task 1: Gerbang online, pengaturan audio, katalog qari

**Files:**
- Modify: `lib/app/services/online_service.dart`
- Create: `lib/app/data/models/qari.dart`, `lib/app/data/repositories/audio_settings_store.dart`, `sqlite_audio_settings_store.dart`
- Test: `test/app/services/online_service_test.dart`, `test/app/data/sqlite_audio_settings_store_test.dart`

**Interfaces:**
- Produces: `OnlineService.audioEnabled` (getter dari `online_enabled`, default `false`), `setAudioEnabled(bool)`, `Stream<bool>`/`RxBool` perubahan agar pemutar bisa berhenti; `class Qari { String id; String name; }`, `const List<Qari> kQaris` (6 entri di tabel fakta), `kDefaultQariId = '05'`; `AudioSettingsStore { String get qariId; void setQariId(String id); }` (id tak dikenal → default; setter menolak id di luar daftar).

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

### Task 3: Layanan pemutar

*(D2 dan D3 disetujui)*

**Files:**
- Create: `lib/app/services/audio_engine.dart` (antarmuka + `JustAudioEngine`), `lib/app/services/audio_player_service.dart`
- Modify: `pubspec.yaml` (`just_audio`), `android/` bila paket memintanya (commit platform terpisah)
- Test: `test/app/services/audio_player_service_test.dart` (mesin tiruan)

**Interfaces:**
- Consumes: `AudioApiClient`, `OnlineService`, `AudioSettingsStore`.
- Produces: `abstract interface class AudioEngine { Future<void> setSources(List<AudioSourceRef> items, {int initialIndex}); Future<void> play(); Future<void> pause(); Future<void> stop(); Stream<EngineEvent> get events; Future<void> dispose(); }` (`AudioSourceRef` = URL streaming); `AudioPlayerService { Rx<PlaybackState> state; Future<PlayResult> playAyah(int surah, int ayah, int ayahTotal); Future<PlayResult> playFrom(int surah, int ayah, int ayahTotal); Future<void> pause(); Future<void> resume(); Future<void> stop(); }` dengan `PlaybackState { idle | loading | playing(surah, ayah) | paused(surah, ayah) }` dan `PlayResult { ok, switchedOff, needsInternet, failed }`.

- [ ] **Step 1: Write the failing tests** (mesin tiruan): ayat + online → streaming dari URL API qari terpilih; offline → `needsInternet` tanpa memanggil mesin atau API; sakelar mati → `switchedOff`, mesin dan API tidak disentuh (nol permintaan); antrian `playFrom(94, 3, 8)` berisi ayat 3–8 berurutan; state `playing` berpindah ayat mengikuti event mesin dan kembali `idle` di akhir surah; error mesin di tengah antrian → berhenti, state `idle`, hasil `failed` (untuk snackbar), tidak macet di `loading`; offline di tengah antrian → berhenti dan state `idle`; `playAyah` baru saat sedang memutar menggantikan antrian lama (tidak ada dua sumber aktif); sakelar dimatikan saat memutar → `stop` dan tidak ada pengambilan URL sesudahnya; aplikasi ke latar belakang → dijeda dan tidak melanjutkan otomatis saat kembali (D3); ganti qari saat memutar → berhenti; URL surah di-cache per sesi (satu permintaan API per surah untuk banyak ayat) dan tidak diambil ulang saat qari berganti (satu `SurahAudio` memuat semua qari; ganti qari hanya menghentikan pemutaran); tidak ada berkas audio yang ditulis ke direktori aplikasi setelah memutar (periksa direktori sementara tes); `dispose` membersihkan langganan.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `build: add just_audio` dan `feat: add audio player service`.

### Task 4: Audio di layar baca surah

**Files:**
- Modify: `lib/app/modules/quran_detail/controllers/quran_detail_controller.dart`, `views/quran_detail_view.dart`, `widgets/ayah_action_bar.dart`, `widgets/ayah_card.dart`, `widgets/surah_header_card.dart`, `widgets/reading_settings_sheet.dart`, `lib/app/app_bootstrap.dart`
- Test: `test/app/modules/quran_detail/audio_controls_test.dart`, tambahan di tes controller yang ada

**Interfaces:**
- Consumes: `AudioPlayerService`, `OnlineService`, `AudioSettingsStore`. Produces: state audio per ayat di controller (`hidden | ready | playing | paused | needsInternet`), aksi `toggleAyahAudio`, `playSurahFrom`.

- [ ] **Step 1: Write the failing tests**: sakelar mati → tidak ada kontrol audio sama sekali dan nol panggilan jaringan (D6); sakelar hidup + online → tombol putar per ayat "siap streaming"; sedang memutar → ayat disorot dan daftar menggulir mengikutinya (spec 6.2); sakelar nyala tetapi offline → kontrol tampil nonaktif dengan "Butuh internet"; kegagalan streaming → snackbar, bukan layar error; "putar dari sini" memutar sampai akhir surah; meninggalkan layar atau aplikasi ke latar belakang menghentikan/menjeda pemutaran; bagian "Audio" di sheet pengaturan baca: sakelar "Fitur Online" + penjelasan satu baris, pilihan qari (hanya saat sakelar hidup), tanpa kontrol unduhan sama sekali; target sentuh ≥ 48 dp; skala teks 130% pada 360×640 tanpa overflow; ganti qari menghentikan pemutaran.
- [ ] **Step 2–4: Run fail, implement (UI sementara mengikuti komponen `AyahActionBar` di handoff), run pass.**
- [ ] **Step 5: Commit** `feat: add audio controls to surah reading`.

### Task 5: Pemasangan dan penyelesaian

**Files:** `lib/app/app_bootstrap.dart`, `docs/STATUS.md`, `docs/PRD.md`, `docs/specs/2026-11-09-nura-v1-design.md` (6.2 sesuai hasil)

- [ ] **Step 1:** Registrasi layanan di bootstrap tanpa melanggar "tidak mendaftarkan apa pun saat gagal"; pemutar dilepas saat aplikasi ditutup; tes bootstrap.
- [ ] **Step 2:** `flutter analyze`, `flutter test`, `flutter build apk --debug`. Pastikan tidak ada kode yang menulis berkas audio atau memakai `audio_download` (grep).
- [ ] **Step 3:** Perbarui STATUS (fase, keputusan D1–D9, atribusi "Audio: EQuran.id (sumber: Verse By Verse Quran)" untuk daftar Sumber & Atribusi Fase 8, konfirmasi tertulis ke equran.id dianjurkan sebelum rilis tidak wajib, daftar string UI untuk persetujuan, risiko, daftar uji perangkat: sakelar mati/hidup, streaming satu ayat dan satu surah, sorotan mengikuti, mode pesawat di tengah streaming (berhenti dengan snackbar) dan sakelar nyala saat offline ("Butuh internet"), ganti qari, aplikasi ke latar belakang menjeda, telepon masuk saat memutar, cek Basmalah di ayat 1), spec 6.2 dan PRD 5.2 sesuai hasil, Q3 audio sesuai keputusan pemilik.
- [ ] **Step 4: Commit** `docs: update status after phase 7`.

## Spec coverage

| Spec / PRD | Task |
|---|---|
| 6.1 `OnlineService.audioEnabled`, semua request lewat gerbang | 1, 2, 3 |
| 6.2 penyedia dan URL per ayat (equran.id v2, `cdn.equran.id`) | 2 |
| 6.2 putar ayat (streaming atau "Butuh internet") dan putar surah dengan sorotan dan gulir | 3, 4 |
| 6.2 sakelar mati: nol permintaan dan kontrol tersembunyi; hanya saat aplikasi terlihat | 1, 3, 4 |
| 6.2/4 tanpa unduhan, `audio_download` tidak dipakai | 3 (tes tanpa berkas), 5 (grep) |
| PRD 5.2 sakelar mati secara default, tidak error | 1, 4 |
| 9 request audio gagal → berhenti dan snackbar | 3, 4 |
| 10 tes dengan klien tiruan | 2, 3 |
