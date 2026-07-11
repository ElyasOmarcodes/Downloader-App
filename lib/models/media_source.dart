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

  /// Whether a first-class extractor is implemented for this source.
  bool get isSupported =>
      this == MediaSource.youtube || this == MediaSource.directFile;
}
