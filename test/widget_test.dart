import 'package:flutter_test/flutter_test.dart';

import 'package:media_grab/models/media_source.dart';
import 'package:media_grab/services/platform_detector.dart';

void main() {
  group('PlatformDetector', () {
    test('detects YouTube links', () {
      expect(PlatformDetector.detect('https://youtu.be/dQw4w9WgXcQ'),
          MediaSource.youtube);
      expect(
          PlatformDetector.detect(
              'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          MediaSource.youtube);
    });

    test('detects social platforms', () {
      expect(PlatformDetector.detect('https://www.tiktok.com/@a/video/1'),
          MediaSource.tiktok);
      expect(PlatformDetector.detect('https://www.instagram.com/reel/x/'),
          MediaSource.instagram);
      expect(PlatformDetector.detect('https://fb.watch/abc/'),
          MediaSource.facebook);
    });

    test('detects direct media files', () {
      expect(PlatformDetector.detect('https://cdn.site.com/clip.mp4'),
          MediaSource.directFile);
      expect(PlatformDetector.detect('https://cdn.site.com/song.mp3?token=1'),
          MediaSource.directFile);
    });

    test('returns unknown for non-media links', () {
      expect(PlatformDetector.detect('https://example.com/article'),
          MediaSource.unknown);
    });

    test('extracts a URL from shared caption text', () {
      const text = 'Check this out https://youtu.be/abc123 amazing!';
      expect(PlatformDetector.extractUrl(text), 'https://youtu.be/abc123');
    });
  });
}
