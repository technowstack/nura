# Nura Fase 5 (Jadwal Sholat): Rencana Implementasi

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Jadwal sholat per wilayah (provinsi + kabupaten/kota) dari API equran.id v2, disimpan per bulan di `user.db`, tampil offline, dengan cadangan perhitungan offline berlabel "perkiraan", layar Sholat, dan notifikasi per waktu sholat dalam zona waktu wilayah.

**Architecture:** `PrayerApiClient` (HTTP, fungsi `send` bisa disuntik, hanya dipanggil lewat `PrayerRepository` yang lebih dulu bertanya ke `OnlineService`) mengisi cache `prayer_day` + `prayer_month` di `user.db`. `PrayerRepository.dayFor(date)` menjalankan alur spec 7.2 dan menyerahkan ke `PrayerCalculator` (`adhan`) bila perlu. Daftar wilayah berupa snapshot asset (pemilih wilayah harus jalan offline), zona waktu dipetakan per provinsi dengan offset tetap (Indonesia tanpa DST). `PrayerNotifier` menjadwalkan 7 hari ke depan dari cache.

**Tech Stack:** Flutter, GetX, `sqlite3` (`user.db`), `dart:io` `HttpClient` (tanpa paket HTTP), paket baru **menunggu persetujuan pemilik** (D3): `adhan`, `flutter_local_notifications`, `timezone`, `geolocator`, `connectivity_plus`. Tidak ada perubahan `content.db`.

**Spec:** `docs/specs/2026-11-09-nura-v1-design.md` (4, 6.1, 7, 9, 10, 11 Fase 5), `docs/PRD.md` 5.4, keputusan equran.id di `docs/STATUS.md`. Desain: `docs/design/HANDOFF-flutter.md` dan brief (komponen `NextPrayerCard`, onboarding langkah b dan c). Baca juga `AGENTS.md`.

## Global Constraints

- Kode dan komentar teknis Inggris; teks pengguna Bahasa Indonesia. Tanpa `ignore_for_file`. Hindari `!` (bila terpaksa beri komentar alasan). `flutter analyze` bersih, `flutter test` lulus sebelum tiap commit.
- Semua akses jaringan lewat `PrayerRepository` setelah `OnlineService.prayerSyncEnabled` dan koneksi diperiksa (AGENTS aturan 5). Kegagalan jaringan bukan error layar: pakai cadangan.
- Data satu bulan kecil, jadi tanpa paging. Setiap layar menangani loading, kosong, dan error eksplisit; `null` tidak sampai ke UI.
- Perubahan folder platform (`android/`) dicommit terpisah dari fitur (AGENTS aturan 8). Paket baru dan data baru diminta persetujuan dulu (D1, D3).
- Satu topik per commit, Conventional Commits Inggris. Jangan push (dan sebelum push, konfirmasi langsung dari pemilik bahwa repo privat). Perbarui `docs/STATUS.md` di akhir.

## Fakta yang diukur (API equran.id v2, 2026-11-15)

