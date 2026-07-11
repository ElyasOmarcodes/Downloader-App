import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/download_task.dart';
import '../models/media_format.dart';
import '../models/media_info.dart';
import '../models/media_source.dart';
import '../services/connectivity_service.dart';
import '../services/download_manager.dart';
import '../services/extractor_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';

/// Owns the app's runtime state: resolving links, managing the download
/// queue, folder layout, and persistence.
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
  final Dio _dio = Dio();

  final List<DownloadTask> _tasks = [];
  List<DownloadTask> get tasks => List.unmodifiable(_tasks.reversed);

  /// Active or paused (not yet complete) downloads — shown as a sub-list.
  List<DownloadTask> get activeTasks => tasks
      .where((t) => t.status != DownloadStatus.completed)
      .toList();

  /// Finished downloads.
  List<DownloadTask> get completedTasks =>
      tasks.where((t) => t.status == DownloadStatus.completed).toList();

  bool _resolving = false;
  bool get isResolving => _resolving;

  String? _resolveError;
  String? get resolveError => _resolveError;

  MediaInfo? _lastResolved;
  MediaInfo? get lastResolved => _lastResolved;

  /// Emits resolved media that the UI should present a download sheet for
  /// (used by share intents).
  final StreamController<MediaInfo> _autoSheet =
      StreamController<MediaInfo>.broadcast();
  Stream<MediaInfo> get autoSheetStream => _autoSheet.stream;

  /// A link detected on the clipboard: the Home field prefills it, but nothing
  /// is resolved until the user taps Fetch.
  final ValueNotifier<String?> clipboardLink = ValueNotifier<String?>(null);

  Future<void> loadPersisted() async {
    final saved = await StorageService.instance.loadTasks();
    for (final t in saved) {
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

  /// Resolves a pasted URL into [MediaInfo]. Returns null on failure.
  /// [cookie] may carry a logged-in session captured from the in-app browser.
  Future<MediaInfo?> resolve(String url, {String? cookie}) async {
    _resolving = true;
    _resolveError = null;
    notifyListeners();
    try {
      final info = await _extractor.resolve(url, cookie: cookie);
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

  /// Resolves a page open in the in-app browser (with its session cookie) and
  /// presents the download sheet on success.
  Future<void> resolveViaBrowser(String url, String? cookie) async {
    final info = await resolve(url, cookie: cookie);
    if (info != null) _autoSheet.add(info);
  }

  /// Resolves [url] coming from a share intent or the clipboard and, on
  /// success, asks the UI (via [autoSheetStream]) to present the sheet.
  Future<void> autoResolve(String url) async {
    final info = await resolve(url);
    if (info != null) _autoSheet.add(info);
  }

  // ---------------------------------------------------------------------------
  // Storage layout: <primary storage>/MediaGrab/{Video,Audio}
  // ---------------------------------------------------------------------------
  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;
    await Permission.notification.request();
    // All-files access lets us write into a public /MediaGrab folder on
    // Android 11+. If the user declines we fall back to app-scoped storage.
    if (await Permission.manageExternalStorage.isDenied) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<Directory> _mediaDir({required bool isAudio}) async {
    final sub = isAudio ? 'Audio' : 'Video';
    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          // .../Android/data/<pkg>/files -> take the primary-storage root.
          final root = ext.path.split('/Android/').first; // /storage/emulated/0
          final dir = Directory('$root/MediaGrab/$sub');
          await dir.create(recursive: true);
          return dir;
        }
      } catch (_) {
        // Fall through to app-scoped storage.
      }
    }
    final base = Platform.isAndroid
        ? await getApplicationDocumentsDirectory()
        : (await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory());
    final dir = Directory('${base.path}/MediaGrab/$sub');
    await dir.create(recursive: true);
    return dir;
  }

  String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^\w\s.-]'), '_').trim();

  /// Queues a download for [format] and, optionally, its subtitles.
  Future<void> download(
    MediaInfo info,
    MediaFormat format, {
    bool withSubtitles = false,
  }) async {
    await _ensurePermissions();
    await _applyConcurrency();

    final isAudio = format.kind == MediaKind.audio || format.audioOnlyMp3;
    final dir = await _mediaDir(isAudio: isAudio);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final safeTitle = _sanitize(info.title);
    final ext = format.audioOnlyMp3 ? 'm4a' : format.container;
    final fileName = _sanitize('$safeTitle-${format.displayQuality}.$ext');
    final savePath = '${dir.path}/$fileName';

    final task = DownloadTask.fromFormat(
      id: id,
      title: info.title,
      format: format,
      savePath: savePath,
      thumbnailUrl: info.thumbnailUrl,
      sourceLabel: info.source.label,
      isAudio: isAudio,
      youtubeVideoId:
          info.source == MediaSource.youtube ? info.sourceId : null,
    );
    _tasks.add(task);
    notifyListeners();
    _persist();
    _manager.enqueue(task);

    if (withSubtitles && info.hasSubtitles) {
      unawaited(_downloadSubtitle(info, dir, safeTitle));
    }
  }

  /// Saves the first subtitle track as a sidecar file next to the media.
  Future<void> _downloadSubtitle(
      MediaInfo info, Directory dir, String safeTitle) async {
    try {
      final sub = info.subtitles.first;
      final path = '${dir.path}/${_sanitize('$safeTitle.${sub.ext}')}';
      await _dio.download(sub.url, path);
    } catch (_) {
      // Subtitles are best-effort; ignore failures.
    }
  }

  /// Sets the manager's concurrency from settings + current network type.
  Future<void> _applyConcurrency() async {
    final onWifi = await ConnectivityService.instance.isWifi();
    final limit = onWifi
        ? SettingsService.instance.wifiConcurrency
        : SettingsService.instance.mobileConcurrency;
    _manager.setMaxConcurrent(limit);
  }

  void pauseAll() {
    for (final t in _tasks) {
      if (t.status == DownloadStatus.downloading) _manager.pause(t);
    }
  }

  void resumeAll() {
    _applyConcurrency();
    for (final t in _tasks) {
      if (t.status == DownloadStatus.paused ||
          t.status == DownloadStatus.failed) {
        _manager.resume(t);
      }
    }
  }

  void pause(DownloadTask task) => _manager.pause(task);

  void resume(DownloadTask task) {
    _applyConcurrency();
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

  void _persist() => StorageService.instance.saveTasks(_tasks);

  @override
  void dispose() {
    _autoSheet.close();
    clipboardLink.dispose();
    _extractor.dispose();
    super.dispose();
  }
}
