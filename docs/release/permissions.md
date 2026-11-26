# Izin Android Nura (build rilis)

Diambil dari manifest hasil gabungan dan APK rilis pada 2026-11-26.

| Izin | Asal | Alasan |
|---|---|---|
| `INTERNET` | aplikasi | Jadwal sholat dan audio, keduanya di balik sakelar |
| `ACCESS_NETWORK_STATE` | plugin/pustaka | Memeriksa koneksi sebelum memakai fitur online (`connectivity_plus`) |
| `POST_NOTIFICATIONS` | aplikasi | Pengingat sholat dan ayat/hadis harian (Android 13+, diminta saat pengingat dinyalakan) |
| `SCHEDULE_EXACT_ALARM` | aplikasi | Pengingat tepat pada waktunya |
| `RECEIVE_BOOT_COMPLETED` | aplikasi | Menjadwalkan ulang pengingat dan pembaruan widget setelah restart |
| `VIBRATE` | plugin/pustaka | Getar notifikasi |
| `WAKE_LOCK` | pustaka (WorkManager dan lain-lain) | Menyelesaikan pekerjaan singkat saat perangkat bangun |
| `com.technowstack.nura.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | AndroidX | Izin internal bertanda tangan; tidak terlihat pengguna |

## `FOREGROUND_SERVICE` dihapus (D8)

Satu-satunya yang menambahkannya adalah `androidx.work:work-runtime` (dibawa `home_widget`), dipakai bila sebuah worker memanggil `setForeground` atau berjalan sebagai expedited work. Pemeriksaan 2026-11-26:

- `HomeWidgetBackgroundWorker` tidak memakai keduanya, dan receiver pemicunya tidak dideklarasikan di manifest.
- Tidak ada widget Glance di aplikasi (jalur `startForegroundService` di Glance hanya untuk widget Glance).
- `ForegroundService` milik `flutter_local_notifications` tidak dideklarasikan dan `startForegroundService` tidak dipanggil.
- `DownloadService` Media3 (lewat `just_audio`) tidak dideklarasikan; audio hanya streaming saat aplikasi terlihat.

Dihapus dengan `tools:node="remove"`. Periksa ulang sebelum menambah audio latar belakang, WorkManager, atau menaikkan versi paket-paket ini.

## Pernyataan untuk `SCHEDULE_EXACT_ALARM`

**[KONFIRMASI]** Play Console mungkin tidak meminta formulir untuk izin ini (formulir khusus berlaku untuk `USE_EXACT_ALARM`, yang tidak dipakai Nura). Bila diminta:

> Nura is a Muslim prayer-time app. Users can turn on reminders for each of the five daily prayers, which must fire at the exact prayer time calculated for their chosen region. The exact alarm access is requested only when the user enables a reminder. If it is not granted, reminders are still delivered with inexact alarms and may be late.

Dengan izin yang sama, notifikasi harian dan pembaruan widget tengah malam juga memakai alarm tepat.

**Bila ditolak:** hapus `SCHEDULE_EXACT_ALARM` dari manifest (perbarui `test/release/android_manifest_test.dart`). Kode sudah memakai alarm tidak tepat bila izin tidak ada, jadi pengingat tetap datang tetapi bisa terlambat; keterangan di aplikasi dan deskripsi Play perlu disesuaikan, dan perilakunya diuji di perangkat.

## Cadangan otomatis (bukan izin)

`android:allowBackup="true"`, dibatasi aturan include ke `user.db` (beserta berkas pendamping SQLite) dan shared preferences, untuk cadangan akun Google dan pemindahan perangkat (`res/xml/data_extraction_rules.xml` Android 12+, `res/xml/backup_rules.xml` Android 11 ke bawah). `content.db`, `content.version`, gambar widget, dan cache tidak ikut. Salinan dikelola Android di akun Google pengguna; pengembang tidak dapat mengaksesnya. Dikunci oleh `test/android/backup_rules_test.dart`.
