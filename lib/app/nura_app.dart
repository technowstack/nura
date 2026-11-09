import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_bootstrap.dart';
import 'core/init_failure_view.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_setting.dart';
import 'data/sources/setting_keys.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

class NuraApp extends StatelessWidget {
  const NuraApp({required this.result, required this.onRetry, super.key});

  final BootstrapResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final r = result;
    switch (r) {
      case BootstrapFailure():
        return MaterialApp(
          title: 'Nura',
          theme: AppTheme.light,
          home: InitFailureView(onRetry: onRetry),
        );
      case BootstrapSuccess():
        final done = r.user.getSetting(SettingKeys.onboardingDone) == 'true';
        return GetMaterialApp(
          title: 'Nura',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeModeFromSetting(
            r.user.getSetting(SettingKeys.themeMode),
          ),
          initialRoute: done ? Routes.home : Routes.onboarding,
          getPages: appPages(r),
        );
    }
  }
}
