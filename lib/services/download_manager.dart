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
  final int _maxConcurrent;

  final Map<String, CancelToken> _tokens = {};
  final Set<String> _active = {};
  final List<DownloadTask> _queue = [];

  TaskListener? onUpdate;

  bool get _hasSlot => _active.length < _maxConcurrent;

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

      final response = await _dio.get<ResponseBody>(
        task.url,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          headers: offset > 0 ? {'Range': 'bytes=$offset-'} : null,
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

      // Derive total size (content-length is the *remaining* length on a 206).
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
      } else {
        task.status = DownloadStatus.failed;
        task.error = e.message ?? 'Network error';
      }
      _notify(task);
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      _notify(task);
    } finally {
      _active.remove(task.id);
      _tokens.remove(task.id);
      _pump();
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
    task.status = DownloadStatus.queued;
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
