import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app_bootstrap.dart';
import 'app/data/sources/bundle_asset_copier.dart';
import 'app/data/sources/content_db_installer.dart';
import 'app/data/sources/native_asset_copier.dart';
import 'app/nura_app.dart';
import 'app/services/daily_link_router.dart';
import 'app/services/daily_refresher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

bool _starting = false;

Future<void> _start() async {
  if (_starting) return;
  _starting = true;
  try {
    final Directory dir = await getApplicationSupportDirectory();
    final result = await bootstrap(
      installer: ContentDbInstaller(
        copyAsset: Platform.isAndroid ? copyAssetNatively : copyAssetFromBundle,
        loadVersion: rootBundle.loadString,
        targetDir: dir,
      ),
      dataDir: dir,
    );
    runApp(NuraApp(result: result, onRetry: _start));
    if (result is BootstrapSuccess) {
      // Both wait for the first frame, so startup is never delayed.
      Get.find<DailyRefresher>().start();
      Get.find<DailyLinkRouter>().start();
    }
  } catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: 'nura startup'),
    );
    runApp(NuraApp(result: BootstrapFailure(e), onRetry: _start));
  } finally {
    _starting = false;
  }
}
