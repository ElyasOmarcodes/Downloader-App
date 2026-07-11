import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import '../widgets/download_tile.dart';

/// Snaptube-style downloads tab: active/paused downloads in a sub-list at the
/// top, completed downloads in the main list below.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final provider = context.watch<DownloadProvider>();
    final active = provider.activeTasks;
    final completed = provider.completedTasks;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('downloads')),
        actions: [
          if (active.any((t) => t.status == DownloadStatus.downloading))
            IconButton(
              tooltip: l.t('pauseAll'),
              icon: const Icon(Icons.pause),
              onPressed: provider.pauseAll,
            ),
          if (active.any((t) => t.status != DownloadStatus.downloading))
            IconButton(
              tooltip: l.t('resumeAll'),
              icon: const Icon(Icons.play_arrow),
              onPressed: provider.resumeAll,
            ),
          if (completed.isNotEmpty)
            IconButton(
              tooltip: l.t('clearCompleted'),
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () {
                for (final t in completed) {
                  provider.remove(t);
                }
              },
            ),
        ],
      ),
      body: (active.isEmpty && completed.isEmpty)
          ? const _EmptyState()
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.downloading,
                    label: '${l.t('inProgress')} (${active.length})',
                  ),
                  for (final t in active)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DownloadTile(task: t),
                    ),
                  const SizedBox(height: 8),
                ],
                if (completed.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.check_circle,
                    label: '${l.t('completed')} (${completed.length})',
                  ),
                  for (final t in completed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DownloadTile(task: t),
                    ),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_done_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(l.t('noDownloads'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l.t('noDownloadsHint'),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
