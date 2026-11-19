import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../hadith_books/bindings/hadith_books_binding.dart';
import '../../hadith_books/views/hadith_books_view.dart';
import '../../home/bindings/home_binding.dart';
import '../../home/home_view.dart';
import '../../prayer/bindings/prayer_binding.dart';
import '../../prayer/views/prayer_view.dart';
import '../../quran_list/bindings/quran_list_binding.dart';
import '../../quran_list/views/quran_list_view.dart';
import '../controllers/shell_controller.dart';

class ShellView extends StatelessWidget {
  const ShellView({required this.dataVersion, super.key});

  final String dataVersion;

  @override
  Widget build(BuildContext context) => GetBuilder<ShellController>(
    init: ShellController(),
    initState: (_) {
      QuranListBinding().dependencies();
      HadithBooksBinding().dependencies();
      PrayerBinding().dependencies();
      HomeBinding().dependencies();
    },
    builder: (c) => Scaffold(
      // Tabs have no AppBar, so keep their top row out of the status bar.
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: c.index,
          children: [
            HomeView(dataVersion: dataVersion),
            const QuranListView(),
            const HadithBooksView(),
            const PrayerView(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: c.index,
        onDestinationSelected: c.select,
        destinations: const [
          NavigationDestination(
            icon: NuraIcon(NuraIcons.home),
            selectedIcon: NuraIcon(NuraIcons.home, filled: true),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: NuraIcon(NuraIcons.menuBook),
            selectedIcon: NuraIcon(NuraIcons.menuBook, filled: true),
            label: "Al-Qur'an",
          ),
          NavigationDestination(
            icon: NuraIcon(NuraIcons.autoStories),
            selectedIcon: NuraIcon(NuraIcons.autoStories, filled: true),
            label: 'Hadis',
          ),
          NavigationDestination(
            icon: NuraIcon(NuraIcons.schedule),
            selectedIcon: NuraIcon(NuraIcons.schedule, filled: true),
            label: 'Sholat',
          ),
        ],
      ),
    ),
  );
}
