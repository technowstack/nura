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
// Design sizes, used until the launcher has reported a real one.
const _sizes = {'4x2': Size(320, 152), '4x3': Size(320, 240)};

/// Renders the home screen widget images for today..today+6 and stores them
/// for the native providers.
///
/// Storage contract (read by the Android providers):
///
/// - For each kind (`ayah` | `hadith`), local date (`yyyy-MM-dd`), theme
///   (`light` | `dark`) and size tag (`4x2` | `4x3`) the home_widget key
///   `daily_<kind>_<yyyy-MM-dd>_<light|dark>_<4x2|4x3>` holds a JSON string
///   `{"image": "<png path>", "link": "nura://...", "description": "<text>"}`
///   (`description` = TalkBack text, optional).
/// - PNGs live in the app support directory under `widget/`, named like the
///   key plus `.png`; they are written to a temp file and renamed.
/// - `daily_widget_updated` = ISO-8601 timestamp of the last refresh in which
///   every entry succeeded.
/// - `widget_size_<kind>_<4x2|4x3>` = `<width>x<height>` in dp, written by the
///   native providers; images are rendered at that size.
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

  Future<bool> _inFlight = Future<bool>.value(true);

  /// Never throws; failures are logged and the remaining entries continue.
  /// Runs are serialized so two runs never share the same temp file.
  /// Completes with true only when every entry was written or intentionally
  /// skipped.
  Future<bool> refresh() {
    final run = _inFlight.then((_) async {
      try {
        return await _refresh();
      } catch (e) {
        debugPrint('HomeWidgetService.refresh failed: $e');
        return false;
      }
    });
    _inFlight = run;
    return run;
  }

  /// Changes when a widget is placed or resized, so the images get redrawn.
  Future<String> sizeSignature() async {
    final parts = <String>[];
    for (final kind in DailyKind.values) {
      for (final tag in _sizes.keys) {
        parts.add(await _storage.read('widget_size_${kind.name}_$tag') ?? '');
      }
    }
    return parts.join(',');
  }

  /// The launcher's size per variant of [kind], clamped to sane bounds. A
  /// variant never reported keeps its design height and borrows the width.
  Future<Map<String, Size>> _sizesFor(DailyKind kind) async {
    final reported = <String, Size>{};
    for (final tag in _sizes.keys) {
      String? raw;
      try {
        raw = await _storage.read('widget_size_${kind.name}_$tag');
      } catch (e) {
        debugPrint('widget size unreadable: $e');
      }
      final parts = raw?.split('x') ?? const <String>[];
      if (parts.length != 2) continue;
      final w = double.tryParse(parts[0]);
      final h = double.tryParse(parts[1]);
      if (w == null || h == null || !w.isFinite || !h.isFinite) continue;
      reported[tag] = Size(w.clamp(200.0, 600.0), h.clamp(100.0, 480.0));
    }
    return {
      for (final e in _sizes.entries)
        e.key:
            reported[e.key] ??
            Size(
              reported.values.firstOrNull?.width ?? e.value.width,
              e.value.height,
            ),
    };
  }

  static Iterable<String> _keys(String kind, String date) => [
    for (final b in Brightness.values)
      for (final t in _sizes.keys) 'daily_${kind}_${date}_${b.name}_$t',
  ];

  Future<bool> _refresh() async {
    final n = _now();
    final today = DateTime(n.year, n.month, n.day);
    final wanted = <String>{};
    final present = <String>{};
    var failed = false;
    await _dir.create(recursive: true);
    final ratio = _pixelRatio();
    final source = _settings.hadithSource;
    final sizes = {
      for (final kind in DailyKind.values) kind: await _sizesFor(kind),
    };

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
          // A failed lookup keeps the old entries (not "no content").
          wanted.addAll(_keys(kind.name, d));
          failed = true;
          continue;
        }
        if (content == null) continue;
        for (final brightness in Brightness.values) {
          for (final tag in (sizes[kind] ?? _sizes).entries) {
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
      if (f is! File) continue;
      final key = f.uri.pathSegments.last.replaceAll(
        RegExp(r'\.png(\.tmp)?$'),
        '',
      );
      if (!wanted.contains(key)) {
        // Directory sweep also covers keys lost with a failed index save.
        if (key.startsWith('daily_')) {
          await _guard(() => _storage.save(key, null));
        }
        await _guard(f.delete);
      }
    }
    // A failed entry keeps its old value, so it stays in the index.
    final index = {...present, ...old.intersection(wanted)};
    await _guard(() => _storage.save(_indexKey, jsonEncode(index.toList())));
    if (!failed) {
      await _guard(() => _storage.save(_updatedKey, _now().toIso8601String()));
    }
    // Providers only redraw on their own schedule unless told to.
    if (present.isNotEmpty) await _guard(_storage.notifyWidgets);

    return !failed;
  }

  Future<bool> _write(
    String key,
    DailyContent c,
    Size dp,
    double ratio,
    Brightness brightness,
  ) async {
    final path = '${_dir.path}/$key.png';
    final tmp = File('$path.tmp');
    try {
      final bytes = await _render(
        c,
        dp: dp,
        pixelRatio: ratio,
        brightness: brightness,
      );
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(path);
      await _storage.save(
        key,
        jsonEncode({
          'image': path,
          'link': c.deepLink,
          'description': _description(c),
        }),
      );
      return true;
    } catch (e) {
      debugPrint('widget entry $key failed: $e');
      if (tmp.existsSync()) await _guard(tmp.delete);
      return false;
    }
  }

  /// TalkBack text: label, reference and the translation cut to 160 chars.
  static String _description(DailyContent c) {
    final label = c.kind == DailyKind.ayah ? 'Ayat hari ini' : 'Hadis hari ini';
    final runes = c.translation.runes;
    final text = runes.length <= 160
        ? c.translation
        : '${String.fromCharCodes(runes.take(159))}\u2026';
    return '$label. ${c.reference}. $text';
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
