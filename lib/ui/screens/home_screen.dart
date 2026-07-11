import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/media_info.dart';
import '../../models/media_source.dart';
import '../../providers/download_provider.dart';
import '../../services/platform_detector.dart';
import '../widgets/format_selection_sheet.dart';

/// The landing screen: paste a link, resolve it, and preview the media.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  MediaSource _detected = MediaSource.unknown;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final s = PlatformDetector.detect(_controller.text);
      if (s != _detected) setState(() => _detected = s);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final url = PlatformDetector.extractUrl(text) ?? text;
    _controller.text = url;
  }

  Future<void> _resolve() async {
    FocusScope.of(context).unfocus();
    final provider = context.read<DownloadProvider>();
    final info = await provider.resolve(_controller.text.trim());
    if (!mounted) return;
    if (info != null) {
      _showFormats(info);
    } else if (provider.resolveError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.resolveError!)),
      );
    }
  }

  void _showFormats(MediaInfo info) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FormatSelectionSheet(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.download_for_offline, color: scheme.primary),
            const SizedBox(width: 8),
            const Text('MediaGrab'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a video link',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'https://…',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  tooltip: 'Paste',
                  icon: const Icon(Icons.content_paste),
                  onPressed: _paste,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_detected != MediaSource.unknown)
              _SourceChip(source: _detected),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: provider.isResolving ? null : _resolve,
              icon: provider.isResolving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(provider.isResolving ? 'Resolving…' : 'Fetch media'),
            ),
            const SizedBox(height: 28),
            _SupportedPlatforms(),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});
  final MediaSource source;

  @override
  Widget build(BuildContext context) {
    final supported = source.isSupported;
    return Chip(
      avatar: Icon(
        supported ? Icons.check_circle : Icons.info_outline,
        size: 18,
        color: supported ? Colors.green : Colors.orange,
      ),
      label: Text(
        supported
            ? '${source.label} • supported'
            : '${source.label} • needs resolver backend',
      ),
    );
  }
}

class _SupportedPlatforms extends StatelessWidget {
  static const _items = [
    ('YouTube', Icons.play_circle_fill, true),
    ('Facebook', Icons.facebook, false),
    ('Instagram', Icons.camera_alt, false),
    ('TikTok', Icons.music_note, false),
    ('Direct links', Icons.insert_link, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Platforms', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (name, icon, ok) in _items)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 6),
                    Text(name),
                    const SizedBox(width: 4),
                    Icon(
                      ok ? Icons.check_circle : Icons.hourglass_bottom,
                      size: 14,
                      color: ok ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
