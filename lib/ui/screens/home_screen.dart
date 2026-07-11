import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
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
  ValueNotifier<String?>? _clipNotifier;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final s = PlatformDetector.detect(_controller.text);
      if (s != _detected) setState(() => _detected = s);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<DownloadProvider>().clipboardLink;
    if (!identical(notifier, _clipNotifier)) {
      _clipNotifier?.removeListener(_onClipboard);
      _clipNotifier = notifier..addListener(_onClipboard);
    }
  }

  void _onClipboard() {
    final link = _clipNotifier?.value;
    if (link != null && link.isNotEmpty && mounted) {
      _controller.text = link;
      _controller.selection = TextSelection.collapsed(offset: link.length);
    }
  }

  @override
  void dispose() {
    _clipNotifier?.removeListener(_onClipboard);
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
    final l = AppLocalizations.of(context);
    final provider = context.read<DownloadProvider>();
    final info = await provider.resolve(_controller.text.trim());
    if (!mounted) return;
    if (info != null) {
      _showFormats(info);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.resolveError ?? l.t('unrecognizedLink'))),
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
    final l = AppLocalizations.of(context);
    final provider = context.watch<DownloadProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.download_for_offline, color: scheme.primary),
            const SizedBox(width: 8),
            Text(l.t('appName')),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.t('pasteLink'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'https://…',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  tooltip: l.t('paste'),
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
              label: Text(provider.isResolving ? l.t('resolving') : l.t('fetch')),
            ),
            const SizedBox(height: 28),
            _SupportedPlatforms(label: l.t('platforms')),
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
    final firstClass = source.isFirstClass;
    return Chip(
      avatar: Icon(
        Icons.check_circle,
        size: 18,
        color: firstClass ? Colors.green : Colors.blue,
      ),
      label: Text(source.label),
    );
  }
}

class _SupportedPlatforms extends StatelessWidget {
  const _SupportedPlatforms({required this.label});
  final String label;

  static const _items = [
    ('YouTube', Icons.play_circle_fill),
    ('Facebook', Icons.facebook),
    ('Instagram', Icons.camera_alt),
    ('TikTok', Icons.music_note),
    ('X', Icons.close),
    ('Vimeo', Icons.videocam),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (name, icon) in _items)
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
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
