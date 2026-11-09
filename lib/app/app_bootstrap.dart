import 'dart:io';

import 'package:get/get.dart';

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

/// Installs and opens both databases; registers them in GetX only on success.
Future<BootstrapResult> bootstrap({
  required ContentDbInstaller installer,
  required Directory dataDir,
}) async {
  ContentDatabase? content;
  UserDatabase? user;
  try {
    final file = await installer.ensureInstalled();
    content = ContentDatabase.open(file);
    user = UserDatabase.open(File('${dataDir.path}/user.db'));
    Get.put<ContentDatabase>(content, permanent: true);
    Get.put<UserDatabase>(user, permanent: true);
    return BootstrapSuccess(content, user);
  } catch (e) {
    content?.close();
    user?.close();
    return BootstrapFailure(e);
  }
}
