import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_format.dart';
import '../../models/media_info.dart';
import '../../providers/download_provider.dart';

/// Bottom sheet that previews resolved media and lets the user pick a
/// video quality (144p → 4K) or extract audio.
class FormatSelectionSheet extends StatelessWidget {
  const FormatSelectionSheet({super.key, required this.info});

  final MediaInfo info;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Column(
            children: [
              _Header(info: info),
              const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.videocam), text: 'Video'),
                  Tab(icon: Icon(Icons.music_note), text: 'Audio'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _FormatList(
                      info: info,
                      formats: info.videoFormats,
                      controller: scrollController,
                      emptyText: 'No video formats available.',
                    ),
                    _FormatList(
                      info: info,
                      formats: info.audioFormats,
                      controller: scrollController,
                      emptyText: 'No audio formats available.',
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: info.thumbnailUrl != null
                ? Image.network(
                    info.thumbnailUrl!,
                    width: 96,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ThumbFallback(),
                  )
                : const _ThumbFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
        width: 96,
        height: 60,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.movie),
      );
}

class _FormatList extends StatelessWidget {
  const _FormatList({
    required this.info,
    required this.formats,
    required this.controller,
    required this.emptyText,
  });

  final MediaInfo info;
  final List<MediaFormat> formats;
  final ScrollController controller;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (formats.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: formats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final f = formats[i];
        return _FormatTile(info: info, format: f);
      },
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({required this.info, required this.format});
  final MediaInfo info;
  final MediaFormat format;

  IconData get _icon {
    if (format.audioOnlyMp3) return Icons.audiotrack;
    if (format.kind == MediaKind.audio) return Icons.music_note;
    return Icons.hd;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(_icon, color: scheme.onPrimaryContainer),
        ),
        title: Text(format.displayQuality),
        subtitle: Text(
          '${format.container.toUpperCase()} • ${format.sizeLabel}',
        ),
        trailing: FilledButton.tonal(
          onPressed: () async {
            await context.read<DownloadProvider>().download(info, format);
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to downloads')),
              );
            }
          },
          child: const Icon(Icons.download),
        ),
      ),
    );
  }
}
