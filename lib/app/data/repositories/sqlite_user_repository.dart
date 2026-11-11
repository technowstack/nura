import 'package:flutter/material.dart';

import '../../core/theme/theme_mode_setting.dart';
import '../models/ayah.dart';
import '../models/bookmark.dart';
import '../models/last_read.dart';
import '../models/reading_prefs.dart';
import '../sources/setting_keys.dart';
import '../sources/user_database.dart';
import 'user_repository.dart';

class SqliteUserRepository implements UserRepository {
  SqliteUserRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const double _defaultFontSize = 28;
  static const double _minFontSize = 20;
  static const double _maxFontSize = 40;

  final UserDatabase _db;
  final DateTime Function() _now;

  int _stamp() => _now().toUtc().millisecondsSinceEpoch;

  DateTime _time(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);

  @override
  bool toggleBookmark(AyahRef ref) {
    final raw = _db.raw;
    // One transaction: delete-or-insert is atomic and unique per ayah.
    raw.execute('BEGIN IMMEDIATE');
    try {
      final key = [ref.surah.toString(), ref.ayah];
      raw.execute(
        "DELETE FROM bookmark WHERE kind = 'ayah' AND ref_a = ? AND ref_b = ?",
        key,
      );
      final removed = raw.updatedRows > 0;
      if (!removed) {
        raw.execute(
          "INSERT INTO bookmark (kind, ref_a, ref_b, created_at) "
          "VALUES ('ayah', ?, ?, ?)",
          [...key, _stamp()],
        );
      }
      raw.execute('COMMIT');
      return !removed;
    } catch (_) {
      raw.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  List<Bookmark> listBookmarks() => _db.raw
      .select(
        "SELECT ref_a, ref_b, created_at FROM bookmark WHERE kind = 'ayah' "
        'ORDER BY created_at DESC, id DESC',
      )
      .map(
        (r) => Bookmark(
          ref: AyahRef(int.parse(r['ref_a'] as String), r['ref_b'] as int),
          createdAt: _time(r['created_at']),
        ),
      )
      .toList();

  @override
  Set<int> bookmarkedAyahNumbers(int surahNumber) => _db.raw
      .select("SELECT ref_b FROM bookmark WHERE kind = 'ayah' AND ref_a = ?", [
        surahNumber.toString(),
      ])
      .map((r) => r['ref_b'] as int)
      .toSet();

  @override
  Set<int> bookmarkedSurahNumbers() => _db.raw
      .select("SELECT DISTINCT ref_a FROM bookmark WHERE kind = 'ayah'")
      .map((r) => int.parse(r['ref_a'] as String))
      .toSet();

  @override
  LastRead? getLastRead() {
    final rows = _db.raw.select(
      "SELECT ref_a, ref_b, updated_at FROM last_read WHERE kind = 'ayah'",
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    return LastRead(
      ref: AyahRef(int.parse(r['ref_a'] as String), r['ref_b'] as int),
      updatedAt: _time(r['updated_at']),
    );
  }

  @override
  void setLastRead(AyahRef ref) => _db.raw.execute(
    "INSERT INTO last_read (kind, ref_a, ref_b, updated_at) "
    "VALUES ('ayah', ?, ?, ?) ON CONFLICT(kind) DO UPDATE SET "
    'ref_a = excluded.ref_a, ref_b = excluded.ref_b, '
    'updated_at = excluded.updated_at',
    [ref.surah.toString(), ref.ayah, _stamp()],
  );

  @override
  ReadingPrefs getReadingPrefs() => ReadingPrefs(
    arabicFontSize:
        (double.tryParse(_db.getSetting(SettingKeys.arabicFontSize) ?? '') ??
                _defaultFontSize)
            .clamp(_minFontSize, _maxFontSize),
    showTranslation: _db.getSetting(SettingKeys.showTranslation) != 'false',
  );

  @override
  void setArabicFontSize(double size) => _db.setSetting(
    SettingKeys.arabicFontSize,
    size.clamp(_minFontSize, _maxFontSize).toString(),
  );

  @override
  void setShowTranslation(bool value) =>
      _db.setSetting(SettingKeys.showTranslation, value.toString());

  @override
  ThemeMode getThemeMode() =>
      themeModeFromSetting(_db.getSetting(SettingKeys.themeMode));

  @override
  void setThemeMode(ThemeMode mode) =>
      _db.setSetting(SettingKeys.themeMode, themeModeToSetting(mode));
}
