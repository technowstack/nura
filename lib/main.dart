import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app_bootstrap.dart';
import 'app/data/sources/content_db_installer.dart';
import 'app/nura_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

Future<void> _start() async {
  final Directory dir = await getApplicationSupportDirectory();
  final result = await bootstrap(
    installer: ContentDbInstaller(
      loadAsset: (key) async =>
          (await rootBundle.load(key)).buffer.asUint8List(),
      targetDir: dir,
    ),
    dataDir: dir,
  );
  runApp(NuraApp(result: result, onRetry: _start));
}
