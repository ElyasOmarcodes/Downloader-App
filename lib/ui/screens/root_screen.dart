import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/media_info.dart';
import '../../models/media_source.dart';
import '../../providers/download_provider.dart';
import '../../services/platform_detector.dart';
import '../../services/share_service.dart';
import '../widgets/format_selection_sheet.dart';
import 'downloads_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Hosts bottom navigation and wires app-wide behaviors: presenting the
/// download sheet for shared / clipboard links from any tab.
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  int _index = 0;
  StreamSubscription<MediaInfo>? _sheetSub;
  StreamSubscription<String>? _shareSub;
  String? _lastHandledClipboard;
  bool _sheetOpen = false;

  static const _pages = [
    HomeScreen(),
    DownloadsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final provider = context.read<DownloadProvider>();

    // Present the sheet whenever a share/clipboard link resolves.
    _sheetSub = provider.autoSheetStream.listen(_presentSheet);

    // Links shared into the app from other apps.
    _shareSub = ShareService.instance.sharedUrls.listen((url) {
      provider.autoResolve(url);
    });

    // Also check the clipboard on first launch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sheetSub?.cancel();
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // #6: when the app returns to the foreground, auto-process a freshly
    // copied link — exactly like Snaptube.
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      final url = PlatformDetector.extractUrl(text);
      if (url == null) return;
      if (url == _lastHandledClipboard) return;
      if (PlatformDetector.detect(url) == MediaSource.unknown) return;
      _lastHandledClipboard = url;
      if (!mounted) return;
      context.read<DownloadProvider>().autoResolve(url);
    } catch (_) {}
  }

  Future<void> _presentSheet(MediaInfo info) async {
    if (_sheetOpen || !mounted) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FormatSelectionSheet(info: info),
    );
    _sheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final activeCount = context.select<DownloadProvider, int>(
      (p) => p.activeTasks.length,
    );

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.t('home'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.download_outlined),
            ),
            selectedIcon: const Icon(Icons.download),
            label: l.t('downloads'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l.t('settings'),
          ),
        ],
      ),
    );
  }
}
