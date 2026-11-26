# Draf Data Safety (Play Console), Nura

Status: DRAF, keputusan D9 = B (konservatif). Bukan nasihat hukum. Semua jawaban bertanda **[KONFIRMASI]** harus diperiksa pemilik terhadap definisi terbaru di Play Console sebelum dikirim. Diverifikasi terhadap kode pada 2026-11-26.

## Fakta dari kode

| Hal | Isi | Kapan |
|---|---|---|
| Jadwal sholat | `POST https://equran.id/api/v2/shalat` berisi nama provinsi, nama kabupaten/kota, bulan, tahun | Hanya bila "Unduh jadwal sholat" menyala dan wilayah sudah dipilih. Bulan berjalan dan berikutnya, saat aplikasi membutuhkan jadwal yang belum tersimpan |
| Audio: daftar berkas | `GET https://equran.id/api/v2/surat/{nomor surah}` | Hanya bila "Fitur Online" menyala dan pengguna memutar audio |
| Audio: berkas | `GET https://cdn.equran.id/...mp3` (alamat dari jawaban di atas; menunjuk ayat dan qari yang dipilih) | Sama |
| Ikut terkirim | Alamat IP dan header HTTP teknis standar, seperti permintaan web mana pun | Setiap permintaan di atas |

- "Unduh jadwal sholat": menyala secara bawaan di onboarding, baru disimpan dan dipakai setelah pengguna mengetuk "Lanjut". Tanpa onboarding bawaannya mati. Bisa dimatikan di Pengaturan.
- "Fitur Online": mati secara bawaan.
- Tidak ada GPS atau izin lokasi, akun, analitik, iklan, atau pelaporan kerusakan pihak ketiga.
- Tersimpan di perangkat: bookmark, terakhir dibaca, setelan, wilayah, jadwal sholat. Aplikasi tidak mengunggahnya.
- Tautan di Sumber & Atribusi membuka browser (di luar aplikasi, tunduk pada kebijakan situs tujuan).
- Cadangan otomatis Android menyala (`allowBackup`, keputusan pemilik 2026-11-26), dibatasi ke `user.db` dan shared preferences (`res/xml/backup_rules.xml`, `res/xml/data_extraction_rules.xml`). Salinan disimpan Android di akun Google pengguna atau dipindahkan antar perangkat; pengembang tidak dapat mengaksesnya. **[KONFIRMASI]** periksa terhadap definisi Play apakah cadangan sistem ini memengaruhi jawaban di bawah.

## Usulan jawaban

| Pertanyaan | Usulan | Alasan |
|---|---|---|
| Apakah aplikasi mengumpulkan atau membagikan data pengguna? | Ya **[KONFIRMASI]** | Data keluar dari perangkat ke pihak ketiga saat fitur online dipakai |
| Lokasi > Perkiraan lokasi: dikumpulkan | Ya **[KONFIRMASI]** | Wilayah pilihan manual (kabupaten/kota) dan IP diperlakukan konservatif sebagai perkiraan lokasi |
| Lokasi > Perkiraan lokasi: dibagikan | Ya **[KONFIRMASI]** | Penerimanya equran.id, bukan penyedia layanan terikat kontrak dengan pengembang |
| Diproses sementara (ephemeral)? | Tidak **[KONFIRMASI]** | Retensi log di equran.id tidak diketahui |
| Wajib atau opsional? | Opsional (pengguna bisa memilih) **[KONFIRMASI]** | Bisa dimatikan; catatan: sakelar jadwal menyala secara bawaan di onboarding |
| Tujuan | Fungsi aplikasi | Mengambil jadwal wilayah; memutar audio |
| Nomor surah/qari sebagai "Aktivitas aplikasi"? | Tidak dideklarasikan **[KONFIRMASI]** | Hanya parameter untuk mengambil konten, tanpa pengenal pengguna; equran.id tetap bisa melihatnya bersama IP |
| Jenis data lain (pribadi, keuangan, kontak, pengenal perangkat, dll.) | Tidak | Tidak ada kode yang mengumpulkannya |
| Dienkripsi saat transit? | Ya | Semua alamat `https`; URL audio selain `https://cdn.equran.id` ditolak |
| Pengguna bisa meminta penghapusan data? | Tidak ada mekanisme **[KONFIRMASI]** | Tanpa akun; data lokal terhapus lewat hapus data/copot aplikasi; data di log equran.id di luar kendali pengembang |
| Pembuatan akun | Tidak ada | |
| Iklan | Tidak | |

Sebelum dikirim: baca https://equran.id/terms (Q3) dan periksa dokumentasi pustaka pihak ketiga bila versinya berubah.
