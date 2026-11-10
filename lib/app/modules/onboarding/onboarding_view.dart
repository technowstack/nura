import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/sources/setting_keys.dart';
import '../../data/sources/user_database.dart';
import '../../routes/app_routes.dart';

/// Placeholder; real onboarding comes in a later phase.
class OnboardingView extends StatelessWidget {
  const OnboardingView({required this.user, super.key});

  final UserDatabase user;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Selamat datang di Nura'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              user.setSetting(SettingKeys.onboardingDone, 'true');
              Get.offAllNamed<void>(Routes.home);
            },
            child: const Text('Mulai'),
          ),
        ],
      ),
    ),
  );
}
