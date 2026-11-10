# data-source

Folder ini **read-only** dan menjadi **sumber kebenaran** data konten Nura. Jangan edit file di sini. Semua perubahan isi harus lewat keputusan eksplisit dan memperbarui `CHECKSUMS.sha256`.

## Sumber

| Data | Folder | Sumber |
|---|---|---|
| Al-Qur'an (teks Arab, terjemahan Indonesia, tafsir) | `quran/` | Kementerian Agama RI (tafsir: "Aplikasi Quran Kementrian Agama Republik Indonesia") |
| Hadis 9 kitab (teks Arab, terjemahan Indonesia) | `hadith/` | https://github.com/gadingnst/hadith-api (lisensi MIT), data asal tafsirq.com |

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

## Verifikasi checksum

Dari dalam folder `data-source/`:

```sh
sha256sum -c CHECKSUMS.sha256
```

Semua baris harus berstatus `OK` (123 file). Path di `CHECKSUMS.sha256` relatif terhadap folder ini.

## Catatan keterbatasan

- Folder `assets/` asli (sebelum dipindahkan ke sini) tidak tersedia untuk dibandingkan. Checksum di sini hanya membuktikan file tidak berubah **sejak dipindahkan**, bukan bahwa isinya identik dengan sumber asli.
- Verifikasi isi ke sumber asli (misalnya `gadingnst/hadith-api` untuk hadis) dijadwalkan sebagai tugas terpisah.
- Status lisensi teks Quran (tashih LPMQ) dan terjemahan hadis dari sumber asal masih perlu dikonfirmasi (lihat `docs/PRD.md` bagian 10).
