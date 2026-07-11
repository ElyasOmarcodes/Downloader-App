import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/media_format.dart';
import '../../models/media_info.dart';
import '../../providers/download_provider.dart';

/// Bottom sheet that previews resolved media, lets the user pick ONE format
/// (video quality 144p→4K or audio), optionally attach subtitles, and start
/// the download from a single button pinned at the bottom.
class FormatSelectionSheet extends StatefulWidget {
  const FormatSelectionSheet({super.key, required this.info});

  final MediaInfo info;

  @override
  State<FormatSelectionSheet> createState() => _FormatSelectionSheetState();
}

class _FormatSelectionSheetState extends State<FormatSelectionSheet> {
  MediaFormat? _selected;
  bool _withSubtitles = false;

  @override
  void initState() {
    super.initState();
    // Preselect the best video format, else the first available.
    final v = widget.info.videoFormats;
    final a = widget.info.audioFormats;
    _selected = v.isNotEmpty ? v.first : (a.isNotEmpty ? a.first : null);
  }

  Future<void> _startDownload() async {
    final sel = _selected;
    if (sel == null) return;
    final l = AppLocalizations.of(context);
    await context
        .read<DownloadProvider>()
        .download(widget.info, sel, withSubtitles: _withSubtitles);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.t('addedToDownloads'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final info = widget.info;

    return DefaultTabController(
      length: 2,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Column(
            children: [
              _Header(info: info),
              TabBar(
                tabs: [
                  Tab(icon: const Icon(Icons.videocam), text: l.t('video')),
                  Tab(icon: const Icon(Icons.music_note), text: l.t('audio')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _FormatList(
                      formats: info.videoFormats,
                      selected: _selected,
                      controller: scrollController,
                      emptyText: l.t('noVideoFormats'),
                      onSelect: (f) => setState(() => _selected = f),
                    ),
                    _FormatList(
                      formats: info.audioFormats,
                      selected: _selected,
                      controller: scrollController,
                      emptyText: l.t('noAudioFormats'),
                      onSelect: (f) => setState(() => _selected = f),
                    ),
                  ],
                ),
              ),
              _BottomBar(
                hasSubtitles: info.hasSubtitles,
                withSubtitles: _withSubtitles,
                onSubtitleChanged: (v) =>
                    setState(() => _withSubtitles = v ?? false),
                canDownload: _selected != null,
                onDownload: _startDownload,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.info});
  final MediaInfo info;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: info.thumbnailUrl != null
                ? Image.network(
                    info.thumbnailUrl!,
                    width: 104,
                    height: 62,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ThumbFallback(),
                  )
                : const _ThumbFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  [info.author, info.durationLabel]
                      .where((e) => e != null && e.isNotEmpty)
                      .join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();
  @override
  Widget build(BuildContext context) => Container(
        width: 104,
        height: 62,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.movie),
      );
}

class _FormatList extends StatelessWidget {
  const _FormatList({
    required this.formats,
    required this.selected,
    required this.controller,
    required this.emptyText,
    required this.onSelect,
  });

  final List<MediaFormat> formats;
  final MediaFormat? selected;
  final ScrollController controller;
  final String emptyText;
  final ValueChanged<MediaFormat> onSelect;

  @override
  Widget build(BuildContext context) {
    if (formats.isEmpty) return Center(child: Text(emptyText));
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: formats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final f = formats[i];
        final scheme = Theme.of(context).colorScheme;
        final isSelected = identical(f, selected) || f == selected;
        return Card(
          color: isSelected ? scheme.primaryContainer : null,
          child: RadioListTile<MediaFormat>(
            value: f,
            groupValue: selected,
            onChanged: (v) => v != null ? onSelect(v) : null,
            controlAffinity: ListTileControlAffinity.leading,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              f.displayQuality,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            // Horizontal metadata row — kept in a single line so the text can
            // never collapse into a vertical, one-character-per-line column.
            subtitle: Text(
              '${f.container.toUpperCase()}  •  ${f.sizeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            secondary: Icon(
              f.audioOnlyMp3 || f.kind == MediaKind.audio
                  ? Icons.audiotrack
                  : Icons.high_quality,
              color: scheme.primary,
            ),
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.hasSubtitles,
    required this.withSubtitles,
    required this.onSubtitleChanged,
    required this.canDownload,
    required this.onDownload,
  });

  final bool hasSubtitles;
  final bool withSubtitles;
  final ValueChanged<bool?> onSubtitleChanged;
  final bool canDownload;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSubtitles)
            CheckboxListTile(
              value: withSubtitles,
              onChanged: onSubtitleChanged,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(l.t('downloadSubtitles')),
              secondary: const Icon(Icons.closed_caption),
            ),
          FilledButton.icon(
            onPressed: canDownload ? onDownload : null,
            icon: const Icon(Icons.download),
            label: Text(l.t('download')),
          ),
        ],
      ),
    );
  }
}
