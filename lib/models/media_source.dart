/// Supported source platforms for link detection.
enum MediaSource {
  youtube,
  facebook,
  instagram,
  tiktok,
  twitter,
  vimeo,
  directFile,
  unknown,
}

extension MediaSourceX on MediaSource {
  String get label {
    switch (this) {
      case MediaSource.youtube:
        return 'YouTube';
      case MediaSource.facebook:
        return 'Facebook';
      case MediaSource.instagram:
        return 'Instagram';
      case MediaSource.tiktok:
        return 'TikTok';
      case MediaSource.twitter:
        return 'X / Twitter';
      case MediaSource.vimeo:
        return 'Vimeo';
      case MediaSource.directFile:
        return 'Direct link';
      case MediaSource.unknown:
        return 'Unknown';
    }
  }

  /// Whether the app will attempt to resolve this source. YouTube and direct
  /// files have first-class resolvers; the social platforms are resolved
  /// best-effort on-device by the generic extractor.
  bool get isSupported => this != MediaSource.unknown;

  /// True only for the fully-reliable, first-class resolvers.
  bool get isFirstClass =>
      this == MediaSource.youtube || this == MediaSource.directFile;
}
