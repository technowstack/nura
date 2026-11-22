# data-source

Folder ini **read-only** dan menjadi **sumber kebenaran** data konten Nura. Jangan edit file di sini. Semua perubahan isi harus lewat keputusan eksplisit dan memperbarui `CHECKSUMS.sha256`.

## Sumber

| Data | Folder | Sumber |
|---|---|---|
| Al-Qur'an (teks Arab, terjemahan Indonesia, tafsir) | `quran/` | Kementerian Agama RI (tafsir: "Aplikasi Quran Kementrian Agama Republik Indonesia") |
| Hadis 9 kitab (teks Arab, terjemahan Indonesia) | `hadith/` | https://github.com/gadingnst/hadith-api (lisensi MIT), data asal tafsirq.com |
| Wilayah jadwal sholat (34 provinsi, 517 kab/kota, nama persis dari API) | `meta/prayer_regions.json` | https://equran.id/api/v2/shalat (snapshot `fetched_at` 2026-11-15, dihasilkan `tool/fetch_prayer_regions.dart`) |
| Tempat turun 114 surah (`makkiyah` 84, `madaniyah` 30) | `meta/surah_info.json` | https://equran.id/api/v2/surat (data Kemenag RI via equran.id; field `tempatTurun`: Mekah -> `makkiyah`, Madinah -> `madaniyah`; jumlah ayat dicocokkan dengan `quran/`). Snapshot `fetched_at` 2026-11-21T23:03:30Z (2026-11-22 WIB), dihasilkan `tool/fetch_surah_info.dart` |
| Batas 30 juz (awal dari Tanzil, akhir dihitung dari awal juz berikutnya dan jumlah ayat per surah di `quran/`) | `meta/juz.json` | Tanzil Quran Metadata, https://tanzil.net/res/text/metadata/quran-data.xml (elemen `<juz index sura aya>`). Snapshot `fetched_at` 2026-11-21T23:03:30Z (2026-11-22 WIB), dihasilkan `tool/fetch_juz.dart`. Lisensi: lihat bagian Lisensi data juz |
| Pengecualian manual hadis harian (`[{"book": "bukhari", "number": 34}]`, awalnya `[]`) | `meta/daily_hadith_exclude.json` | Keputusan pemilik proyek (2026-11-15), dibaca `tool/build_content_db.dart` |
| Daftar ayat harian SEMENTARA untuk uji widget (94:6, 2:286, 13:28; bukan kurasi final, Q9 masih terbuka) | `meta/daily_ayah.json` | Keputusan pemilik proyek (2026-11-15), dibaca `tool/build_content_db.dart` |

## Isi

- **Quran:** 114 file (`1.json` sampai `114.json`), satu surah per file. Total 114 surah dan 6.236 ayat.
- **Hadis:** 9 kitab, total 38.102 hadis. Setiap file adalah list `{number, arab, id}`.

| Kitab | File | Jumlah hadis |
|---|---|---|
| Bukhari | `hadith/bukhari.json` | 6.638 |
| Muslim | `hadith/muslim.json` | 4.930 |
| Abu Daud | `hadith/abu-daud.json` | 4.419 |
| Tirmidzi | `hadith/tirmidzi.json` | 3.625 |
| Nasai | `hadith/nasai.json` | 5.364 |
| Ibnu Majah | `hadith/ibnu-majah.json` | 4.285 |
| Ahmad | `hadith/ahmad.json` | 4.305 |
| Malik | `hadith/malik.json` | 1.587 |
| Darimi | `hadith/darimi.json` | 2.949 |

## Format `surah_info.json` dan `juz.json`

Keduanya objek `{"source", "fetched_at", "surahs"|"juz": [...]}` seperti `prayer_regions.json`. Builder juga masih menerima daftar polos.
Tempat turun mengikuti equran.id apa adanya. Sebagai informasi, klasifikasi Tanzil (`type` di `quran-data.xml`) berbeda untuk dua surah: 113 (Al-Falaq) dan 114 (An-Nas), equran.id `madaniyah` dan Tanzil `Meccan`. Tidak ada yang ditimpa.

## Lisensi data juz (Tanzil)

- Sumber: https://tanzil.net/res/text/metadata/quran-data.xml, diambil 2026-11-22.
- Hak cipta (atribut `copyright` di berkas): `(C) 2008-2009 Tanzil.info`. Lisensi (atribut `license`): `cc-by`; `quran-data.js` dari Tanzil menyebut "License: Creative Commons Attribution 3.0".
- Lisensi: Creative Commons Attribution 3.0 Unported (CC BY 3.0), https://creativecommons.org/licenses/by/3.0/
- Syarat menurut halaman lisensi: "Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use." Artinya: cantumkan kredit ke Tanzil.info, sertakan tautan lisensi di atas, dan nyatakan jika data diubah, serta jangan menyiratkan Tanzil mendukung Nura.
- Perubahan di sini: hanya awal juz (surah, ayah) yang diambil dan diformat ulang ke JSON; akhir tiap juz dihitung dari awal juz berikutnya. Kredit ini perlu muncul di halaman Tentang/atribusi aplikasi.

## Verifikasi checksum

Dari dalam folder `data-source/`:

```sh
sha256sum -c CHECKSUMS.sha256
```

Semua baris harus berstatus `OK` (128 file). Path di `CHECKSUMS.sha256` relatif terhadap folder ini.

## Catatan keterbatasan

- Folder `assets/` asli (sebelum dipindahkan ke sini) tidak tersedia untuk dibandingkan. Checksum di sini hanya membuktikan file tidak berubah **sejak dipindahkan**, bukan bahwa isinya identik dengan sumber asli.
- Verifikasi isi ke sumber asli (misalnya `gadingnst/hadith-api` untuk hadis) dijadwalkan sebagai tugas terpisah.
- Status lisensi teks Quran (tashih LPMQ) dan terjemahan hadis dari sumber asal masih perlu dikonfirmasi (lihat `docs/PRD.md` bagian 10).