| Hal | Nilai |
|---|---|
| `GET /api/v2/shalat/provinsi` | 34 nama provinsi, tanpa Papua Selatan, Papua Tengah, Papua Pegunungan, Papua Barat Daya. Struktur Papua masih lama: Papua memuat Merauke, Mimika, Nabire, Jayawijaya, Kota Jayapura (30 wilayah); Papua Barat memuat Kota Sorong, Raja Ampat, Manokwari (13) |
| `POST /api/v2/shalat/kabkota` `{provinsi}` | daftar nama, mis. `Kab. Asmat`, `Kota Jakarta`, `Kab. Kepulauan Seribu`. Total **517** kab/kota di 34 provinsi |
| `POST /api/v2/shalat` `{provinsi,kabkota,bulan,tahun}` | `data.jadwal[]` per hari: `tanggal`, `tanggal_lengkap` (yyyy-MM-dd), `hari`, `imsak`, `subuh`, `terbit`, `dhuha`, `dzuhur`, `ashar`, `maghrib`, `isya` (`HH:mm`). **Tidak ada zona waktu atau koordinat di respons** |
| Wilayah tidak dikenal | HTTP 404 `{"code":404,"message":"Kabupaten/Kota \"X\" tidak ditemukan di provinsi \"Y\"","data":null}` |
| Bulan tanpa data (Nov 2035) | HTTP 404 `{"code":404,"message":"Jadwal shalat untuk ... bulan November 2035 tidak ditemukan","data":null}` |
| **`bulan: 13`** | HTTP 200 dengan data **bulan berjalan** (parameter salah diam-diam diganti). Klien wajib memvalidasi rentang masukan dan `bulan`/`tahun` yang dikembalikan |
| Contoh Jakarta 2026-11-01 | imsak 03:59, subuh 04:09, terbit 05:23, dhuha 05:51 (terbit +28 mnt), dzuhur 11:40, ashar 14:55, maghrib 17:49, isya 19:00. Imsak = subuh −10 mnt |
| Rate limit, syarat layanan | tidak didokumentasikan / belum dibaca (Q3, wajib sebelum rilis) |
| Kode saat ini | `user.db` v1 sudah punya `prayer_location(source,label,lat,lng,city_key)` dan `prayer_day(date,city_key,...)`, belum pernah dipakai (kosong). Belum ada `OnlineService`; `lib/app/services/` kosong; `pubspec.yaml` tidak punya paket jadwal/notifikasi/lokasi; manifest hanya `INTERNET`; tab Sholat = `ComingSoonTab` |

## Review Focus

Masukan atau kondisi yang disiratkan spec tetapi tidak dilatih tugas lain; tiap butir punya tes di tugas pemiliknya.

1. **Parameter salah dijawab 200 dengan bulan lain** (bulan 13, tahun di luar rentang): klien menolak masukan di luar rentang dan membuang respons yang `bulan`/`tahun`-nya tidak sama dengan permintaan (Task 3).
2. **"Hari ini" menurut zona wilayah, bukan zona perangkat**: pukul 23.30 WIB di perangkat untuk wilayah WIT sudah hari berikutnya; hitung mundur, label, dan notifikasi memakai instan absolut dari offset wilayah (Task 4, 7).
3. **Wilayah berganti nama di API (404 wilayah)**: tidak mengulang permintaan, tidak crash, pengguna diminta memilih ulang; 404 bulan tanpa data di-cache negatif 24 jam, bukan dipanggil tiap buka (Task 3, 4).
4. **Respons janggal**: hari kurang atau berlebih, waktu bukan `HH:mm` (`24:00`, kosong, `--:--`), tanggal tidak berurutan: seluruh bulan ditolak, tidak disimpan separuh (Task 3).
5. **Penjadwalan ulang notifikasi**: tanpa duplikat setelah dijadwalkan dua kali, waktu yang sudah lewat tidak dijadwalkan, izin alarm tepat ditolak memakai alarm tidak tepat, setelah restart dijadwalkan ulang (Task 7).

## Keputusan terbuka dan asumsi plan

D1 dan D3 mengubah sumber data / dependensi dan **perlu persetujuan pemilik sebelum Task 1, 5, dan 7 dikerjakan**; sisanya diasumsikan dan bisa dikoreksi.

