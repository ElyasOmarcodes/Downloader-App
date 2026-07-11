import 'media_format.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  canceled,
}

extension DownloadStatusX on DownloadStatus {
  bool get isActive =>
      this == DownloadStatus.downloading || this == DownloadStatus.queued;
  bool get isTerminal =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.canceled;
}

/// A persistent, resumable download job.
class DownloadTask {
  DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.savePath,
    required this.container,
    this.thumbnailUrl,
    this.sourceLabel,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.status = DownloadStatus.queued,
    this.error,
    this.isAudio = false,
    this.youtubeVideoId,
    this.youtubeItag,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;

  /// Resolved direct media URL to fetch.
  final String url;

  /// Absolute path the file is written to.
  final String savePath;
  final String container;
  final String? thumbnailUrl;
  final String? sourceLabel;

  /// Whether this is an audio-only download (drives which folder it lands in).
  final bool isAudio;

  /// When set, the file is fetched via the YouTube stream client (fixes the
  /// 403 that plain HTTP GETs hit on adaptive audio streams).
  final String? youtubeVideoId;
  final int? youtubeItag;

  int totalBytes;

  /// Bytes already written to [savePath]. Drives resume via HTTP Range.
  int receivedBytes;

  DownloadStatus status;
  String? error;
  final DateTime createdAt;

  double get progress {
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get progressLabel => '${(progress * 100).toStringAsFixed(0)}%';

  String _fmt(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(2)} GB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get sizeLabel {
    if (totalBytes <= 0) return _fmt(receivedBytes);
    return '${_fmt(receivedBytes)} / ${_fmt(totalBytes)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'savePath': savePath,
        'container': container,
        'thumbnailUrl': thumbnailUrl,
        'sourceLabel': sourceLabel,
        'totalBytes': totalBytes,
        'receivedBytes': receivedBytes,
        'status': status.name,
        'error': error,
        'isAudio': isAudio,
        'youtubeVideoId': youtubeVideoId,
        'youtubeItag': youtubeItag,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id'] as String,
        title: json['title'] as String,
        url: json['url'] as String,
        savePath: json['savePath'] as String,
        container: json['container'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        sourceLabel: json['sourceLabel'] as String?,
        totalBytes: json['totalBytes'] as int? ?? 0,
        receivedBytes: json['receivedBytes'] as int? ?? 0,
        status: DownloadStatus.values.byName(json['status'] as String),
        error: json['error'] as String?,
        isAudio: json['isAudio'] as bool? ?? false,
        youtubeVideoId: json['youtubeVideoId'] as String?,
        youtubeItag: json['youtubeItag'] as int?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  static DownloadTask fromFormat({
    required String id,
    required String title,
    required MediaFormat format,
    required String savePath,
    String? thumbnailUrl,
    String? sourceLabel,
    bool isAudio = false,
    String? youtubeVideoId,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      url: format.url,
      savePath: savePath,
      container: format.container,
      thumbnailUrl: thumbnailUrl,
      sourceLabel: sourceLabel,
      isAudio: isAudio,
      youtubeVideoId: youtubeVideoId,
      youtubeItag: format.itag,
      totalBytes: format.sizeBytes ?? 0,
    );
  }
}
