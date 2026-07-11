import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../models/download_task.dart';
import '../../providers/download_provider.dart';

/// A single row in the downloads list with contextual actions.
class DownloadTile extends StatelessWidget {
  const DownloadTile({super.key, required this.task});

  final DownloadTask task;

  Color _statusColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (task.status) {
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return scheme.error;
      case DownloadStatus.paused:
        return Colors.orange;
      default:
        return scheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DownloadProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  task.container == 'mp3' || task.container == 'm4a'
                      ? Icons.audiotrack
                      : Icons.movie,
                  color: _statusColor(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          task.sourceLabel,
                          task.container.toUpperCase(),
                          task.sizeLabel,
                        ].where((e) => e != null && e.isNotEmpty).join(' • '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _ActionButtons(task: task, provider: provider),
              ],
            ),
            const SizedBox(height: 10),
            if (task.status == DownloadStatus.failed && task.error != null)
              Text(
                task.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: task.status == DownloadStatus.downloading &&
                                task.totalBytes == 0
                            ? null
                            : task.progress,
                        minHeight: 6,
                        color: _statusColor(context),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    task.status == DownloadStatus.completed
                        ? 'Done'
                        : task.progressLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.task, required this.provider});
  final DownloadTask task;
  final DownloadProvider provider;

  @override
  Widget build(BuildContext context) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.pause_circle),
          tooltip: 'Pause',
          onPressed: () => provider.pause(task),
        );
      case DownloadStatus.paused:
      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle),
              tooltip: 'Resume',
              onPressed: () => provider.resume(task),
            ),
            _deleteButton(context),
          ],
        );
      case DownloadStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open',
              onPressed: () => OpenFilex.open(task.savePath),
            ),
            _deleteButton(context),
          ],
        );
      default:
        return _deleteButton(context);
    }
  }

  Widget _deleteButton(BuildContext context) => IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Remove',
        onPressed: () => provider.remove(task),
      );
}
