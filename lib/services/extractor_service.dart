import 'package:dio/dio.dart';

import '../models/media_info.dart';
import '../models/media_source.dart';
import 'extractors/direct_file_extractor.dart';
import 'extractors/extractor.dart';
import 'extractors/generic_extractor.dart';
import 'extractors/youtube_extractor.dart';
import 'platform_detector.dart';

/// Central entry point that routes a URL to the right [Extractor].
///
/// Platforms without a first-class extractor (Facebook, Instagram, TikTok,
/// ...) throw a descriptive [ExtractionException]. They are best resolved via
/// a server-side resolver endpoint (see [resolverEndpoint]) because their
/// signed stream URLs change frequently and often require session cookies —
/// doing that on-device is brittle and violates several platforms' ToS.
class ExtractorService {
  ExtractorService({Dio? dio}) : _dio = dio ?? Dio() {
    _extractors = [
      YoutubeExtractor(),
      DirectFileExtractor(_dio),
      GenericExtractor(_dio),
    ];
  }

  final Dio _dio;
  late final List<Extractor> _extractors;

  /// Optionally point this at your own resolver micro-service to enable
  /// Facebook / Instagram / TikTok / Twitter / Vimeo. See README.
  String? resolverEndpoint;

  Future<MediaInfo> resolve(String url) async {
    final cleanUrl = url.trim();
    for (final ex in _extractors) {
      if (ex.canHandle(cleanUrl)) return ex.resolve(cleanUrl);
    }

    final source = PlatformDetector.detect(cleanUrl);
    if (source != MediaSource.unknown && resolverEndpoint != null) {
      return _resolveViaBackend(cleanUrl, source);
    }

    if (source == MediaSource.unknown) {
      throw ExtractionException(
          'Unrecognized link. Paste a full video URL.');
    }
    throw ExtractionException(
        '${source.label} needs a resolver backend. See README to enable it.');
  }

  /// Resolves via an external resolver service returning our JSON schema:
  /// `{ title, author, thumbnail, duration, formats: [ ... ] }`.
  Future<MediaInfo> _resolveViaBackend(String url, MediaSource source) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        resolverEndpoint!,
        data: {'url': url},
      );
      final data = res.data!;
      return MediaInfo(
        sourceUrl: url,
        source: source,
        title: data['title'] as String? ?? 'Video',
        author: data['author'] as String?,
        thumbnailUrl: data['thumbnail'] as String?,
        durationSeconds: data['duration'] as int?,
        formats: [], // Populate from data['formats'] per your backend schema.
      );
    } catch (e) {
      throw ExtractionException('Resolver failed for ${source.label}: $e');
    }
  }

  void dispose() {
    for (final ex in _extractors) {
      ex.dispose();
    }
  }
}
