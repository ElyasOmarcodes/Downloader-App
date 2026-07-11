import '../../models/media_info.dart';

/// Raised when a URL cannot be resolved to downloadable media.
class ExtractionException implements Exception {
  ExtractionException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Contract every platform resolver implements. This keeps the app
/// extensible: adding a new platform is a matter of implementing one class.
abstract class Extractor {
  /// Whether this extractor can handle [url].
  bool canHandle(String url);

  /// Resolves [url] into a [MediaInfo] with concrete downloadable formats.
  Future<MediaInfo> resolve(String url);

  /// Releases any long-lived resources (http clients, etc.).
  void dispose() {}
}
