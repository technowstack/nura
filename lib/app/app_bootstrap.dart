import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'core/theme/theme_controller.dart';
import 'data/repositories/hadith_repository.dart';
import 'data/repositories/isolate_hadith_repository.dart';
import 'data/repositories/quran_repository.dart';
import 'data/repositories/sqlite_quran_repository.dart';
import 'data/repositories/sqlite_user_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/sources/content_database.dart';
import 'data/sources/content_db_installer.dart';
import 'data/sources/user_database.dart';

sealed class BootstrapResult {
  const BootstrapResult();
}

class BootstrapSuccess extends BootstrapResult {
  const BootstrapSuccess(this.content, this.user);

  final ContentDatabase content;
  final UserDatabase user;
}

class BootstrapFailure extends BootstrapResult {
  const BootstrapFailure(this.error);

  final Object error;
}

/// Installs and opens both databases and the hadith worker; registers
/// everything in GetX only after all of them are up, so a failure at any step
/// closes what was opened (including the worker) and registers nothing.
/// Order: content db, worker, user db, then registration.
Future<BootstrapResult> bootstrap({
  required ContentDbInstaller installer,
  required Directory dataDir,
  @visibleForTesting
  Future<IsolateHadithRepository> Function(File) startHadith =
      IsolateHadithRepository.start,
}) async {
  ContentDatabase? content;
  UserDatabase? user;
  IsolateHadithRepository? hadith;
  try {
    final file = await installer.ensureInstalled();
    content = ContentDatabase.open(file);
    hadith = await startHadith(content.file);
    user = UserDatabase.open(File('${dataDir.path}/user.db'));
    Get.put<ContentDatabase>(content, permanent: true);
    Get.put<UserDatabase>(user, permanent: true);
    Get.put<QuranRepository>(SqliteQuranRepository(content), permanent: true);
    Get.put<UserRepository>(SqliteUserRepository(user), permanent: true);
    Get.put<HadithRepository>(hadith, permanent: true);
    // Lazy so the stored mode is read when the app first builds.
    Get.lazyPut<ThemeController>(ThemeController.new, fenix: true);
    return BootstrapSuccess(content, user);
  } catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: 'nura bootstrap'),
    );
    await hadith?.close();
    content?.close();
    user?.close();
    return BootstrapFailure(e);
  }
}
