/// A downloadable subtitle / closed-caption track.
class SubtitleTrack {
  const SubtitleTrack({
    required this.label,
    required this.url,
    this.ext = 'vtt',
  });

  final String label;
  final String url;
  final String ext;
}
