import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../data/models/daily_content.dart';
import '../data/repositories/daily_content_repository.dart';
import '../data/repositories/daily_settings_store.dart';
import '../data/sources/widget_storage.dart';

typedef DailyImageRenderer =
    Future<Uint8List> Function(
      DailyContent c, {
      required Size dp,
      required double pixelRatio,
      required Brightness brightness,
    });

const _days = 7;
const _updatedKey = 'daily_widget_updated';
const _indexKey = 'daily_widget_index';
const _sizes = {'4x2': Size(320, 152), '4x3': Size(320, 240)};

/// Renders the home screen widget images for today..today+6 and stores them
/// for the native providers.
///
/// Storage contract (read by the Android providers):
///
/// - For each kind (`ayah` | `hadith`), local date (`yyyy-MM-dd`), theme
///   (`light` | `dark`) and size tag (`4x2` | `4x3`) the home_widget key
///   `daily_<kind>_<yyyy-MM-dd>_<light|dark>_<4x2|4x3>` holds a JSON string
///   `{"image": "<absolute path of the png>", "link": "nura://..."}`.
/// - PNGs live in the app support directory under `widget/`, named like the
///   key plus `.png`; they are written to a temp file and renamed.
/// - `daily_widget_updated` = ISO-8601 timestamp of the last refresh in which
///   every entry succeeded.
/// - `daily_widget_index` = JSON list of the keys written (cleanup only; the
///   native side ignores it).
/// - The ayah kind is not written at all while the repository has no ayah;
///   a missing entry for today is handled natively with a fallback text.
/// - Entries older than today are deleted; a failed entry keeps its old value.
class HomeWidgetService {
  HomeWidgetService({
    required DailyContentRepository repository,
    required DailySettingsStore settings,
    required WidgetStorage storage,
    required Directory directory,
    required DailyImageRenderer render,
    required DateTime Function() now,
    required double Function() pixelRatio,
  }) : _repository = repository,
       _settings = settings,
       _storage = storage,
       _dir = directory,
       _render = render,
       _now = now,
       _pixelRatio = pixelRatio;

  final DailyContentRepository _repository;
  final DailySettingsStore _settings;
  final WidgetStorage _storage;
  final Directory _dir;
  final DailyImageRenderer _render;
  final DateTime Function() _now;
  final double Function() _pixelRatio;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Never throws; failures are logged and the remaining entries continue.
  Future<void> refresh() async {
    try {
      await _refresh();
    } catch (e) {
      debugPrint('HomeWidgetService.refresh failed: $e');
    }
  }

  Future<void> _refresh() async {
    final n = _now();
    final today = DateTime(n.year, n.month, n.day);
    final wanted = <String>{};
    final present = <String>{};
    var failed = false;
    await _dir.create(recursive: true);
    final ratio = _pixelRatio();
    final source = _settings.hadithSource;

    for (var i = 0; i < _days; i++) {
      // Calendar arithmetic, so DST shifts cannot skip or repeat a date.
      final date = DateTime(today.year, today.month, today.day + i);
      final d = _date(date);
      for (final kind in DailyKind.values) {
        DailyContent? content;
        try {
          if (kind == DailyKind.ayah) {
            content = _repository.hasAyah ? _repository.ayahFor(date) : null;
          } else {
            content = _repository.hadithFor(date, source);
          }
        } catch (e) {
          debugPrint('daily content $kind $d failed: $e');
          failed = true;
          continue;
        }
        if (content == null) continue;
        for (final brightness in Brightness.values) {
          for (final tag in _sizes.entries) {
            final key = 'daily_${kind.name}_${d}_${brightness.name}_${tag.key}';
            wanted.add(key);
            if (await _write(key, content, tag.value, ratio, brightness)) {
              present.add(key);
            } else {
              failed = true;
            }
          }
        }
      }
    }

    final old = await _readIndex();
    for (final key in old.difference(wanted)) {
      await _guard(() => _storage.save(key, null));
    }
    for (final f in _dir.listSync()) {
      final name = f.uri.pathSegments.last;
      if (f is File &&
          !wanted.contains(name.replaceAll(RegExp(r'\.png$'), ''))) {
        await _guard(f.delete);
      }
    }
    // A failed entry keeps its old value, so it stays in the index.
    final index = {...present, ...old.intersection(wanted)};
    await _guard(() => _storage.save(_indexKey, jsonEncode(index.toList())));
    if (!failed) {
      await _guard(() => _storage.save(_updatedKey, _now().toIso8601String()));
    }
  }

  Future<bool> _write(
    String key,
    DailyContent c,
    Size dp,
    double ratio,
    Brightness brightness,
  ) async {
    try {
      final bytes = await _render(
        c,
        dp: dp,
        pixelRatio: ratio,
        brightness: brightness,
      );
      final path = '${_dir.path}/$key.png';
      final tmp = File('$path.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(path);
      await _storage.save(key, jsonEncode({'image': path, 'link': c.deepLink}));
      return true;
    } catch (e) {
      debugPrint('widget entry $key failed: $e');
      return false;
    }
  }

  Future<Set<String>> _readIndex() async {
    try {
      final raw = await _storage.read(_indexKey);
      if (raw == null) return {};
      return (jsonDecode(raw) as List<dynamic>).whereType<String>().toSet();
    } catch (e) {
      debugPrint('widget index unreadable: $e');
      return {};
    }
  }

  Future<void> _guard(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('widget cleanup/store failed: $e');
    }
  }
}