| ID | Pertanyaan | Asumsi / rekomendasi |
|---|---|---|
| D1 | Daftar wilayah: snapshot atau ambil langsung dari API saat memilih? | **Snapshot** `data-source/meta/prayer_regions.json` (provinsi → kab/kota, dengan `fetched_at`), dibuat skrip `tool/fetch_prayer_regions.dart`, dipakai app sebagai asset. Alasan: onboarding memilih wilayah sebelum izin sinkron diberikan, jadi pemilih harus jalan offline; 517 nama hanya sekitar 15 KB. Berkas baru di `data-source/` dan `CHECKSUMS.sha256` diperbarui. Skrip yang sama dijalankan ulang untuk mendeteksi perubahan (provinsi baru, nama berubah, termasuk 4 provinsi Papua baru bila API menambahkannya). Alternatif (live) gagal offline |
| D2 | Zona waktu wilayah | Tabel statis provinsi → WIB (+7) / WITA (+8) / WIT (+9), offset tetap tanpa basis data tz. WIB: Aceh, Sumut, Sumbar, Riau, Kepri, Jambi, Sumsel, Babel, Bengkulu, Lampung, Banten, DKI, Jabar, Jateng, DIY, Jatim, Kalbar, Kalteng. WITA: Bali, NTB, NTT, Kalsel, Kaltim, Kaltara, Sulut, Gorontalo, Sulteng, Sulsel, Sultra, Sulbar. WIT: Maluku, Maluku Utara, Papua, Papua Barat. Tes memastikan tiap provinsi di snapshot punya zona; skrip D1 gagal bila ada provinsi tanpa zona. Provinsi tidak dikenal saat runtime = wilayah tidak dapat dijadwalkan, pengguna diminta memilih ulang |
| D3 | Paket baru (AGENTS: tanya dulu) | `adhan` (Dart murni, kecil), `flutter_local_notifications` (+ `timezone`, hanya untuk `TZDateTime` di lokasi `UTC`, tanpa data tz), `geolocator` (GPS untuk cadangan), `connectivity_plus` (sesuai spec 6.1). Tanpa paket HTTP (`dart:io`) dan tanpa `permission_handler` (izin lewat plugin masing-masing). `flutter_local_notifications` meminta desugaring di `android/app/build.gradle.kts` (commit platform terpisah). Tidak dipasang sebelum disetujui |
| D4 | Cadangan offline saat koordinat wilayah (Q4) belum ada | Urutan: cache API → bila belum ada dan sinkron diizinkan + online: ambil API → bila gagal: `adhan` dengan koordinat GPS perangkat bila izin lokasi diberikan (label "perkiraan") → bila tidak: "Butuh internet untuk jadwal pertama". Koordinat per kab/kota (Q4) tidak dikarang; bila nanti ada, ditambahkan sebagai sumber koordinat kedua tanpa mengubah alur. GPS-ke-wilayah-terdekat ditunda sampai Q4 ada |
| D5 | Alarm tepat Android 12+ | `SCHEDULE_EXACT_ALARM` dengan permintaan izin + penjelasan (spec 7.4), bukan `USE_EXACT_ALARM` (kebijakan Play hanya untuk aplikasi alarm/kalender, berisiko). Ditolak: alarm tidak tepat + keterangan di layar Sholat |
| D6 | Skema cache | Migrasi `user.db` v2: hapus dan buat ulang `prayer_location` dan `prayer_day` (keduanya kosong, belum pernah dipakai) dan tambah `prayer_month`. `prayer_location(id=1, provinsi, kabkota, source CHECK('city','gps'))` tanpa lat/lng wajib; `prayer_day(date, provinsi, kabkota, imsak..isya nullable, source CHECK('api','calc'), fetched_at, PK(date,provinsi,kabkota))`; `prayer_month(provinsi, kabkota, year, month, status CHECK('ok','none'), fetched_at, PK(...))`. Spec bagian 4 diperbarui |
| D7 | Kebijakan sinkron | Hanya saat aplikasi dibuka atau wilayah berganti (tanpa WorkManager di v1): ambil bulan berjalan bila belum `ok`; ambil bulan berikutnya bila sisa hari `api` < 7 (spec 7.2.5); satu permintaan sekaligus per wilayah+bulan (single-flight); `status='none'` dicoba lagi setelah 24 jam; kegagalan jaringan dicoba lagi saat aplikasi dibuka berikutnya. Konsekuensi: notifikasi hanya terjadwal sejauh cache (maks 7 hari); pengguna yang tidak membuka aplikasi > 7 hari berhenti dapat pengingat (dicatat di STATUS) |
| D8 | UI | Sementara (desain putaran 2 belum ada untuk daftar kota dan jadwal bulanan): tab Sholat = kartu waktu berikutnya + hitung mundur + daftar waktu hari ini + pemilih wilayah (provinsi lalu kab/kota, pencarian nama) + sakelar sinkron online + sakelar pengingat per waktu + keterangan izin. Logika di controller dan repository, view tipis. Jadwal bulanan dan kartu di Beranda tidak ada di Fase 5 (Beranda = Fase 6) |
| D9 | Cadangan `adhan` | Subuh 20°, Isya 18°, Asar Syafi'i (spec 7.1): metode Singapore di `adhan`; penyesuaian per waktu dari setting (default 0; nilai ihtiyat Kemenag tetap Q5). Imsak = subuh −10 mnt, dhuha tidak dihitung (disimpan `NULL`, UI menyembunyikan baris) karena aturan Kemenag belum dipastikan (dari contoh API: terbit +28 mnt). Tes membandingkan dengan fixture API Jakarta dan Bontang, toleransi ±2 menit (spec 10) |
| D10 | Syarat layanan equran.id | Dibaca pemilik sebelum rilis (Q3); atribusi "equran.id" masuk layar Sumber & Atribusi (Fase 8). Selama pengembangan, batasi permintaan dan jangan polling |

