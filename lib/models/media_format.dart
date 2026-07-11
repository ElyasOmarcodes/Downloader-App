import 'package:flutter/foundation.dart';

/// The kind of media a [MediaFormat] represents.
enum MediaKind { video, audio, muxed }

/// A single downloadable representation of a piece of media
/// (a specific quality / container / codec).
@immutable
class MediaFormat {
  const MediaFormat({
    required this.url,
    required this.kind,
    required this.container,
    this.qualityLabel,
    this.bitrate,
    this.sizeBytes,
    this.hasAudio = false,
    this.hasVideo = false,
    this.audioOnlyMp3 = false,
  });

  /// Direct download URL for this format.
  final String url;

  final MediaKind kind;

  /// File extension / container, e.g. `mp4`, `webm`, `m4a`, `mp3`.
  final String container;

  /// Human readable quality, e.g. `1080p`, `4K`, `128kbps`.
  final String? qualityLabel;

  /// Bitrate in bits per second, when known.
  final int? bitrate;

  /// Total size in bytes, when the server reports it.
  final int? sizeBytes;

  final bool hasAudio;
  final bool hasVideo;

  /// When true this represents an "extract audio as MP3" pseudo-format.
  final bool audioOnlyMp3;

  String get displayQuality {
    if (qualityLabel != null) return qualityLabel!;
    if (kind == MediaKind.audio) {
      final kbps = bitrate != null ? '${(bitrate! / 1000).round()}kbps' : '';
      return 'Audio $kbps'.trim();
    }
    return container.toUpperCase();
  }

  String get sizeLabel {
    if (sizeBytes == null || sizeBytes == 0) return '—';
    final mb = sizeBytes! / (1024 * 1024);
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(2)} GB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'kind': kind.name,
        'container': container,
        'qualityLabel': qualityLabel,
        'bitrate': bitrate,
        'sizeBytes': sizeBytes,
        'hasAudio': hasAudio,
        'hasVideo': hasVideo,
        'audioOnlyMp3': audioOnlyMp3,
      };

  factory MediaFormat.fromJson(Map<String, dynamic> json) => MediaFormat(
        url: json['url'] as String,
        kind: MediaKind.values.byName(json['kind'] as String),
        container: json['container'] as String,
        qualityLabel: json['qualityLabel'] as String?,
        bitrate: json['bitrate'] as int?,
        sizeBytes: json['sizeBytes'] as int?,
        hasAudio: json['hasAudio'] as bool? ?? false,
        hasVideo: json['hasVideo'] as bool? ?? false,
        audioOnlyMp3: json['audioOnlyMp3'] as bool? ?? false,
      );
}
