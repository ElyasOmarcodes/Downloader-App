import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'platform_detector.dart';

/// Listens for links shared into the app from other apps (share sheet) and
/// re-emits the detected URLs.
class ShareService {
  ShareService._();
  static final ShareService instance = ShareService._();

  final StreamController<String> _urls = StreamController<String>.broadcast();
  Stream<String> get sharedUrls => _urls.stream;

  StreamSubscription<List<SharedMediaFile>>? _sub;

  Future<void> init() async {
    // Link the app was cold-launched with.
    try {
      final initial =
          await ReceiveSharingIntent.instance.getInitialMedia();
      _emit(initial);
    } catch (_) {}

    // Links shared while the app is already running.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _emit,
      onError: (_) {},
    );
  }

  void _emit(List<SharedMediaFile> files) {
    for (final f in files) {
      final candidate = PlatformDetector.extractUrl(f.path) ??
          (f.path.startsWith('http') ? f.path : null);
      if (candidate != null) _urls.add(candidate);
    }
  }

  void dispose() {
    _sub?.cancel();
    _urls.close();
  }
}