---

### Task 1: Snapshot wilayah, zona waktu, model

*(menunggu persetujuan D1)*

**Files:**
- Create: `tool/fetch_prayer_regions.dart`, `data-source/meta/prayer_regions.json`, `lib/app/data/models/prayer_region.dart`, `lib/app/data/sources/prayer_regions_source.dart`
- Modify: `pubspec.yaml` (asset), `data-source/CHECKSUMS.sha256`, `data-source/README.md`
- Test: `test/app/data/prayer_regions_test.dart`, `test/tool/fetch_prayer_regions_test.dart`

**Interfaces:**
- Produces: `enum PrayerZone { wib, wita, wit }` dengan `int offsetHours` (7/8/9) dan `String label`; `PrayerZone? zoneOfProvince(String provinsi)` (null = tidak dikenal); `class PrayerRegion { String provinsi; String kabkota; PrayerZone zone; String get key => '$provinsi|$kabkota'; }`; `class PrayerRegions { List<String> provinces; List<String> kabkotaOf(String provinsi); List<PrayerRegion> search(String query); PrayerRegion? find(String provinsi, String kabkota); }`; `Future<PrayerRegions> loadPrayerRegions(AssetBundle)`.

- [ ] **Step 1: Write the failing tests**: `zoneOfProvince('DKI Jakarta') == wib`, `'Kalimantan Timur' == wita`, `'Papua Barat' == wit`, `'Papua Selatan' == null`; tiap provinsi di snapshot punya zona; `search('JAKARTA')` memuat `Kota Jakarta` dan `search('seribu')` memuat `Kab. Kepulauan Seribu` (tak peka huruf besar/kecil); `find` untuk nama tidak ada = null; skrip pada klien tiruan menulis JSON dengan `fetched_at` dan gagal (exit 1) bila ada provinsi tanpa zona atau satu provinsi mengembalikan 0 wilayah.
- [ ] **Step 2: Run tests, verify fail.**
- [ ] **Step 3: Implement** model, tabel zona (D2), `PrayerRegions`, dan skrip (`dart run tool/fetch_prayer_regions.dart [--out ...]`, satu permintaan per provinsi dengan jeda 200 ms, nama persis dari API tanpa trim atau ubah).
- [ ] **Step 4: Run the script once** untuk membuat snapshot (34 provinsi, 517 kab/kota, tanggal ambil), perbarui checksum dan README, jalankan tes.
- [ ] **Step 5: Commit** (`data:` untuk snapshot, `feat:` untuk model dan skrip, dua commit).

### Task 2: Migrasi `user.db` v2 dan penyimpanan lokasi/cache

**Files:**
- Modify: `lib/app/data/sources/user_database.dart` (`_migrateToV2`), `lib/app/data/sources/setting_keys.dart`, `docs/specs/2026-11-09-nura-v1-design.md` (bagian 4)
- Create: `lib/app/data/models/prayer_day.dart`, `lib/app/data/repositories/prayer_store.dart` (antarmuka), `lib/app/data/repositories/sqlite_prayer_store.dart`
- Test: `test/app/data/user_database_test.dart` (tambah), `test/app/data/sqlite_prayer_store_test.dart`

