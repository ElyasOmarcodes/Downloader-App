import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import '../models/download_task.dart';
import 'notification_service.dart';

/// Signature invoked whenever a task's state changes so the UI can rebuild.
typedef TaskListener = void Function(DownloadTask task);

/// Streams remote media to disk with real pause / resume support.
///
/// Two fetch paths:
///  * YouTube tasks (with a stored itag) stream through the YouTube stream
///    client, which handles URL signing / throttling and avoids the 403 that
///    plain HTTP GETs hit on adaptive audio streams.
///  * Everything else streams over HTTP with `dio`, resuming via HTTP Range.
class DownloadManager {
  DownloadManager({Dio? dio, int maxConcurrent = 2})
      : _dio = dio ?? Dio(),
        _maxConcurrent = maxConcurrent;

  final Dio _dio;
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();
  int _maxConcurrent;

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  static const _maxRetries = 3;

  final Map<String, CancelToken> _tokens = {};
  final Map<String, StreamSubscription<List<int>>> _ytSubs = {};
  final Map<String, Completer<void>> _ytCompleters = {};
  final Set<String> _active = {};
  final List<DownloadTask> _queue = [];
  final Map<String, int> _retries = {};

  TaskListener? onUpdate;

  bool get _hasSlot => _active.length < _maxConcurrent;

  void setMaxConcurrent(int value) {
    _maxConcurrent = value.clamp(1, 6);
    _pump();
  }

  void enqueue(DownloadTask task) {
    _queue.add(task);
    _pump();
  }

  void _pump() {
    for (final task in _queue) {
      if (!_hasSlot) break;
      if (task.status == DownloadStatus.queued && !_active.contains(task.id)) {
        if (task.youtubeItag != null && task.youtubeVideoId != null) {
          _startYoutube(task);
        } else {
          _startHttp(task);
        }
      }
    }
  }

  bool _isGoogleVideo(String url) => url.contains('googlevideo.com');

