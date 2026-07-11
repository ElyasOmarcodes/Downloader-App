import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';

/// App settings: per-network download concurrency and app language.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(title: Text(l.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.t('appName')),
            subtitle: const Text('Version 1.1.0 • Flutter cross-platform'),
          ),
          const Divider(),

          // Language
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.t('language')),
            trailing: DropdownButton<String>(
              value: settings.languageCode,
              onChanged: (code) {
                if (code != null) settings.setLanguage(code);
              },
              items: const [
                DropdownMenuItem(value: 'ps', child: Text('پښتو')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
            ),
          ),
          const Divider(),

          // Concurrency — WiFi
          _ConcurrencyTile(
            icon: Icons.wifi,
            label: l.t('concurrentWifi'),
            value: settings.wifiConcurrency,
            onChanged: settings.setWifiConcurrency,
          ),
          // Concurrency — Mobile data
          _ConcurrencyTile(
            icon: Icons.signal_cellular_alt,
            label: l.t('concurrentMobile'),
            value: settings.mobileConcurrency,
            onChanged: settings.setMobileConcurrency,
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(l.t('storageLocation')),
            subtitle: const Text('/MediaGrab/Video  •  /MediaGrab/Audio'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.t('legalNote'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcurrencyTile extends StatelessWidget {
  const _ConcurrencyTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Slider(
        value: value.toDouble(),
        min: 1,
        max: 6,
        divisions: 5,
        label: '$value',
        onChanged: (v) => onChanged(v.round()),
      ),
      trailing: Text('$value',
          style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
