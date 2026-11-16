/// A Quran reciter available for audio streaming.
class Qari {
  const Qari(this.id, this.name);

  final String id;
  final String name;
}

const String kDefaultQariId = '05';

const List<Qari> kQaris = [
  Qari('01', 'Abdullah Al-Juhany'),
  Qari('02', 'Abdul Muhsin Al-Qasim'),
  Qari('03', 'Abdurrahman As-Sudais'),
  Qari('04', 'Ibrahim Al-Dossari'),
  Qari('05', 'Misyari Rasyid Al-Afasi'),
  Qari('06', 'Yasser Al-Dosari'),
];

Qari? qariById(String id) => kQaris.where((q) => q.id == id).firstOrNull;
