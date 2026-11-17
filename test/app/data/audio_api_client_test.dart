import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/sources/audio_api_client.dart';
import 'package:nura/app/data/sources/audio_api_exception.dart';

String _fixture() =>
    File('test/fixtures/audio/surat_94.json').readAsStringSync();

Map<String, dynamic> _json() => jsonDecode(_fixture()) as Map<String, dynamic>;

List<Map<String, dynamic>> _ayat(Map<String, dynamic> j) =>
    ((j['data'] as Map)['ayat'] as List).cast<Map<String, dynamic>>();

class _Fake {
  _Fake(this.respond);
  final Future<({int status, String body})> Function() respond;
  final calls = <Uri>[];
  Future<({int status, String body})> call(Uri url, {String? jsonBody}) {
    calls.add(url);
    return respond();
  }
}

_Fake _ok(String body, [int status = 200]) =>
    _Fake(() async => (status: status, body: body));

_Fake _throwing(Object e) => _Fake(() async => throw e);

Future<Object?> _err(_Fake f, {int surah = 94, int count = 8}) async {
  try {
    await AudioApiClient(f.call).fetchSurah(surah, expectedAyahCount: count);
  } catch (e) {
    return e;
  }
  return null;
}

void main() {
  test('fixture yields 8 urls for each of 6 qaris', () async {
    final f = _ok(_fixture());
    final a = await AudioApiClient(f.call).fetchSurah(94, expectedAyahCount: 8);
    expect(f.calls.single.toString(), 'https://equran.id/api/v2/surat/94');
    expect(a.surah, 94);
    expect(a.ayahUrlsByQari.keys.toSet(), {'01', '02', '03', '04', '05', '06'});
    for (final u in a.ayahUrlsByQari.values) {
      expect(u, hasLength(8));
    }
    expect(
      a.urlsFor('01')?.first.toString(),
      'https://cdn.equran.id/audio-partial/Abdullah-Al-Juhany/094001.mp3',
    );
    expect(
      a.urlsFor('05')?.last.toString(),
      'https://cdn.equran.id/audio-partial/Misyari-Rasyid-Al-Afasi/094008.mp3',
    );
    expect(a.urlsFor('99'), isNull);
  });

  for (final c in [(0, 8), (115, 8), (-1, 8), (94, 0)]) {
    test('rejects surah ${c.$1} count ${c.$2} without a request', () async {
      final f = _ok(_fixture());
      expect(await _err(f, surah: c.$1, count: c.$2), isA<AudioBadResponse>());
      expect(f.calls, isEmpty);
    });
  }

  test('404 is AudioNotFound', () async {
    expect(await _err(_ok('{}', 404)), isA<AudioNotFound>());
  });

  for (final s in [500, 503]) {
    test('HTTP $s is AudioNetwork', () async {
      expect(await _err(_ok('x', s)), isA<AudioNetwork>());
    });
  }

  for (final e in [
    const SocketException('x'),
    const HandshakeException('x'),
    TimeoutException('x'),
  ]) {
    test('${e.runtimeType} is AudioNetwork', () async {
      expect(await _err(_throwing(e)), isA<AudioNetwork>());
    });
  }

  test('undecodable body is AudioBadResponse', () async {
    final e = await _err(_throwing(const FormatException('bad')));
    expect(e, isA<AudioBadResponse>());
    expect((e as AudioBadResponse).reason, 'undecodable body');
  });

  test('other status is AudioBadResponse', () async {
    expect(await _err(_ok('x', 302)), isA<AudioBadResponse>());
  });

  for (final b in [
    '<html></html>',
    '',
    '{bad',
    '{"code":200,"data":null}',
    '[]',
    '{"code":200}',
  ]) {
    test('200 with body "$b" is AudioBadResponse', () async {
      expect(await _err(_ok(b)), isA<AudioBadResponse>());
    });
  }

  test('nomor mismatch rejected', () async {
    final j = _json();
    (j['data'] as Map)['nomor'] = 93;
    expect(await _err(_ok(jsonEncode(j))), isA<AudioBadResponse>());
  });

  for (final n in [7, 9]) {
    test('ayat count $n != 8 rejected', () async {
      final j = _json();
      final l = (j['data'] as Map)['ayat'] as List;
      if (n == 7) {
        l.removeLast();
      } else {
        l.add(Map<String, dynamic>.from(l.last as Map)..['nomorAyat'] = 9);
      }
      expect(await _err(_ok(jsonEncode(j))), isA<AudioBadResponse>());
    });
  }

  test('out of order nomorAyat rejected', () async {
    final j = _json();
    final a = _ayat(j);
    final t = a[0]['nomorAyat'];
    a[0]['nomorAyat'] = a[1]['nomorAyat'];
    a[1]['nomorAyat'] = t;
    expect(await _err(_ok(jsonEncode(j))), isA<AudioBadResponse>());
  });

  test('duplicated nomorAyat rejected', () async {
    final j = _json();
    _ayat(j)[1]['nomorAyat'] = 1;
    expect(await _err(_ok(jsonEncode(j))), isA<AudioBadResponse>());
  });

  const bad = <String, Object?>{
    'http scheme': 'http://cdn.equran.id/a.mp3',
    'evil host': 'https://evil.example/a.mp3',
    'suffix host': 'https://cdn.equran.id.evil.example/a.mp3',
    'userinfo': 'https://cdn.equran.id@evil.example/x.mp3',
    'userinfo same host': 'https://u:p@cdn.equran.id/a.mp3',
    'port': 'https://cdn.equran.id:8443/a.mp3',
    'query': 'https://cdn.equran.id/a.mp3?x=1',
    'fragment': 'https://cdn.equran.id/a.mp3#x',
    'wrong extension': 'https://cdn.equran.id/a.mp4',
    'relative': '/audio/a.mp3',
    'non-string': 5,
    'null': null,
  };
  bad.forEach((name, value) {
    test('bad url ($name) rejects the whole surah', () async {
      final j = _json();
      ((_ayat(j)[3]['audio']) as Map)['02'] = value;
      expect(await _err(_ok(jsonEncode(j))), isA<AudioBadResponse>());
    });
  });

  test('bad url under an unknown qari still rejects', () async {
    final j = _json();
    ((_ayat(j)[0]['audio']) as Map)['99'] = 'http://evil.example/a.mp3';
    expect(await _err(_ok(jsonEncode(j))), isA<AudioBadResponse>());
  });

  test('qari missing one ayat is omitted, others stay', () async {
    final j = _json();
    ((_ayat(j)[2]['audio']) as Map).remove('03');
    final a = await AudioApiClient(
      _ok(jsonEncode(j)).call,
    ).fetchSurah(94, expectedAyahCount: 8);
    expect(a.urlsFor('03'), isNull);
    expect(a.ayahUrlsByQari.keys.toSet(), {'01', '02', '04', '05', '06'});
  });

  test('unknown qari id 99 is ignored', () async {
    final j = _json();
    for (final a in _ayat(j)) {
      (a['audio'] as Map)['99'] = 'https://cdn.equran.id/x/094001.mp3';
    }
    final a = await AudioApiClient(
      _ok(jsonEncode(j)).call,
    ).fetchSurah(94, expectedAyahCount: 8);
    expect(a.urlsFor('99'), isNull);
    expect(a.ayahUrlsByQari, hasLength(6));
  });
}
