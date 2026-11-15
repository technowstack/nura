import 'dart:io';
import 'dart:isolate';

import '../models/hadith.dart';
import '../models/hadith_book.dart';
import '../repositories/sqlite_hadith_repository.dart';
import 'content_database.dart';

// Wire format: only plain data (strings, ints, bools, lists, maps) crosses
// the isolate boundary. All (de)serialisation lives in this file.

Map<String, Object?> bookToMap(HadithBook b) => {
  'slug': b.slug,
  'name': b.name,
  'count': b.hadithCount,
  'sort': b.sortOrder,
};

HadithBook bookFromMap(Map<Object?, Object?> m) => HadithBook(
  slug: m['slug'] as String,
  name: m['name'] as String,
  hadithCount: m['count'] as int,
  sortOrder: m['sort'] as int,
);

Map<String, Object?> refToMap(HadithRef r) => {
  'slug': r.slug,
  'number': r.number,
};

HadithRef refFromMap(Map<Object?, Object?> m) =>
    HadithRef(m['slug'] as String, m['number'] as int);

Map<String, Object?> hadithToMap(Hadith h) => {
  'ref': refToMap(h.ref),
  'book': h.bookName,
  'arab': h.arab,
  'tr': h.translation,
  'trLen': h.translationLength,
  'arabCut': h.arabTruncated,
  'trCut': h.translationTruncated,
};

Hadith hadithFromMap(Map<Object?, Object?> m) => Hadith(
  ref: refFromMap(m['ref'] as Map<Object?, Object?>),
  bookName: m['book'] as String,
  arab: m['arab'] as String,
  translation: m['tr'] as String,
  translationLength: m['trLen'] as int,
  arabTruncated: m['arabCut'] as bool,
  translationTruncated: m['trCut'] as bool,
);

Map<String, Object?> pageToMap(HadithPage p) => {
  'items': [
    for (final i in p.items)
      {'ref': refToMap(i.ref), 'preview': i.preview, 'len': i.length},
  ],
  'more': p.hasMore,
};

HadithPage pageFromMap(Map<Object?, Object?> m) => HadithPage(
  items: [
    for (final i in m['items'] as List<Object?>)
      HadithSummary(
        ref: refFromMap(
          (i as Map<Object?, Object?>)['ref'] as Map<Object?, Object?>,
        ),
        preview: i['preview'] as String,
        length: i['len'] as int,
      ),
  ],
  hasMore: m['more'] as bool,
);

/// Worker isolate entry. [init] is `[SendPort replies, String dbPath]`.
/// Replies `['ready', SendPort]` or `['error', message]`; afterwards each
/// request `[id, op, args]` gets `[id, true, result]` or `[id, false, msg]`.
/// The message `'close'` closes the connection and ends the isolate.
Future<void> hadithWorkerMain(List<Object> init) async {
  final replies = init[0] as SendPort;
  final ContentDatabase db;
  try {
    db = ContentDatabase.open(File(init[1] as String));
  } catch (e) {
    replies.send(['error', '$e']);
    return;
  }
  final repo = SqliteHadithRepository(db);
  final inbox = ReceivePort();
  inbox.listen((Object? msg) async {
    if (msg == 'close') {
      db.close();
      inbox.close();
      return;
    }
    final req = msg! as List<Object?>; // shortcut: only our client sends here
    final id = req[0] as int;
    final a = req[2] as List<Object?>;
    try {
      final Object? result = switch (req[1]) {
        'listBooks' => [for (final b in await repo.listBooks()) bookToMap(b)],
        'listPage' => pageToMap(
          await repo.listPage(
            a[0] as String,
            afterNumber: a[1] as int,
            limit: a[2] as int,
          ),
        ),
        'getHadith' => hadithToMap(
          await repo.getHadith(HadithRef(a[0] as String, a[1] as int)),
        ),
        'neighbor' => switch (await repo.neighbor(
          HadithRef(a[0] as String, a[1] as int),
          next: a[2] as bool,
        )) {
          final HadithRef r => refToMap(r),
          null => null,
        },
        final op => throw StateError('unknown op $op'),
      };
      replies.send([id, true, result]);
    } catch (e) {
      replies.send([id, false, '$e']);
    }
  });
  replies.send(['ready', inbox.sendPort]);
}
