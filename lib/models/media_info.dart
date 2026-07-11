import 'media_format.dart';
import 'media_source.dart';
import 'subtitle_track.dart';

/// The resolved metadata + available formats for a given media URL.
class MediaInfo {
  MediaInfo({
    required this.sourceUrl,
    required this.source,
    required this.title,
    required this.formats,
    this.author,
    this.thumbnailUrl,
    this.durationSeconds,
    this.subtitles = const [],
    this.sourceId,
  });

  final String sourceUrl;
  final MediaSource source;

  /// Platform-specific media id (e.g. the YouTube video id) when known.
  final String? sourceId;
  final String title;
  final String? author;
  final String? thumbnailUrl;
  final int? durationSeconds;

  /// Available subtitle tracks (may be empty).
  final List<SubtitleTrack> subtitles;

  bool get hasSubtitles => subtitles.isNotEmpty;

  /// All downloadable formats, typically sorted best-first by the extractor.
  final List<MediaFormat> formats;

  List<MediaFormat> get videoFormats =>
      formats.where((f) => f.hasVideo).toList();

  List<MediaFormat> get audioFormats => formats
      .where((f) => f.kind == MediaKind.audio || f.audioOnlyMp3)
      .toList();

  String get durationLabel {
    final s = durationSeconds;
    if (s == null) return '';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }
}
