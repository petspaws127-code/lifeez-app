import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// System notifications for Lifeez: instant completion alerts and
/// scheduled reminder alerts. A failure here never crashes the app —
/// every call is guarded so notification errors stay silent.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'lifeez_reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Stable positive int ID from any string key.
  static int idFor(String key) => key.hashCode & 0x7fffffff;

  /// Initializes timezone data, the notification plugin, the reminders
  /// channel, and requests Android 13+ notification permission.
  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/New_York'));

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(settings);

      const channel = AndroidNotificationChannel(
        _channelId,
        'Reminders',
        description: 'Reminders and completion alerts from Lifeez.',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _initialized = true;
    } catch (_) {
      // Silent: notifications are best-effort.
    }
  }

  /// Shows a notification right away (high priority, default channel).
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      if (!_initialized) return;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.show(id, title, body, details);
    } catch (_) {
      // Silent.
    }
  }

  /// Schedules a notification for [when]. Does nothing when [when] is in
  /// the past.
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    try {
      if (!_initialized) return;
      if (!when.isAfter(DateTime.now())) return;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Silent.
    }
  }

  /// Cancels one scheduled or pending notification.
  Future<void> cancel(int id) async {
    try {
      if (!_initialized) return;
      await _plugin.cancel(id);
    } catch (_) {
      // Silent.
    }
  }

  /// Cancels all pending and active notifications.
  Future<void> cancelAll() async {
    try {
      if (!_initialized) return;
      await _plugin.cancelAll();
    } catch (_) {
      // Silent.
    }
  }
}
