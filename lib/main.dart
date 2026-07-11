import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/download_provider.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/share_service.dart';
import 'services/storage_service.dart';
import 'ui/screens/root_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  await SettingsService.instance.init();
  await NotificationService.instance.init();

  final provider = DownloadProvider();
  await provider.loadPersisted();
  await ShareService.instance.init();

  runApp(MediaGrabApp(provider: provider));
}

class MediaGrabApp extends StatelessWidget {
  const MediaGrabApp({super.key, required this.provider});

  final DownloadProvider provider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider.value(value: SettingsService.instance),
      ],
      // Rebuild when the language changes.
      child: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'MediaGrab',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            locale: Locale(settings.languageCode),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const RootScreen(),
          );
        },
      ),
    );
  }
}