**Interfaces:**
- Produces: `enum PrayerSource { api, calc }`; `class PrayerDay { String date; String? imsak, subuh, terbit, dhuha, dzuhur, ashar, maghrib, isya; PrayerSource source; int fetchedAt; }` (`HH:mm`); `enum MonthStatus { ok, none }`; `class MonthRecord { MonthStatus status; int fetchedAt; }`; `abstract interface class PrayerStore { PrayerRegion? getLocation(); void setLocation(PrayerRegion r, {required String source}); PrayerDay? getDay(String date, PrayerRegion r); void saveMonth(PrayerRegion r, int year, int month, List<PrayerDay> days); void markMonthNone(PrayerRegion r, int year, int month, int nowMs); MonthRecord? getMonth(PrayerRegion r, int year, int month); void saveCalcDay(PrayerRegion r, PrayerDay d); int apiDaysFrom(String date, PrayerRegion r); bool notifyEnabled(PrayerName p); void setNotifyEnabled(PrayerName p, bool v); }`; kunci setting `notify_fajr`…`notify_isha`, `prayer_adjust_*` (`prayer_sync_enabled` sudah ada).

- [ ] **Step 1: Write the failing tests**: migrasi v1 → v2 pada berkas v1 berisi bookmark dan last read: data pengguna utuh, `user_version == 2`, tabel baru ada; migrasi yang gagal di tengah tidak merusak (pola tes `user_database` yang sudah ada); `saveMonth` menyimpan 30 hari dan menimpa hari `calc` bulan yang sama; `getDay` hari tak ada = null; `markMonthNone` lalu `getMonth` = `none`; satu wilayah tidak membaca data wilayah lain.
- [ ] **Step 2–4: Run fail, implement (`_migrateToV2` drop+create, store), run pass.**
- [ ] **Step 5: Commit** `feat: migrate user db for prayer regions and month cache` (spec 4 dalam commit `docs:` terpisah).

### Task 3: Klien API equran.id

**Files:**
- Create: `lib/app/data/sources/prayer_api_client.dart`, `lib/app/data/sources/prayer_api_exception.dart`
- Test: `test/app/data/prayer_api_client_test.dart`; fixture `test/fixtures/prayer/jakarta_2026_11.json`, `bontang_2026_11.json` (rekaman respons nyata, tanggal ambil dicatat di README fixture)

**Interfaces:**
- Produces: `typedef PrayerHttp = Future<({int status, String body})> Function(Uri url, {String? jsonBody})` (default memakai `dart:io` `HttpClient`, timeout 15 dtk); `class PrayerApiClient { PrayerApiClient(PrayerHttp http); Future<List<PrayerDay>> fetchMonth(PrayerRegion r, int year, int month); }`; hierarki sealed `PrayerApiException`: `UnknownRegion`, `NoDataForMonth`, `Network`, `BadResponse(reason)`.

