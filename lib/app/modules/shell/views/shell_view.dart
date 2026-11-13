import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../home/home_view.dart';
import '../../quran_list/bindings/quran_list_binding.dart';
import '../../quran_list/views/quran_list_view.dart';
import '../controllers/shell_controller.dart';
import '../widgets/coming_soon_tab.dart';

class ShellView extends StatelessWidget {
  const ShellView({required this.dataVersion, super.key});

  final String dataVersion;

  @override
  Widget build(BuildContext context) => GetBuilder<ShellController>(
    init: ShellController(),
    initState: (_) => QuranListBinding().dependencies(),
    builder: (c) => Scaffold(
      body: IndexedStack(
        index: c.index,
        children: [
          HomeView(dataVersion: dataVersion),
          const QuranListView(),
          const ComingSoonTab(),
          const ComingSoonTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: c.index,
        onDestinationSelected: c.select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: "Al-Qur'an",
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Hadis',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time),
            selectedIcon: Icon(Icons.access_time_filled),
            label: 'Sholat',
          ),
        ],
      ),
    ),
  );
}
