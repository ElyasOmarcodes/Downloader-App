import 'package:flutter/material.dart';

/// App information and guidance. Kept intentionally light for the MVP.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('MediaGrab'),
            subtitle: Text('Version 1.0.0 • Flutter cross-platform'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.folder_outlined),
            title: Text('Storage location'),
            subtitle: Text('App documents / Downloads › MediaGrab'),
          ),
          const ListTile(
            leading: Icon(Icons.videocam_outlined),
            title: Text('Video quality'),
            subtitle: Text('144p up to 4K, selectable per download'),
          ),
          const ListTile(
            leading: Icon(Icons.music_note_outlined),
            title: Text('Audio extraction'),
            subtitle: Text('Save the audio track (MP3 conversion needs ffmpeg)'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Only download content you have the right to save. '
              'Respect each platform\'s Terms of Service and applicable '
              'copyright law.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
