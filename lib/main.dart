import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'providers/download_provider.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'ui/screens/root_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  await NotificationService.instance.init();

  final provider = DownloadProvider();
  await provider.loadPersisted();

  runApp(MediaGrabApp(provider: provider));
}

class MediaGrabApp extends StatelessWidget {
  const MediaGrabApp({super.key, required this.provider});

  final DownloadProvider provider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        title: 'MediaGrab',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const RootScreen(),
      ),
    );
  }
}
