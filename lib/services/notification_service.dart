import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around local notifications for download progress.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'downloads';
  static const _channelName = 'Downloads';

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> showProgress({
    required int id,
    required String title,
    required int progress,
    bool indeterminate = false,
  }) async {
    if (!_ready) return;
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows the progress of your downloads',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      indeterminate: indeterminate,
      ongoing: true,
    );
    await _plugin.show(
      id,
      title,
      indeterminate ? 'Starting…' : '$progress%',
      NotificationDetails(android: android),
    );
  }

  Future<void> showComplete({
    required int id,
    required String title,
  }) async {
    if (!_ready) return;
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    await _plugin.show(
      id,
      'Download complete',
      title,
      const NotificationDetails(android: android),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
