# Penandatanganan rilis

Keystore, `key.properties`, dan kata sandi tidak pernah masuk git, log, laporan, atau obrolan.

## 1. Buat keystore (dijalankan pemilik, sekali saja)

Bila keystore sudah ada, lewati langkah ini; jangan menimpanya.

```sh
mkdir -p "$HOME/secrets/nura"
keytool -genkeypair -v -keystore "$HOME/secrets/nura/nura-upload.jks" \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

`keytool` meminta kata sandi secara interaktif. Simpan di pengelola kata sandi. Simpan keystore di luar folder repo.

## 2. Isi `android/key.properties`

Salin `android/key.properties.example` menjadi `android/key.properties`, lalu isi:

- `storeFile`: path **absolut** ke keystore (`~` dan `$HOME` tidak diterjemahkan, tanpa tanda kutip). Path relatif dihitung dari folder `android/`.
- `storePassword`, `keyPassword`: kata sandi Anda. Karakter `\` harus ditulis `\\`.
- `keyAlias`: `upload`, atau alias yang dipakai saat membuat keystore.

Tanpa berkas yang lengkap dan keystore yang ditemukan, build rilis gagal. Tidak ada cadangan ke kunci debug. Build debug dan test tidak terpengaruh.

## 3. Cadangan

Simpan salinan keystore dan kata sandinya di sedikitnya dua tempat di luar laptop ini (misalnya pengelola kata sandi dan media terenkripsi). Jangan hanya mengandalkan satu disk.

## 4. Play App Signing

Aktifkan Play App Signing saat unggahan pertama (bawaan untuk aplikasi baru). Google memegang kunci penandatanganan aplikasi; keystore di atas hanya **kunci unggah**. Bila kunci unggah hilang atau bocor, pemilik bisa meminta penggantian lewat Play Console.

## 5. Build

```sh
tool/prepare_content.sh
flutter build appbundle --release
```

Hasil: `build/app/outputs/bundle/release/app-release.aab`. Naikkan angka setelah `+` di `version` (`pubspec.yaml`) pada setiap unggahan.

## 6. Verifikasi tanda tangan

```sh
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

Harus muncul `jar verified.`, dan nama pada sertifikat harus nama yang Anda isi di `keytool`, bukan `CN=Android Debug`. Peringatan sertifikat self-signed wajar.

## Jangan di-commit

`android/key.properties`, `*.jks`, `*.keystore`, kata sandi, dan ekspor kunci. Periksa `git status` sebelum commit.
