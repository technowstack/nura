import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/qari.dart';
import '../models/surah_audio.dart';
import 'audio_api_exception.dart';
import 'prayer_api_client.dart';

/// Same transport contract as the prayer client (GET ignores `jsonBody`).
typedef AudioHttp = PrayerHttp;

const _host = 'cdn.equran.id';

/// Fetches per-ayah audio URLs. GET only, no cache, no disk writes; the
/// caller must check the online gate first.
class AudioApiClient {
  AudioApiClient(AudioHttp http) : _http = http;

  final AudioHttp _http;

  Future<SurahAudio> fetchSurah(
    int surah, {
    required int expectedAyahCount,
  }) async {
    if (surah < 1 || surah > 114 || expectedAyahCount < 1) {
      throw AudioBadResponse('invalid request: $surah/$expectedAyahCount');
    }
    final ({int status, String body}) res;
    try {
      res = await _http(
        Uri.parse('https://equran.id/api/v2/surat/$surah'),
      ).timeout(const Duration(seconds: 15));
    } on IOException {
      throw const AudioNetwork();
    } on TimeoutException {
      throw const AudioNetwork();
    } on FormatException {
      throw const AudioBadResponse('undecodable body');
    }
    if (res.status == 404) throw const AudioNotFound();
    if (res.status >= 500) throw const AudioNetwork();
    if (res.status != 200) throw AudioBadResponse('HTTP ${res.status}');
    final Object? json;
    try {
      json = jsonDecode(res.body);
    } on FormatException {
      throw const AudioBadResponse('unparseable JSON');
    }
    return _parse(json, surah, expectedAyahCount);
  }

  SurahAudio _parse(Object? json, int surah, int count) {
    final data = json is Map ? json['data'] : null;
    if (data is! Map) throw const AudioBadResponse('missing data');
    if (data['nomor'] != surah) throw const AudioBadResponse('surah mismatch');
    final ayat = data['ayat'];
    if (ayat is! List || ayat.length != count) {
      throw AudioBadResponse('expected $count ayat');
    }
    final known = {for (final q in kQaris) q.id};
    final urls = {for (final id in known) id: <Uri>[]};
    for (var i = 0; i < count; i++) {
      final e = ayat[i];
      if (e is! Map || e['nomorAyat'] != i + 1) {
        throw AudioBadResponse('bad or out-of-order ayah ${i + 1}');
      }
      final audio = e['audio'];
      if (audio is! Map) throw AudioBadResponse('missing audio on ${i + 1}');
      for (final entry in audio.entries) {
        // Validate every URL, even for unknown qaris: one bad URL rejects all.
        final uri = _validUri(entry.value);
        if (uri == null) throw AudioBadResponse('bad url on ayah ${i + 1}');
        urls[entry.key]?.add(uri);
      }
    }
    return SurahAudio(
      surah: surah,
      ayahUrlsByQari: {
        for (final e in urls.entries)
          if (e.value.length == count) e.key: List.unmodifiable(e.value),
      },
    );
  }

  Uri? _validUri(Object? v) {
    if (v is! String) return null;
    final u = Uri.tryParse(v);
    if (u == null ||
        u.scheme != 'https' ||
        u.host != _host ||
        u.userInfo.isNotEmpty ||
        u.hasPort ||
        u.hasQuery ||
        u.hasFragment ||
        !u.path.endsWith('.mp3')) {
      return null;
    }
    return u;
  }
}