  // ---------------------------------------------------------------------------
  // YouTube path
  // ---------------------------------------------------------------------------
  Future<void> _startYoutube(DownloadTask task) async {
    _active.add(task.id);
    task.status = DownloadStatus.downloading;
    task.error = null;
    _notify(task);

    final file = File(task.savePath);
    final completer = Completer<void>();
    _ytCompleters[task.id] = completer;
    IOSink? sink;
    try {
      await file.parent.create(recursive: true);
      final manifest =
          await _yt.videos.streamsClient.getManifest(task.youtubeVideoId!);
      final stream = manifest.streams.firstWhere(
        (s) => s.tag == task.youtubeItag,
        orElse: () => manifest.streams.first,
      );
      task.totalBytes = stream.size.totalBytes.toInt();
      task.receivedBytes = 0;
      sink = file.openWrite();

      var lastNotified = DateTime.fromMillisecondsSinceEpoch(0);
      _ytSubs[task.id] = _yt.videos.streamsClient.get(stream).listen(
        (chunk) {
          sink!.add(chunk);
          task.receivedBytes += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastNotified).inMilliseconds > 400) {
            lastNotified = now;
            _notify(task);
            NotificationService.instance.showProgress(
              id: task.id.hashCode,
              title: task.title,
              progress: (task.progress * 100).round(),
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      await completer.future;
      await sink.flush();
      await sink.close();

      if (task.status == DownloadStatus.paused) {
        _notify(task);
      } else {
        task.status = DownloadStatus.completed;
        _retries.remove(task.id);
        _notify(task);
        await NotificationService.instance.cancel(task.id.hashCode);
        await NotificationService.instance
            .showComplete(id: task.id.hashCode, title: task.title);
      }
    } catch (e) {
      try {
        await sink?.flush();
        await sink?.close();
      } catch (_) {}
      if (task.status != DownloadStatus.paused) {
        await _handleFailure(task, e.toString());
      } else {
        _notify(task);
      }
    } finally {
      _ytSubs.remove(task.id);
      _ytCompleters.remove(task.id);
      _active.remove(task.id);
      _pump();
    }
  }

  // ---------------------------------------------------------------------------
  // HTTP path
  // ---------------------------------------------------------------------------
  Future<void> _startHttp(DownloadTask task) async {
    _active.add(task.id);
    final token = CancelToken();
    _tokens[task.id] = token;
    task.status = DownloadStatus.downloading;
    task.error = null;
    _notify(task);

    final file = File(task.savePath);
    try {
      await file.parent.create(recursive: true);

      var offset = 0;
      if (await file.exists()) offset = await file.length();
      task.receivedBytes = offset;

      final needsRange = offset > 0 || _isGoogleVideo(task.url);
      final headers = <String, String>{'User-Agent': _userAgent};
      if (needsRange) headers['Range'] = 'bytes=$offset-';

      final response = await _dio.get<ResponseBody>(
        task.url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          headers: headers,
          validateStatus: (s) => s != null && s < 400,
        ),
      );

      if (offset > 0 && response.statusCode == 200) {
        offset = 0;
        task.receivedBytes = 0;
      }
      final sink = file.openWrite(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );

      final contentLength = int.tryParse(
              response.headers.value(Headers.contentLengthHeader) ?? '') ??
          0;
      if (contentLength > 0) task.totalBytes = offset + contentLength;

      var lastNotified = DateTime.fromMillisecondsSinceEpoch(0);
      final completer = Completer<void>();

      response.data!.stream.listen(
        (chunk) {
          sink.add(chunk);
          task.receivedBytes += chunk.length;
          final now = DateTime.now();
          if (now.difference(lastNotified).inMilliseconds > 400) {
            lastNotified = now;
            _notify(task);
            NotificationService.instance.showProgress(
              id: task.id.hashCode,
              title: task.title,
              progress: (task.progress * 100).round(),
            );
          }
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e, StackTrace st) async {
          await sink.flush();
          await sink.close();
          if (!completer.isCompleted) completer.completeError(e);
        },
        cancelOnError: true,
      );

      await completer.future;

      task.status = DownloadStatus.completed;
      if (task.totalBytes <= 0) task.totalBytes = task.receivedBytes;
      _retries.remove(task.id);
      _notify(task);
      await NotificationService.instance.cancel(task.id.hashCode);
      await NotificationService.instance
          .showComplete(id: task.id.hashCode, title: task.title);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (task.status == DownloadStatus.downloading) {
          task.status = DownloadStatus.paused;
        }
        _notify(task);
      } else {
        await _handleFailure(task, e.message ?? 'Network error');
      }
    } catch (e) {
      await _handleFailure(task, e.toString());
    } finally {
      _active.remove(task.id);
      _tokens.remove(task.id);
      _pump();
    }
  }

  Future<void> _handleFailure(DownloadTask task, String message) async {
    final attempts = (_retries[task.id] ?? 0) + 1;
    _retries[task.id] = attempts;
    if (attempts <= _maxRetries) {
      task.status = DownloadStatus.queued;
      task.error = null;
      if (!_queue.contains(task)) _queue.add(task);
      _notify(task);
      Future<void>.delayed(Duration(seconds: attempts * 2), _pump);
    } else {
      task.status = DownloadStatus.failed;
      task.error = message;
      _notify(task);
    }
  }

  void pause(DownloadTask task) {
    if (task.status != DownloadStatus.downloading) return;
    task.status = DownloadStatus.paused;
    _tokens[task.id]?.cancel('paused');
    _ytSubs[task.id]?.cancel();
    _ytCompleters[task.id]?.complete();
    _notify(task);
  }

  void resume(DownloadTask task) {
    if (task.status == DownloadStatus.downloading) return;
    _retries.remove(task.id);
    task.status = DownloadStatus.queued;
    task.error = null;
    if (!_queue.contains(task)) _queue.add(task);
    _notify(task);
    _pump();
  }

  Future<void> cancel(DownloadTask task) async {
    _tokens[task.id]?.cancel('canceled');
    _ytSubs[task.id]?.cancel();
    _ytCompleters[task.id]?.complete();
    task.status = DownloadStatus.canceled;
    _queue.remove(task);
    final f = File(task.savePath);
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
    await NotificationService.instance.cancel(task.id.hashCode);
    _notify(task);
  }

  void remove(DownloadTask task) {
    _tokens[task.id]?.cancel('removed');
    _ytSubs[task.id]?.cancel();
    _ytCompleters[task.id]?.complete();
    _queue.remove(task);
    _active.remove(task.id);
  }

  void _notify(DownloadTask task) => onUpdate?.call(task);
}
