import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import 'settings_view.dart';

/// `/settings` opened from a reader. The controller is shared with the
/// Pengaturan tab, so a visit re-reads the stores and leaving refreshes
/// Beranda (the controller's onClose no longer runs on every pop).
class SettingsRoutePage extends StatefulWidget {
  const SettingsRoutePage({super.key});

  @override
  State<SettingsRoutePage> createState() => _SettingsRoutePageState();
}

class _SettingsRoutePageState extends State<SettingsRoutePage> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<SettingsController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.onVisit());
  }

  @override
  void dispose() {
    if (Get.isRegistered<SettingsController>() &&
        !Get.isPrepared<SettingsController>()) {
      // Deferred: Beranda's Obx cannot rebuild while the tree is unmounting.
      Future.microtask(Get.find<SettingsController>().refreshHome);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SettingsView();
}
