import 'dart:io';
import 'dart:isolate';

import 'package:flutter/painting.dart';

import '../../core/errors.dart';
import '../../core/search_query.dart';
import '../../core/search_snippet.dart';
import '../models/hadith.dart';
import '../models/search_hit.dart';
import '../repositories/sqlite_search_repository.dart';
import 'content_database.dart';

// Wire format: only plain data (strings, ints, bools, lists, maps) crosses
// the isolate boundary. All (de)serialisation lives in this file.

Map<String, Object?> queryToMap(ParsedQuery q) => {
  'status': q.status.name,
  'arabic': q.isArabic,
  'tokens': q.tokens,
  'match': q.match,
  'like': q.likePatterns,
};

ParsedQuery queryFromMap(Map<Object?, Object?> m) => ParsedQuery(
  status: QueryStatus.values.byName(m['status'] as String),
  isArabic: m['arabic'] as bool,
  tokens: (m['tokens'] as List<Object?>).cast<String>(),
  match: m['match'] as String,
  likePatterns: (m['like'] as List<Object?>).cast<String>(),
);

Map<String, Object?> _snippetToMap(Snippet s) => {
  'text': s.text,
  // Flat [start, end, start, end, ...].
  'hl': [
    for (final r in s.highlights) ...[r.start, r.end],
  ],
  'cutStart': s.cutStart,
  'cutEnd': s.cutEnd,
};

Snippet _snippetFromMap(Map<Object?, Object?> m) {
  final hl = (m['hl'] as List<Object?>).cast<int>();
  return Snippet(
    text: m['text'] as String,
    highlights: [
      for (var i = 0; i < hl.length; i += 2)
        TextRange(start: hl[i], end: hl[i + 1]),
    ],
    cutStart: m['cutStart'] as bool,
    cutEnd: m['cutEnd'] as bool,
  );
}

Map<String, Object?> _hitToMap(SearchHit h) => {
  'id': h.rowId,
  'snippet': _snippetToMap(h.snippet),
  ...switch (h) {
    AyahSearchHit() => {
      'surah': h.surahNumber,
      'ayah': h.ayahNumber,
      'name': h.surahName,
    },
    HadithSearchHit() => {
      'slug': h.ref.slug,
      'number': h.ref.number,
      'book': h.bookName,
    },
  },
};

SearchHit _hitFromMap(Map<Object?, Object?> m) {
  final rowId = m['id'] as int;
  final snippet = _snippetFromMap(m['snippet'] as Map<Object?, Object?>);
  if (m.containsKey('surah')) {
    return AyahSearchHit(
      rowId: rowId,
      snippet: snippet,
      surahNumber: m['surah'] as int,
      ayahNumber: m['ayah'] as int,
      surahName: m['name'] as String,
    );
  }
  return HadithSearchHit(
    rowId: rowId,
    snippet: snippet,
    ref: HadithRef(m['slug'] as String, m['number'] as int),
    bookName: m['book'] as String,
  );
}

Map<String, Object?> searchPageToMap(SearchPage p) => {
  'hits': [for (final h in p.hits) _hitToMap(h)],
  'more': p.hasMore,
};

SearchPage searchPageFromMap(Map<Object?, Object?> m) => SearchPage(
  hits: [
    for (final h in m['hits'] as List<Object?>)
      _hitFromMap(h as Map<Object?, Object?>),
  ],
  hasMore: m['more'] as bool,
);

/// Worker isolate entry. [init] is `[SendPort replies, String dbPath]`.
/// Replies `['ready', SendPort]` or `['error', message]`; afterwards each
/// request `[id, op, args]` gets `[id, true, result]` or `[id, false, msg]`.
/// The message `'close'` closes the connection and ends the isolate.
Future<void> searchWorkerMain(List<Object> init) async {
  final replies = init[0] as SendPort;
  final ContentDatabase db;
  try {
    db = ContentDatabase.open(File(init[1] as String));
  } catch (e) {
    replies.send(['error', '$e']);
    return;
  }
  final repo = SqliteSearchRepository(db);
  final inbox = ReceivePort();
  inbox.listen((Object? msg) async {
    if (msg == 'close') {
      db.close();
      inbox.close();
      return;
    }
    final req = msg as List<Object?>; // shortcut: only our client sends here
    final id = req[0] as int;
    final a = req[2] as List<Object?>;
    try {
      final q = queryFromMap(a[0] as Map<Object?, Object?>);
      final SearchPage page = switch (req[1]) {
        'searchAyah' => await repo.searchAyah(
          q,
          afterRowId: a[1] as int,
          limit: a[2] as int,
        ),
        'searchHadith' => await repo.searchHadith(
          q,
          bookSlug: a[3] as String?,
          afterRowId: a[1] as int,
          limit: a[2] as int,
        ),
        final op => throw StateError('unknown op $op'),
      };
      replies.send([id, true, searchPageToMap(page)]);
    } on ContentUnavailable catch (e) {
      // The client rewraps in ContentUnavailable; send the bare message.
      replies.send([id, false, e.message]);
    } catch (e) {
      replies.send([id, false, '$e']);
    }
  });
  replies.send(['ready', inbox.sendPort]);
}
