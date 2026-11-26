<p align="center">
  <img src="assets/icon/play-store/icon-512.png" alt="Logo Nura" width="128">
</p>

<h1 align="center">Nura</h1>

<p align="center">
  <strong>Al-Qur'an, hadis, dan jadwal sholat dalam satu aplikasi yang tenang.</strong><br>
  Bisa dibaca tanpa internet. Tanpa akun, tanpa iklan, tanpa pelacakan.
</p>

<p align="center">
  Android · Bahasa Indonesia · Segera hadir
</p>

---

## Kenapa Nura

- **Selalu ada, walau tanpa sinyal.** Seluruh Al-Qur'an dan 38.102 hadis tersimpan di ponsel Anda.
- **Tidak mengganggu.** Tidak ada iklan, tidak perlu daftar, dan notifikasi hanya muncul bila Anda menyalakannya.
- **Nyaman dibaca.** Huruf Arab dan terjemahan bisa diperbesar, dengan tema terang dan gelap.

## Yang bisa Anda lakukan

### 📖 Membaca Al-Qur'an

- 114 surah dengan terjemahan Indonesia dan tafsir Kementerian Agama.
- Baca per surah, atau per juz tanpa terputus di antara surah.
- Tandai ayat, dan lanjutkan dari bacaan terakhir.
- Dengarkan murottal per ayat, per surah, atau satu juz penuh (butuh internet).

### 🕌 Menjelajahi hadis

- 9 kitab: Bukhari, Muslim, Abu Daud, Tirmidzi, Nasa'i, Ibnu Majah, Ahmad, Malik, dan Darimi.
- Simpan hadis pilihan, dan salin lengkap dengan rujukannya.

### 🔎 Mencari

Cari kata di Al-Qur'an maupun hadis, langsung dari ponsel.

### ⏰ Menjaga waktu sholat

- Jadwal untuk kabupaten dan kota di 34 provinsi.
- Hitung mundur menuju waktu sholat berikutnya, dan pengingat untuk tiap waktu.
- Tanggal Hijriah, dengan penyesuaian satu hari bila perlu.

### 🌤️ Satu ayat dan satu hadis setiap hari

Tampil di Beranda, di widget layar depan, dan bila mau, sebagai notifikasi harian.

## Mulai dalam tiga langkah

1. Buka Nura dan kenali isinya.
2. Pilih kabupaten atau kota Anda untuk mengunduh jadwal sholat.
3. Nyalakan pengingat yang Anda inginkan, atau lewati saja.

Semua bisa diubah kapan saja di tab **Setelan**.

## Privasi

Bookmark, bacaan terakhir, dan setelan Anda ada di ponsel Anda. Nura tidak punya akun, analitik, atau iklan.

Internet dipakai hanya untuk:

| Fitur | Yang dikirim ke [EQuran.id](https://equran.id) | Bawaan |
|---|---|---|
| Unduh jadwal sholat | Nama provinsi dan kabupaten atau kota, bulan, tahun | Menyala saat pengaturan awal, bisa dimatikan |
| Audio murottal | Nomor surah yang diputar | Mati |

Seperti permintaan internet pada umumnya, alamat IP Anda ikut terlihat oleh server. Tautan di halaman sumber dibuka di peramban Anda. Bila backup Android aktif, data pengguna dan setelan Nura ikut dicadangkan oleh Android.

Selengkapnya: [draf kebijakan privasi](docs/release/privacy-policy.md).

## Pertanyaan umum

**Apakah Nura gratis?**
Tidak ada iklan maupun pembelian di dalam aplikasi.

**Bisa dipakai tanpa internet?**
Al-Qur'an, hadis, pencarian, dan bookmark bisa. Jadwal sholat perlu diunduh dulu, dan audio selalu butuh internet.

**Sudah ada di Play Store?**
Belum. Nura sedang disiapkan untuk uji tertutup.

## Sumber dan terima kasih

- Teks Arab, terjemahan, dan tafsir Al-Qur'an: **Kementerian Agama RI**.
- Hadis: [**gadingnst/hadith-api**](https://github.com/gadingnst/hadith-api) (MIT), data asal tafsirq.com.
- Jadwal sholat, audio, dan tempat turun surah: [**EQuran.id**](https://equran.id). Audio: EQuran.id (sumber: Verse By Verse Quran).
- Batas juz: [**Tanzil.info**](https://tanzil.net), [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/), data diformat ulang.
- Font: Plus Jakarta Sans dan Scheherazade New (SIL OFL 1.1).
- Ikon: Material Symbols (Apache 2.0).

Menemukan salah ketik atau teks yang keliru? Mohon laporkan lewat *Issues* di repositori ini.

---

<details>
<summary><strong>Untuk pengembang</strong></summary>

### Menjalankan

Butuh Flutter 3.44 atau lebih baru dan Android SDK platform 37. Di Linux: `sudo apt install libsqlite3-dev`.

```sh
flutter pub get
tool/prepare_content.sh   # wajib pada clone baru: membuat assets/db/content.db
flutter run
```

### Memeriksa

```sh
flutter analyze
flutter test
```

### Build rilis

Ikuti [docs/release/signing.md](docs/release/signing.md). Keystore dan `android/key.properties` tidak boleh masuk git.

### Struktur

```
data-source/   JSON asli (sumber kebenaran, jangan diedit)
tool/          skrip pembuat, pemeriksa, dan pengambil data
lib/app/       core, data, services, modules, routes
docs/          PRD, spec, rencana, desain, status, dokumen rilis
test/
```

Baca [AGENTS.md](AGENTS.md) sebelum mengubah kode. Kondisi proyek dan syarat rilis ada di [docs/STATUS.md](docs/STATUS.md), lisensi data di [data-source/README.md](data-source/README.md).

</details>
