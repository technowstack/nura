/// One credit card on the Sources & Attribution screen.
class Attribution {
  const Attribution({
    required this.title,
    required this.credits,
    required this.licenseNote,
    this.links = const [],
  });

  final String title;
  final List<String> credits;
  final String licenseNote;

  /// Shown as copyable text; the app has no url_launcher.
  final List<String> links;
}

const kTanzilLicenseUrl = 'https://creativecommons.org/licenses/by/3.0/';

/// Single data source for the screen, in display order. Wording follows
/// data-source/README.md and docs/PRD.md section 6; pending licenses
/// (Q6, Q7) stay neutral.
const List<Attribution> kAttributions = [
  Attribution(
    title: 'Al-Qur\'an',
    credits: [
      'Teks Arab, terjemahan Indonesia, dan tafsir: Kementerian Agama RI',
    ],
    licenseNote: 'Status lisensi dan tashih dalam peninjauan.',
  ),
  Attribution(
    title: 'Hadis 9 kitab',
    credits: ['gadingnst/hadith-api (lisensi MIT), data asal tafsirq.com'],
    licenseNote:
        'Lisensi MIT mencakup repositori. Status lisensi teks terjemahan '
        'dari sumber asal dalam peninjauan.',
    links: ['https://github.com/gadingnst/hadith-api'],
  ),
  Attribution(
    title: 'EQuran.id',
    credits: [
      'Jadwal sholat: EQuran.id (sumber Bimas Islam Kemenag)',
      'Audio: EQuran.id (sumber: Verse By Verse Quran)',
      'Tempat turun surah: EQuran.id (sumber Kemenag)',
    ],
    licenseNote: 'Pemakaian mengikuti ketentuan layanan EQuran.id.',
    links: ['https://equran.id'],
  ),
  Attribution(
    title: 'Tanzil.info',
    credits: [
      'Pemetaan juz: Tanzil.info (metadata Tanzil, Creative Commons '
          'Attribution 3.0; kredit ke Tanzil.info, tautan lisensi '
          '$kTanzilLicenseUrl, data diformat ulang)',
    ],
    licenseNote:
        'Hak cipta (C) 2008-2009 Tanzil.info. Creative Commons Attribution '
        '3.0. Data diformat ulang; Tanzil tidak mendukung Nura.',
    links: [kTanzilLicenseUrl, 'https://tanzil.net'],
  ),
  Attribution(
    title: 'Plus Jakarta Sans',
    credits: ['Copyright 2020 The Plus Jakarta Sans Project Authors'],
    licenseNote: 'SIL Open Font License 1.1.',
    links: ['https://github.com/tokotype/PlusJakartaSans'],
  ),
  Attribution(
    title: 'Scheherazade New',
    credits: [
      'Copyright (c) 1994-2026, SIL Global, with Reserved Font Names '
          '"Scheherazade" and "SIL"',
    ],
    licenseNote: 'SIL Open Font License 1.1.',
    links: ['https://www.sil.org/'],
  ),
  Attribution(
    title: 'Material Symbols',
    credits: ['Ikon: Material Symbols (paket material_symbols_icons)'],
    licenseNote: 'Apache License 2.0.',
  ),
  Attribution(
    title: 'Daftar ayat harian',
    credits: ['Daftar ayat harian: disusun pemilik proyek'],
    licenseNote: 'Daftar sementara; kurasi final menyusul.',
  ),
];
