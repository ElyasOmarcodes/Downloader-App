import 'package:dio/dio.dart';

import '../../models/media_format.dart';
import '../../models/media_info.dart';
import '../../models/media_source.dart';
import '../platform_detector.dart';
import 'extractor.dart';

/// Best-effort on-device resolver for the social platforms that don't have a
/// dedicated API client (Facebook, Instagram, TikTok, X/Twitter, Vimeo).
///
/// It fetches the page HTML with a browser User-Agent and mines it for a
/// direct media URL: Open Graph video tags, `<video>` sources, and the JSON
/// blobs these sites embed (`playAddr`, `contentUrl`, `progressive_url`, …).
///
/// This is inherently fragile — many of these platforms gate content behind
/// login or short-lived signed URLs — so when nothing is found it throws a
/// clear [ExtractionException] rather than failing silently.
class GenericExtractor implements Extractor {
  GenericExtractor(this._dio);
  final Dio _dio;

  /// Optional Cookie header captured from the in-app browser after login,
  /// letting the extractor fetch gated pages as the logged-in user.
  String? cookie;

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  static const _handledSources = {
    MediaSource.facebook,
    MediaSource.instagram,
    MediaSource.tiktok,
    MediaSource.twitter,
    MediaSource.vimeo,
  };

  @override
  bool canHandle(String url) =>
      _handledSources.contains(PlatformDetector.detect(url));

  @override
  Future<MediaInfo> resolve(String url) async {
    final source = PlatformDetector.detect(url);
    String html;
    try {
      final res = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          headers: {
            'User-Agent': _ua,
            'Accept-Language': 'en-US,en;q=0.9',
            if (cookie != null && cookie!.isNotEmpty) 'Cookie': cookie!,
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      html = res.data ?? '';
    } catch (e) {
      throw ExtractionException('Could not open ${source.label}: $e');
    }

    final videoUrls = _findVideoUrls(html);
    if (videoUrls.isEmpty) {
      throw ExtractionException(
        '${source.label} link could not be resolved on-device. It may require '
        'login, or the platform blocks direct extraction.',
      );
    }

    final title = _firstMeta(html, ['og:title', 'twitter:title']) ??
        source.label;
    final thumb = _firstMeta(html, ['og:image', 'twitter:image']);

    final formats = <MediaFormat>[
      for (final v in videoUrls)
        MediaFormat(
          url: v,
          kind: MediaKind.muxed,
          container: v.contains('.webm') ? 'webm' : 'mp4',
          qualityLabel: videoUrls.length > 1
              ? 'Option ${videoUrls.indexOf(v) + 1}'
              : 'Original',
          hasAudio: true,
          hasVideo: true,
        ),
    ];

    return MediaInfo(
      sourceUrl: url,
      source: source,
      title: _decode(title),
      thumbnailUrl: thumb,
      formats: formats,
    );
  }

  /// Collects unique candidate media URLs from a variety of embedding styles.
  List<String> _findVideoUrls(String html) {
    final found = <String>{};

    void addAll(Iterable<RegExpMatch> matches, int group) {
      for (final m in matches) {
        final raw = m.group(group);
        if (raw == null) continue;
        final u = _cleanUrl(raw);
        if (u.startsWith('http') &&
            (u.contains('.mp4') || u.contains('.webm') || u.contains('/video'))) {
          found.add(u);
        }
      }
    }

    // Open Graph / twitter player stream.
    for (final prop in ['og:video:secure_url', 'og:video:url', 'og:video',
        'twitter:player:stream']) {
      final v = _firstMeta(html, [prop]);
      if (v != null) found.add(_cleanUrl(v));
    }

    // <video src> and <source src>.
    addAll(RegExp(r'<(?:video|source)[^>]+src="([^"]+)"').allMatches(html), 1);

    // Common JSON keys used by TikTok / Facebook / Instagram / Vimeo.
    for (final key in [
      'playAddr',
      'downloadAddr',
      'contentUrl',
      'progressive_url',
      'browser_native_hd_url',
      'browser_native_sd_url',
      'video_url',
    ]) {
      addAll(RegExp('"$key":"([^"]+)"').allMatches(html), 1);
    }

    return found.where((u) => u.startsWith('http')).toList();
  }

  String? _firstMeta(String html, List<String> properties) {
    for (final p in properties) {
      final re = RegExp(
        '<meta[^>]+(?:property|name)="$p"[^>]+content="([^"]*)"',
        caseSensitive: false,
      );
      final m = re.firstMatch(html);
      if (m != null && (m.group(1)?.isNotEmpty ?? false)) return m.group(1);
    }
    return null;
  }

  String _cleanUrl(String raw) =>
      _decode(raw).replaceAll(r'\/', '/').replaceAll(r'&', '&');

  String _decode(String s) {
    try {
      return const HtmlUnescape().convert(s);
    } catch (_) {
      return s;
    }
  }

  @override
  void dispose() {}
}

/// Minimal HTML entity unescaper (avoids pulling in a dependency just for a
/// handful of entities that appear in og: tags).
class HtmlUnescape {
  const HtmlUnescape();
  String convert(String input) => input
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
