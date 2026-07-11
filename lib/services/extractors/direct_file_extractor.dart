import 'package:dio/dio.dart';

import '../../models/media_format.dart';
import '../../models/media_info.dart';
import '../../models/media_source.dart';
import '../platform_detector.dart';
import 'extractor.dart';

/// Handles plain direct links to media files (`.mp4`, `.mp3`, ...).
/// Uses a HEAD request to discover size and content type.
class DirectFileExtractor implements Extractor {
  DirectFileExtractor(this._dio);
  final Dio _dio;

  @override
  bool canHandle(String url) =>
      PlatformDetector.detect(url) == MediaSource.directFile;

  @override
  Future<MediaInfo> resolve(String url) async {
    final uri = Uri.parse(url);
    final name = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'download';
    final ext = name.contains('.') ? name.split('.').last : 'mp4';

    int? size;
    bool isAudio = false;
    try {
      final res = await _dio.head<void>(url);
      final len = res.headers.value('content-length');
      size = len != null ? int.tryParse(len) : null;
      final type = res.headers.value('content-type') ?? '';
      isAudio = type.startsWith('audio/');
    } catch (_) {
      // HEAD not supported by every server; fall back to unknown size.
    }

    return MediaInfo(
      sourceUrl: url,
      source: MediaSource.directFile,
      title: name,
      formats: [
        MediaFormat(
          url: url,
          kind: isAudio ? MediaKind.audio : MediaKind.muxed,
          container: ext,
          qualityLabel: isAudio ? 'Audio' : 'Original',
          sizeBytes: size,
          hasAudio: true,
          hasVideo: !isAudio,
        ),
      ],
    );
  }
}
