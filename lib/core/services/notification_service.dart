import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vit_nextclass/core/models/resolved_class.dart';

/// Schedules local notifications before upcoming classes.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Requests POST_NOTIFICATIONS on Android 13+. Returns true if granted (or not required).
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> hasPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited;
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  int _notificationId(DateTime date, ResolvedClass cls) {
    return date.year * 100000 +
        date.month * 10000 +
        date.day * 1000 +
        cls.startHour * 100 +
        cls.startMinute +
        cls.courseCode.hashCode % 100;
  }

  Future<void> rescheduleForWeek({
    required List<Future<List<ResolvedClass>>> dailySchedules,
    required List<DateTime> dates,
    required int minutesBefore,
  }) async {
    await init();
    await cancelAll();

    if (minutesBefore <= 0) return;

    // Don't schedule if the user hasn't granted notification permission.
    if (!await hasPermission()) return;

    final now = DateTime.now();

    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final schedule = await dailySchedules[i];

      for (final cls in schedule) {
        if (cls.status == ClassStatus.cancelled ||
            cls.status == ClassStatus.completed) {
          continue;
        }

        final classStart = DateTime(
          date.year,
          date.month,
          date.day,
          cls.startHour,
          cls.startMinute,
        );
        final notifyAt = classStart.subtract(Duration(minutes: minutesBefore));
        if (notifyAt.isBefore(now)) continue;

        final tzTime = tz.TZDateTime.from(notifyAt, tz.local);
        final id = _notificationId(date, cls);

        try {
          await _plugin.zonedSchedule(
            id,
            'Class starting soon',
            '${cls.courseCode} · ${cls.courseName} in $minutesBefore min · ${cls.classroom}',
            tzTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'class_reminders',
                'Class Reminders',
                channelDescription: 'Reminders before your FFCS classes',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {
          // Skip individual schedule failures (timezone / OEM quirks).
        }
      }
    }
  }
}
