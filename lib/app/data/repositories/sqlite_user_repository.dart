import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/errors.dart';
import '../../core/theme/theme_mode_setting.dart';
import '../models/ayah.dart';
import '../models/bookmark.dart';
import '../models/hadith.dart';
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

  /// Maps database failures to [UserDataUnavailable]; other errors pass through.
  T _guard<T>(T Function() body) {
    try {
      return body();
    } on SqliteException catch (e) {
      throw UserDataUnavailable(
        'Data pengguna tidak dapat diakses: ${e.message}',
      );
    } on StateError {
      // sqlite3 throws StateError (not SqliteException) on a closed database.
      throw const UserDataUnavailable('Data pengguna tidak dapat diakses');
    }
  }

  int _stamp() => _now().toUtc().millisecondsSinceEpoch;

  DateTime _time(Object? ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms as int, isUtc: true);

  @override
  bool toggleBookmark(AyahRef ref) => _guard(() => _toggle(ref));

  bool _toggle(AyahRef ref) =>
      _toggleRow('ayah', ref.surah.toString(), ref.ayah);

  /// Delete-or-insert in one transaction, unique per (kind, ref_a, ref_b).
  bool _toggleRow(String kind, String refA, int refB) {
    final raw = _db.raw;
    raw.execute('BEGIN IMMEDIATE');
    try {
      raw.execute(
        'DELETE FROM bookmark WHERE kind = ? AND ref_a = ? AND ref_b = ?',
        [kind, refA, refB],
      );
      final removed = raw.updatedRows > 0;
      if (!removed) {
        raw.execute(
          'INSERT INTO bookmark (kind, ref_a, ref_b, created_at) '
          'VALUES (?, ?, ?, ?)',
          [kind, refA, refB, _stamp()],
        );
      }
      raw.execute('COMMIT');
      return !removed;
    } catch (_) {
      try {
        raw.execute('ROLLBACK');
      } catch (_) {
        // Keep the original error; a failed rollback must not mask it.
      }
      rethrow;
    }
  }

  @override
  bool toggleHadithBookmark(HadithRef ref) =>
      _guard(() => _toggleRow('hadith', ref.slug, ref.number));

  @override
  List<HadithBookmark> listHadithBookmarks() => _guard(
    () => _db.raw
        .select(
          "SELECT ref_a, ref_b, created_at FROM bookmark WHERE kind = 'hadith' "
          'ORDER BY created_at DESC, id DESC',
        )
        .map(
          (r) => HadithBookmark(
            ref: HadithRef(r['ref_a'] as String, r['ref_b'] as int),
            createdAt: _time(r['created_at']),
          ),
        )
        .toList(),
  );

  @override
  Set<int> bookmarkedHadithNumbers(String slug) => _guard(
    () => _db.raw
        .select(
          "SELECT ref_b FROM bookmark WHERE kind = 'hadith' AND ref_a = ?",
          [slug],
        )
        .map((r) => r['ref_b'] as int)
        .toSet(),
  );

  @override
  List<Bookmark> listBookmarks() => _guard(
    () => _db.raw
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
        .toList(),
  );

  @override
  Set<int> bookmarkedAyahNumbers(int surahNumber) => _guard(
    () => _db.raw
        .select(
          "SELECT ref_b FROM bookmark WHERE kind = 'ayah' AND ref_a = ?",
          [surahNumber.toString()],
        )
        .map((r) => r['ref_b'] as int)
        .toSet(),
  );

  @override
  Set<int> bookmarkedSurahNumbers() => _guard(
    () => _db.raw
        .select("SELECT DISTINCT ref_a FROM bookmark WHERE kind = 'ayah'")
        .map((r) => int.parse(r['ref_a'] as String))
        .toSet(),
  );

  @override
  LastRead? getLastRead() => _guard(() {
    final rows = _db.raw.select(
      "SELECT ref_a, ref_b, updated_at FROM last_read WHERE kind = 'ayah'",
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    return LastRead(
      ref: AyahRef(int.parse(r['ref_a'] as String), r['ref_b'] as int),
      updatedAt: _time(r['updated_at']),
    );
  });

  @override
  void setLastRead(AyahRef ref) => _guard(
    () => _db.raw.execute(
      "INSERT INTO last_read (kind, ref_a, ref_b, updated_at) "
      "VALUES ('ayah', ?, ?, ?) ON CONFLICT(kind) DO UPDATE SET "
      'ref_a = excluded.ref_a, ref_b = excluded.ref_b, '
      'updated_at = excluded.updated_at',
      [ref.surah.toString(), ref.ayah, _stamp()],
    ),
  );

  @override
  ReadingPrefs getReadingPrefs() => _guard(
    () => ReadingPrefs(
      arabicFontSize:
          (double.tryParse(_db.getSetting(SettingKeys.arabicFontSize) ?? '') ??
                  _defaultFontSize)
              .clamp(_minFontSize, _maxFontSize),
      showTranslation: _db.getSetting(SettingKeys.showTranslation) != 'false',
      translationFontSize:
          (double.tryParse(
                    _db.getSetting(SettingKeys.translationFontSize) ?? '',
                  ) ??
                  kTranslationFontDefault)
              .clamp(kTranslationFontMin, kTranslationFontMax),
    ),
  );

  @override
  void setArabicFontSize(double size) {
    // NaN.clamp stays NaN and would be stored.
    if (!size.isFinite) return;
    _guard(
      () => _db.setSetting(
        SettingKeys.arabicFontSize,
        size.clamp(_minFontSize, _maxFontSize).toString(),
      ),
    );
  }

  @override
  void setTranslationFontSize(double size) {
    if (!size.isFinite) return;
    _guard(
      () => _db.setSetting(
        SettingKeys.translationFontSize,
        size.clamp(kTranslationFontMin, kTranslationFontMax).toString(),
      ),
    );
  }

  @override
  void setShowTranslation(bool value) => _guard(
    () => _db.setSetting(SettingKeys.showTranslation, value.toString()),
  );

  @override
  ThemeMode getThemeMode() =>
      _guard(() => themeModeFromSetting(_db.getSetting(SettingKeys.themeMode)));

  @override
  void setThemeMode(ThemeMode mode) => _guard(
    () => _db.setSetting(SettingKeys.themeMode, themeModeToSetting(mode)),
  );
}
