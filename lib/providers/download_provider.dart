import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/download_task.dart';
import '../models/media_format.dart';
import '../models/media_info.dart';
import '../models/media_source.dart';
import '../services/download_manager.dart';
import '../services/extractor_service.dart';
import '../services/storage_service.dart';

/// Owns the app's runtime state: resolving links, managing the download
/// queue, and persisting everything.
class DownloadProvider extends ChangeNotifier {
  DownloadProvider({
    ExtractorService? extractor,
    DownloadManager? manager,
  })  : _extractor = extractor ?? ExtractorService(),
        _manager = manager ?? DownloadManager() {
    _manager.onUpdate = _onTaskUpdate;
  }

  final ExtractorService _extractor;
  final DownloadManager _manager;

  final List<DownloadTask> _tasks = [];
  List<DownloadTask> get tasks => List.unmodifiable(_tasks.reversed);

  bool _resolving = false;
  bool get isResolving => _resolving;

  String? _resolveError;
  String? get resolveError => _resolveError;

  MediaInfo? _lastResolved;
  MediaInfo? get lastResolved => _lastResolved;

  Future<void> loadPersisted() async {
    final saved = await StorageService.instance.loadTasks();
    for (final t in saved) {
      // Anything left mid-flight is treated as paused so the user can resume.
      if (t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.queued) {
        t.status = DownloadStatus.paused;
      }
    }
    _tasks
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }

  /// Resolves a pasted URL into [MediaInfo]. Returns null on failure and sets
  /// [resolveError].
  Future<MediaInfo?> resolve(String url) async {
    _resolving = true;
    _resolveError = null;
    notifyListeners();
    try {
      final info = await _extractor.resolve(url);
      _lastResolved = info;
      return info;
    } catch (e) {
      _resolveError = e.toString();
      return null;
    } finally {
      _resolving = false;
      notifyListeners();
    }
  }

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    // On modern Android, app-scoped storage needs no runtime permission; we
    // still request notifications elsewhere. Media store writes are handled
    // by saving into the app documents dir which is always writable.
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited || status.isDenied;
  }

  Future<Directory> _downloadDir() async {
    Directory base;
    if (Platform.isAndroid) {
      base = await getApplicationDocumentsDirectory();
    } else {
      base = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }
    final dir = Directory('${base.path}/MediaGrab');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^\w\s.-]'), '_').trim();

  /// Queues a download for [format] from the currently resolved [info].
  Future<void> download(MediaInfo info, MediaFormat format) async {
    await _ensureStoragePermission();
    final dir = await _downloadDir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final safeTitle = _sanitize(info.title);
    final ext = format.audioOnlyMp3 ? 'm4a' : format.container;
    // NOTE: we save the source audio container. True MP3 transcoding requires
    // an ffmpeg step; the file is tagged so a post-process can convert it.
    final fileName = '$safeTitle-${format.displayQuality}.$ext';
    final savePath = '${dir.path}/${_sanitize(fileName)}';

    final task = DownloadTask.fromFormat(
      id: id,
      title: info.title,
      format: format,
      savePath: savePath,
      thumbnailUrl: info.thumbnailUrl,
      sourceLabel: info.source.label,
    );
    _tasks.add(task);
    notifyListeners();
    _persist();
    _manager.enqueue(task);
  }

  void pause(DownloadTask task) {
    _manager.pause(task);
  }

  void resume(DownloadTask task) {
    _manager.resume(task);
  }

  Future<void> cancel(DownloadTask task) async {
    await _manager.cancel(task);
    _persist();
  }

  Future<void> remove(DownloadTask task) async {
    _manager.remove(task);
    _tasks.remove(task);
    final file = File(task.savePath);
    if (task.status != DownloadStatus.completed && await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    notifyListeners();
    _persist();
  }

  void _onTaskUpdate(DownloadTask task) {
    notifyListeners();
    _persist();
  }

  void _persist() {
    StorageService.instance.saveTasks(_tasks);
  }

  @override
  void dispose() {
    _extractor.dispose();
    super.dispose();
  }
}
