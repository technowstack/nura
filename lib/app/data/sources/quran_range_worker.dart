import 'dart:io';
import 'dart:isolate';

import '../models/ayah.dart';
import '../repositories/sqlite_quran_repository.dart';
import 'content_database.dart';

List<Object?> ayahToList(Ayah a) => [
  a.surahNumber,
  a.ayahNumber,
  a.arab,
  a.translation,
  a.tafsir,
];

Ayah ayahFromList(List<Object?> l) => Ayah(
  surahNumber: l[0] as int,
  ayahNumber: l[1] as int,
  arab: l[2] as String,
  translation: l[3] as String,
  tafsir: l[4] as String,
);

/// Worker isolate entry; same protocol as hadithWorkerMain. [init] is
/// `[SendPort replies, String dbPath]`; the one op is `range [s1, a1, s2, a2]`.
Future<void> quranRangeWorkerMain(List<Object> init) async {
  final replies = init[0] as SendPort;
  final ContentDatabase db;
  try {
    db = ContentDatabase.open(File(init[1] as String));
  } catch (e) {
    replies.send(['error', '$e']);
    return;
  }
  final repo = SqliteQuranRepository(db);
  final inbox = ReceivePort();
  inbox.listen((Object? msg) {
    if (msg == 'close') {
      db.close();
      inbox.close();
      return;
    }
    final req = msg as List<Object?>; // shortcut: only our client sends here
    final id = req[0] as int;
    final a = req[2] as List<Object?>;
    try {
      if (req[1] != 'range') throw StateError('unknown op ${req[1]}');
      final rows = repo.getAyahRange(
        AyahRef(a[0] as int, a[1] as int),
        AyahRef(a[2] as int, a[3] as int),
      );
      replies.send([id, true, rows.map(ayahToList).toList()]);
    } catch (e) {
      replies.send([id, false, '$e']);
    }
  });
  replies.send(['ready', inbox.sendPort]);
}
