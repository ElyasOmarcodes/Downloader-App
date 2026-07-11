import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import '../widgets/download_tile.dart';

/// Lists all downloads (active and completed) with management controls.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<DownloadProvider>().tasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          if (tasks.any((t) => t.status == DownloadStatus.completed))
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined),
              tooltip: 'Clear completed',
              onPressed: () {
                final provider = context.read<DownloadProvider>();
                for (final t in tasks
                    .where((t) => t.status == DownloadStatus.completed)
                    .toList()) {
                  provider.remove(t);
                }
              },
            ),
        ],
      ),
      body: tasks.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => DownloadTile(task: tasks[i]),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
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
          Text(
            'No downloads yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a link on the Home tab to get started.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