- [ ] **Step 1: Write the failing tests** (klien tiruan, tanpa jaringan): respons Jakarta 30 hari → 30 `PrayerDay` bertanggal berurutan; 404 wilayah → `UnknownRegion`; 404 bulan → `NoDataForMonth`; `bulan: 13` atau `0` ditolak sebelum permintaan keluar (tanpa panggilan HTTP); respons 200 yang `bulan`/`tahun`-nya tidak sama dengan permintaan → `BadResponse`; jumlah hari bukan jumlah hari bulan itu, waktu `24:00`/kosong/`9:5`, tanggal duplikat atau tidak berurutan, JSON rusak, `data: null` pada 200 → `BadResponse` dan tidak ada hasil separuh; timeout/`SocketException` → `Network`; badan permintaan memuat nama wilayah persis (`D.I. Yogyakarta`, `Kab. ...`).
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: add equran prayer api client`.

### Task 4: `OnlineService` dan `PrayerRepository` (alur spec 7.2)

**Files:**
- Create: `lib/app/services/online_service.dart`, `lib/app/data/repositories/prayer_repository.dart` (antarmuka + `DefaultPrayerRepository`), `lib/app/core/prayer_clock.dart`
- Test: `test/app/services/online_service_test.dart`, `test/app/data/prayer_repository_test.dart`; `FakePrayerApi` dan `FakeClock` di `test/support/`

**Interfaces:**
- Consumes: `PrayerStore`, `PrayerApiClient`, `PrayerCalculator` (Task 5; antarmukanya dibuat di sini dengan tiruan), `OnlineService`.
- Produces: `class OnlineService { bool get prayerSyncEnabled; Future<bool> canReach(); }` (setting `prayer_sync_enabled`; `connectivity_plus` menunggu D3, sebelum itu `canReach` memakai tiruan yang selalu mencoba); `class PrayerClock { DateTime nowUtc(); String todayIn(PrayerZone z); DateTime instantOf(String date, String hhmm, PrayerZone z); }`; `enum DayOutcome { api, calc, needsInternet, unknownRegion, noLocation }`; `class DayResult { DayOutcome outcome; PrayerDay? day; }`; `Future<DayResult> dayFor(String date)`; `Future<void> syncIfNeeded()`.

- [ ] **Step 1: Write the failing tests** (klien dan jam tiruan): ada cache `api` → dipakai tanpa panggilan jaringan; cache kosong + sinkron mati → hitung (D4) atau `needsInternet`; cache kosong + sinkron hidup + online → satu panggilan, tersimpan, dipakai; dua `dayFor` bersamaan memicu **satu** permintaan; `UnknownRegion` → `unknownRegion` dan tidak diulang sampai wilayah diganti; `NoDataForMonth` → di-cache `none`, tidak dipanggil lagi dalam 24 jam, dicoba lagi sesudahnya; `Network` → cadangan `calc` berlabel perkiraan, dicoba lagi pada `syncIfNeeded` berikutnya; sisa hari `api` < 7 memicu bulan berikutnya (termasuk batas Des → Jan); pada 2026-11-15 16:30 UTC `todayIn(wib)` = `2026-11-15` (23:30), `todayIn(wita)` = `2026-11-16` (00:30), `todayIn(wit)` = `2026-11-16` (01:30); `instantOf('2026-11-01','04:09',wib)` = 2026-10-31 21:09 UTC dan hasil yang sesuai untuk wita (20:09 UTC) dan wit (19:09 UTC).
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** `feat: add prayer repository with cache and fallback flow`.

### Task 5: Perhitungan offline dan GPS

*(menunggu persetujuan D3: `adhan`, `geolocator`)*

**Files:**
- Create: `lib/app/data/sources/prayer_calculator.dart` (`AdhanPrayerCalculator`), `lib/app/services/location_service.dart`
- Modify: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml` (izin lokasi kasar, commit platform terpisah)
- Test: `test/app/data/prayer_calculator_test.dart`

**Interfaces:**
- Produces: `abstract interface class PrayerCalculator { PrayerDay calculate({required String date, required double lat, required double lng, required PrayerZone zone, Map<PrayerName, int> adjustMinutes}); }`; `abstract interface class LocationService { Future<LocationResult> current(); }` dengan `LocationResult` sealed: `Granted(lat, lng)`, `Denied`, `Unavailable`.

- [ ] **Step 1: Write the failing tests**: untuk tanggal-tanggal di fixture Jakarta (-6.2088, 106.8456) dan Bontang (0.1333, 117.5), subuh, terbit, dzuhur, ashar, maghrib, isya dalam ±2 menit dari fixture API; imsak = subuh −10; `dhuha == null`; penyesuaian +2 menit menggeser tepat 2 menit; hasil `source == calc`; izin ditolak → `Denied` dan `PrayerRepository` mengembalikan `needsInternet` tanpa error.
- [ ] **Step 2–4: Run fail, implement, run pass.** Bila selisih > 2 menit pada salah satu waktu, berhenti dan laporkan angkanya (Q5) sebelum mengubah parameter.
- [ ] **Step 5: Commit** `feat: add offline prayer time calculation`.

### Task 6: Layar Sholat

**Files:**
- Create: `lib/app/modules/prayer/{bindings,controllers,views,widgets}/…`, `lib/app/core/widgets/next_prayer_card.dart`
- Modify: `lib/app/modules/shell/views/shell_view.dart` (ganti `ComingSoonTab` di tab Sholat), `lib/app/app_bootstrap.dart` (registrasi)
- Test: `test/app/modules/prayer/prayer_controller_test.dart`, `prayer_view_test.dart`, `region_picker_test.dart`

**Interfaces:**
- Consumes: `PrayerRepository`, `PrayerRegions`, `PrayerClock`, `UiState`. Produces: `PrayerController` dengan `Rx<UiState<PrayerScreen>>`, `selectRegion(PrayerRegion)`, `setSyncEnabled(bool)`, hitung mundur per detik yang berhenti saat tab tidak aktif.

