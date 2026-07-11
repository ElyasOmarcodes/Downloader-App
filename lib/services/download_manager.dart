import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/download_task.dart';
import 'notification_service.dart';

/// Signature invoked whenever a task's state changes so the UI can rebuild.
typedef TaskListener = void Function(DownloadTask task);

/// Streams remote media to disk with real pause / resume support.
///
/// Resume works by tracking how many bytes are already on disk and asking the
/// server for the remainder via an HTTP `Range: bytes=<offset>-` header, then
/// appending to the existing file. This survives both in-session pauses and
/// full app restarts (the offset is persisted with the task).
class DownloadManager {
  DownloadManager({Dio? dio, int maxConcurrent = 2})
      : _dio = dio ?? Dio(),
        _maxConcurrent = maxConcurrent;

  final Dio _dio;
  int _maxConcurrent;

  /// A desktop browser UA — some CDNs (notably googlevideo) reject requests
  /// that don't look like a browser with a 403.
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  static const _maxRetries = 3;

  final Map<String, CancelToken> _tokens = {};
  final Set<String> _active = {};
  final List<DownloadTask> _queue = [];
  final Map<String, int> _retries = {};

  TaskListener? onUpdate;

  bool get _hasSlot => _active.length < _maxConcurrent;

  /// Adjusts how many downloads may run at once (e.g. WiFi vs mobile).
  void setMaxConcurrent(int value) {
    _maxConcurrent = value.clamp(1, 6);
    _pump();
  }

  /// Enqueues [task] and starts it as soon as a concurrency slot is free.
  void enqueue(DownloadTask task) {
    _queue.add(task);
    _pump();
  }

  void _pump() {
    for (final task in _queue) {
      if (!_hasSlot) break;
      if (task.status == DownloadStatus.queued && !_active.contains(task.id)) {
        _start(task);
      }
    }
  }

  bool _isGoogleVideo(String url) => url.contains('googlevideo.com');

  Future<void> _start(DownloadTask task) async {
    _active.add(task.id);
    final token = CancelToken();
    _tokens[task.id] = token;
    task.status = DownloadStatus.downloading;
    task.error = null;
    _notify(task);

    final file = File(task.savePath);
    try {
      await file.parent.create(recursive: true);

      // Resume from whatever is already on disk.
      var offset = 0;
      if (await file.exists()) {
        offset = await file.length();
      }
      task.receivedBytes = offset;

      // googlevideo requires a Range header even from byte 0, otherwise it
      // frequently answers 403 for adaptive (audio-only / video-only) streams.
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

      // If we asked to resume but the server ignored Range (200 instead of a
      // 206 Partial Content), restart cleanly to avoid a corrupt file.
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
      if (contentLength > 0) {
        task.totalBytes = offset + contentLength;
      }

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
        // Paused / canceled — state already set by pause()/cancel().
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

  /// Keeps the partial file and transparently retries a few times before
  /// surfacing the failure. The partial is never deleted, so the user (or the
  /// auto-retry) can always resume from where it stopped.
  Future<void> _handleFailure(DownloadTask task, String message) async {
    final attempts = (_retries[task.id] ?? 0) + 1;
    _retries[task.id] = attempts;
    if (attempts <= _maxRetries) {
      task.status = DownloadStatus.queued;
      task.error = null;
      if (!_queue.contains(task)) _queue.add(task);
      _notify(task);
      // Small backoff before the queue picks it up again.
      Future<void>.delayed(Duration(seconds: attempts * 2), _pump);
    } else {
      task.status = DownloadStatus.failed;
      task.error = message;
      _notify(task);
    }
  }

  /// Pauses an in-flight download. Bytes already written are kept on disk.
  void pause(DownloadTask task) {
    if (task.status != DownloadStatus.downloading) return;
    task.status = DownloadStatus.paused;
    _tokens[task.id]?.cancel('paused');
    _notify(task);
  }

  /// Resumes a paused/failed download, appending to the existing partial file.
  void resume(DownloadTask task) {
    if (task.status == DownloadStatus.downloading) return;
    _retries.remove(task.id);
    task.status = DownloadStatus.queued;
    task.error = null;
    if (!_queue.contains(task)) _queue.add(task);
    _notify(task);
    _pump();
  }

  /// Cancels a download and deletes any partial file.
  Future<void> cancel(DownloadTask task) async {
    _tokens[task.id]?.cancel('canceled');
    task.status = DownloadStatus.canceled;
    _queue.remove(task);
    final file = File(task.savePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    await NotificationService.instance.cancel(task.id.hashCode);
    _notify(task);
  }

  void remove(DownloadTask task) {
    _tokens[task.id]?.cancel('removed');
    _queue.remove(task);
    _active.remove(task.id);
  }

  void _notify(DownloadTask task) => onUpdate?.call(task);
}
