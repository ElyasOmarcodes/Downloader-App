import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import 'downloads_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Hosts the bottom navigation between Home, Downloads and Settings.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    DownloadsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeCount = context.select<DownloadProvider, int>(
      (p) => p.tasks.where((t) => t.status.isActive).length,
    );

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.download_outlined),
            ),
            selectedIcon: const Icon(Icons.download),
            label: 'Downloads',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