- [ ] **Step 1: Write the failing tests**: kartu waktu berikutnya memilih Subuh besok setelah Isya (lewat tengah malam zona wilayah), hitung mundur memakai instan absolut; label "perkiraan" hanya untuk `calc`; `unknownRegion` meminta memilih ulang; `needsInternet` menampilkan "Butuh internet untuk jadwal pertama"; baris dhuha disembunyikan bila `null`; pemilih wilayah (provinsi lalu kab/kota, pencarian, tak peka huruf besar/kecil) dengan target sentuh ≥ 48 dp; skala teks 130% pada 360×640 tanpa overflow; state loading/kosong/error.
- [ ] **Step 2–4: Run fail, implement (UI sementara, D8), run pass.**
- [ ] **Step 5: Commit** `feat: add prayer screen with region picker`.

### Task 7: Notifikasi dan izin

*(menunggu persetujuan D3: `flutter_local_notifications`, `timezone`)*

**Files:**
- Create: `lib/app/services/prayer_notifier.dart`
- Modify: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml` (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, receiver plugin), `android/app/build.gradle.kts` (desugaring), `lib/app/modules/prayer/…` (sakelar dan keterangan izin), `app_bootstrap.dart`
- Test: `test/app/services/prayer_notifier_test.dart` (plugin dibungkus antarmuka `NotificationScheduler`, tiruan di tes)

**Interfaces:**
- Produces: `abstract interface class NotificationScheduler { Future<void> cancelPrayer(); Future<void> schedule(int id, DateTime utcInstant, String title, String body, {required bool exact}); Future<PermissionState> notificationPermission(); Future<PermissionState> exactAlarmPermission(); }`; `class PrayerNotifier { Future<void> reschedule(); }` memakai `PrayerClock.instantOf` + `tz.UTC`.

- [ ] **Step 1: Write the failing tests**: `reschedule` dua kali menghasilkan himpunan jadwal yang sama (tanpa duplikat, id deterministik dari tanggal+waktu); hanya waktu yang sakelarnya hidup dan belum lewat, maksimum 7 hari dan tidak melewati data cache; instan benar untuk wilayah WIT saat zona perangkat WIB; izin notifikasi ditolak → tidak menjadwalkan dan keterangan tampil; izin alarm tepat ditolak → `exact:false` dan keterangan; wilayah berganti atau sakelar berubah → batal lalu jadwal ulang; `unknownRegion` → semua jadwal dibatalkan.
- [ ] **Step 2–4: Run fail, implement, run pass.**
- [ ] **Step 5: Commit** terpisah: `feat: schedule prayer notifications` dan `build: add notification permissions and boot receiver`.

### Task 8: Penyelesaian

**Files:** `docs/STATUS.md`, `docs/PRD.md` (bila perlu), `docs/specs/2026-11-09-nura-v1-design.md` (7.x sesuai hasil)

- [ ] **Step 1:** Jalankan `flutter analyze` dan `flutter test` (`content.db` tidak berubah di fase ini).
- [ ] **Step 2:** Perbarui STATUS: fase, keputusan D1–D10, daftar uji perangkat pemilik (pilih wilayah, jadwal tampil offline setelah mode pesawat, "perkiraan" tanpa cache, wilayah WIT dengan perangkat WIB, notifikasi berbunyi tepat waktu, izin alarm ditolak, restart perangkat, aplikasi tidak dibuka 7 hari), risiko tersisa, dan Q3/Q4/Q5.
- [ ] **Step 3: Commit** `docs: update status after phase 5`.

## Spec coverage

| Spec | Task |
|---|---|
| 7.1 API sebulan sekali, `adhan` Subuh 20°/Isya 18°/Asar Syafi'i | 3, 4, 5 |
| 7.2 alur cache → API → hitung, sinkron < 7 hari | 4 |
| 7.3 provinsi + kab/kota, zona waktu wilayah, GPS/Q4 | 1, 4, 5 |
| 7.4 notifikasi 7 hari, penjadwalan ulang, izin 12+/13+, boot | 7 |
| 4 skema `user.db` (diubah D6) | 2 |
| 9 tabel error (API gagal → cadangan, izin ditolak) | 4, 5, 6, 7 |
| 10 tes jadwal (±2 menit Bontang/Jakarta, klien tiruan) | 3, 4, 5 |
