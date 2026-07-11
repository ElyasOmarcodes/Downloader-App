import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

import '../../models/media_format.dart';
import '../../models/media_info.dart';
import '../../models/media_source.dart';
import '../../models/subtitle_track.dart';
import '../platform_detector.dart';
import 'extractor.dart';

/// Resolves YouTube URLs using `youtube_explode_dart`.
///
/// Exposes every muxed + video-only + audio-only stream, plus a synthetic
/// "MP3 (extract audio)" entry backed by the best audio stream.
class YoutubeExtractor implements Extractor {
  final yt.YoutubeExplode _yt = yt.YoutubeExplode();

  @override
  bool canHandle(String url) =>
      PlatformDetector.detect(url) == MediaSource.youtube;

  @override
  Future<MediaInfo> resolve(String url) async {
    try {
      final video = await _yt.videos.get(url);
      // Start both requests in parallel to keep link resolution fast; the
      // caption fetch is optional so we swallow its errors.
      final manifestFuture = _yt.videos.streamsClient.getManifest(video.id);
      final captionsFuture = _yt.videos.closedCaptions
          .getManifest(video.id)
          .then<yt.ClosedCaptionManifest?>((m) => m)
          .catchError((_) => null);

      final manifest = await manifestFuture;

      final subtitles = <SubtitleTrack>[];
      final captions = await captionsFuture;
      if (captions != null) {
        for (final track in captions.tracks) {
          subtitles.add(SubtitleTrack(
            label: track.language.name,
            url: track.url.toString(),
            ext: 'vtt',
          ));
        }
      }

      final formats = <MediaFormat>[];

      // Muxed streams (video + audio in one file — simplest to download).
      for (final s in manifest.muxed.sortByVideoQuality()) {
        formats.add(MediaFormat(
          url: s.url.toString(),
          kind: MediaKind.muxed,
          container: s.container.name,
          itag: s.tag,
          qualityLabel: s.videoQualityLabel,
          bitrate: s.bitrate.bitsPerSecond.toInt(),
          sizeBytes: s.size.totalBytes.toInt(),
          hasAudio: true,
          hasVideo: true,
        ));
      }

      // Video-only streams (higher resolutions, incl. 1440p / 2160p / 4K).
      for (final s in manifest.videoOnly.sortByVideoQuality()) {
        formats.add(MediaFormat(
          url: s.url.toString(),
          kind: MediaKind.video,
          container: s.container.name,
          itag: s.tag,
          qualityLabel: s.videoQualityLabel,
          bitrate: s.bitrate.bitsPerSecond.toInt(),
          sizeBytes: s.size.totalBytes.toInt(),
          hasVideo: true,
        ));
      }

      // Best audio stream -> offered both as-is and as an "MP3" pseudo format.
      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isNotEmpty) {
        final best = audioStreams.last;
        formats.add(MediaFormat(
          url: best.url.toString(),
          kind: MediaKind.audio,
          container: best.container.name,
          itag: best.tag,
          qualityLabel:
              '${(best.bitrate.bitsPerSecond / 1000).round()}kbps',
          bitrate: best.bitrate.bitsPerSecond.toInt(),
          sizeBytes: best.size.totalBytes.toInt(),
          hasAudio: true,
        ));
        formats.add(MediaFormat(
          url: best.url.toString(),
          kind: MediaKind.audio,
          container: 'mp3',
          itag: best.tag,
          qualityLabel: 'MP3 (audio)',
          bitrate: best.bitrate.bitsPerSecond.toInt(),
          sizeBytes: best.size.totalBytes.toInt(),
          hasAudio: true,
          audioOnlyMp3: true,
        ));
      }

      return MediaInfo(
        sourceUrl: url,
        source: MediaSource.youtube,
        sourceId: video.id.value,
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.highResUrl,
        durationSeconds: video.duration?.inSeconds,
        formats: formats,
        subtitles: subtitles,
      );
    } on yt.VideoUnavailableException {
      throw ExtractionException('This video is unavailable or private.');
    } catch (e) {
      throw ExtractionException('Failed to resolve YouTube link: $e');
    }
  }

  @override
  void dispose() => _yt.close();
}
