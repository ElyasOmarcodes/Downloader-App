import '../models/media_source.dart';

/// Detects which platform a pasted URL belongs to.
class PlatformDetector {
  static final _patterns = <MediaSource, List<RegExp>>{
    MediaSource.youtube: [
      RegExp(r'(youtube\.com|youtu\.be|youtube-nocookie\.com)',
          caseSensitive: false),
    ],
    MediaSource.facebook: [
      RegExp(r'(facebook\.com|fb\.watch|fb\.com)', caseSensitive: false),
    ],
    MediaSource.instagram: [
      RegExp(r'instagram\.com', caseSensitive: false),
    ],
    MediaSource.tiktok: [
      RegExp(r'tiktok\.com', caseSensitive: false),
    ],
    MediaSource.twitter: [
      RegExp(r'(twitter\.com|x\.com|t\.co)', caseSensitive: false),
    ],
    MediaSource.vimeo: [
      RegExp(r'vimeo\.com', caseSensitive: false),
    ],
  };

  static final _directFile = RegExp(
    r'\.(mp4|m4v|mov|webm|mkv|avi|wmv|flv|3gp|ts|m3u8|mpd|'
    r'mp3|m4a|aac|wav|flac|ogg|opus|weba)(\?.*)?$',
    caseSensitive: false,
  );

  /// HLS playlists need segment-based downloading rather than a plain GET.
  static final _hls = RegExp(r'\.m3u8(\?.*)?$', caseSensitive: false);

  /// Whether [url] points to an HLS (`.m3u8`) stream.
  static bool isHls(String url) => _hls.hasMatch(url.trim());

  /// Returns the detected [MediaSource] for [rawUrl].
  static MediaSource detect(String rawUrl) {
    final url = rawUrl.trim();
    if (url.isEmpty) return MediaSource.unknown;

    for (final entry in _patterns.entries) {
      for (final re in entry.value) {
        if (re.hasMatch(url)) return entry.key;
      }
    }
    if (_directFile.hasMatch(url)) return MediaSource.directFile;
    return MediaSource.unknown;
  }

  /// Extracts the first http(s) URL found in arbitrary shared text
  /// (share sheets often include captions around the link).
  static String? extractUrl(String text) {
    final match =
        RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(text);
    return match?.group(0);
  }
}
