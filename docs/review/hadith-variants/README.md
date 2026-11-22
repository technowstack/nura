# Hadis: dua varian desain untuk dipilih

Mockup (hanya gambar, tanpa implementasi di `lib/`). Data nyata: kitab dari `hadithBookNames` dan `data-source/README.md`; hadis dari `data-source/hadith/bukhari.json`; hadis harian dari `content.db` (`daily_hadith`, urutan 4 daftar `default`: Muslim No. 4360). Detail memakai **Bukhari No. 14** (Arab 405 karakter, terjemahan 495 karakter). Frame 360 dp, pixelRatio 2.
Render ulang: `TMPDIR=$HOME/.cache/nura-tmp flutter test --dart-define=RENDER_HADITH_VARIANTS=true test/review/hadith_variants_render_test.dart`

## Varian A "Kartu"
Kontinuitas dengan kartu ayat. Daftar: `NuraCard` per hadis, `OrnamentBadge` nomor di kiri, nama kitab kecil (iconAccent), pratinjau 3 baris, ikon bookmark terisi (primary) di kanan bila ditandai. Detail: kartu hero (hero/onHero/onHeroAccent: Kitab, Nomor, Jumlah hadis), kartu Arab, kartu terjemahan, baris "HR. Bukhari No. 14", sel aksi salin dan bookmark, lalu Sebelumnya/Berikutnya.
- Palet: surface, surfaceContainerLowest (kartu), outlineVariant, hero, iconAccent, primary. Tipe: titleMedium/labelMedium/bodyMedium, arabicCard, translation.
- Elemen berani: kartu hero. Dibuang: tombol di app bar (pindah ke sel aksi), nama Arab kitab.

## Varian B "Lembar"
Membaca dulu, tenang. Daftar: baris datar di atas surface, pemisah hairline, nomor sebagai angka besar polos (iconAccent, SemiBold) di kolom kiri tetap, pratinjau 3 baris, bookmark di tepi kanan. Detail: tanpa hero; capsule "HR. Bukhari No. 14" (primaryContainer) kiri atas; Arab langsung di surface (arabicReading 28/56); pembatas bintang delapan titik (OrnamentBadge tanpa label) di tengah garis hairline; terjemahan bodyLarge leading 30; pil aksi melayang di bawah (surfaceContainerLow, radius xl, border outlineVariant, salin dan bookmark); Sebelumnya/Berikutnya tetap.
- Elemen berani: pembatas bintang + stempel referensi. Dibuang: kartu, border, hero, kotak di sekeliling teks.

## Paritas fungsi
| Fungsi app saat ini | A | B |
|---|---|---|
| Daftar kitab, nama + "N hadis", chevron | sama (satu desain K) | sama |
| Daftar hadis: nomor, pratinjau 200 karakter / 3 baris, penanda bookmark | ya | ya |
| Detail: Arab RTL + terjemahan (tanpa potong) | ya | ya |
| Bookmark (toggle) dan salin (+ referensi "HR. Kitab No. n") | sel aksi | pil aksi |
| Sebelumnya / Berikutnya (nonaktif di ujung) | ya | ya |
| Catatan "Teks hadis ini terpotong di sumber data" | tidak digambar (hadis contoh tidak terpotong); letak: bawah kartu terjemahan | bawah terjemahan |
| Bagikan | ditunda Fase 8, tidak digambar | sama |
| Loading/kosong/error | tidak berubah | tidak berubah |

## Gambar
| Layar | Light | Dark |
|---|---|---|
| K Daftar kitab | light/kitab-light.png | dark/kitab-dark.png |
| L-A Daftar hadis | light/daftar-A-light.png | dark/daftar-A-dark.png |
| L-B Daftar hadis | light/daftar-B-light.png | dark/daftar-B-dark.png |
| D-A Detail | light/detail-A-light.png | dark/detail-A-dark.png |
| D-B Detail | light/detail-B-light.png | dark/detail-B-dark.png |
| H Kartu harian Beranda | light/harian-light.png | dark/harian-dark.png |

## H: kartu hadis harian
`DailyHadithCard` yang ada dipakai apa adanya (label iconAccent, Arab arabicCard, terjemahan, referensi, "Baca selengkapnya", maks 6 baris). Sudah sejalan dengan bahasa Putaran 1.5; dipertahankan. Usulan saja (tidak digambar): rujukan dan "Baca selengkapnya" sekarang bertumpuk dua baris saat referensi panjang; bisa dijadikan satu baris. Hadis tidak punya tombol Bagikan (ditunda).

## Pekerjaan baru bila dipilih
- A: widget daftar (kartu + badge), `HadithHeroCard` (mirip `SurahHeaderCard`), sel aksi (salin dari `AyahActionBar` diekstrak/dipakai ulang), baris referensi. Tidak ada string baru selain label hero: "Kitab", "Nomor", "Jumlah hadis".
- B: baris datar, capsule referensi, pembatas bintang (varian `OrnamentBadge` tanpa label), pil aksi melayang. String baru: tidak ada.
- Keduanya: kartu kitab di K memakai `NuraCard` + `NuraIcons.menuBook`; aksi pindah dari app bar ke sel/pil.

## Pertanyaan untuk pemilik
1. Data tidak punya nama kitab dalam Arab; tidak ditampilkan. Sumber mana bila diinginkan (varian A bisa memuatnya di hero)?
2. Bagikan ditunda ke Fase 8: sel aksi ketiga kelak.
3. Prev/next: dipertahankan sebagai tombol di akhir konten; di B bisa jadi geser/ikon di pil.
4. Hadis panjang (mis. Bukhari No. 3, 3.329 karakter Arab): tampilkan penuh (sekarang) atau potong + "Baca selengkapnya"?
5. Nama kitab di daftar: "Shahih Bukhari" (nama app) vs referensi singkat "Bukhari". Mockup memakai nama app di daftar dan singkat di referensi.
6. Teks terjemahan dimulai dengan rantai perawi ("Telah menceritakan kepada kami [..]") sehingga pratinjau daftar semuanya mirip; pertimbangkan pratinjau dari matan (offset seperti hadis harian).

## Keputusan (2026-11-22)

Pemilik memilih **varian A** untuk daftar dan detail hadis. Implementasi: `docs/plans/2026-11-22-nura-hadith-ui.md`. Varian B tidak dikerjakan.
