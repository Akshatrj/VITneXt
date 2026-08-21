import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:vit_nextclass/core/models/resolved_class.dart';

/// Schedules local notifications before upcoming classes.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _scheduledIdsKey = 'scheduled_class_reminder_ids';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _localTimezoneConfigured = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> _configureLocalTimezone() async {
    if (_localTimezoneConfigured) return;
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // VIT Bhopal default; better than leaving tz.local at UTC.
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }
    _localTimezoneConfigured = true;
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

  /// Cancels only class-reminder notifications tracked by this service.
  Future<void> cancelClassReminders() async {
    try {
      await init();
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_scheduledIdsKey) ?? const [];
      for (final idStr in ids) {
        final id = int.tryParse(idStr);
        if (id != null) {
          await _plugin.cancel(id);
        }
      }
      await prefs.remove(_scheduledIdsKey);
    } catch (_) {}
  }

  @Deprecated('Use cancelClassReminders')
  Future<void> cancelAll() => cancelClassReminders();

  int notificationIdFor(DateTime date, ResolvedClass cls) {
    final linked = cls.linkedCourseId ?? cls.courseCode;
    final key =
        '${date.year}-${date.month}-${date.day}|$linked|${cls.startHour}:${cls.startMinute}';
    return key.hashCode & 0x7fffffff;
  }

  Future<void> _persistScheduledIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scheduledIdsKey,
      ids.map((id) => id.toString()).toList(),
    );
  }

  Future<void> rescheduleForWeek({
    required List<Future<List<ResolvedClass>>> dailySchedules,
    required List<DateTime> dates,
    required int minutesBefore,
  }) async {
    await init();
    await cancelClassReminders();

    if (minutesBefore <= 0) return;

    // Don't schedule if the user hasn't granted notification permission.
    if (!await hasPermission()) return;

    final now = DateTime.now();
    final scheduledIds = <int>[];

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
        if (!classStart.isAfter(now)) continue;

        final notifyAt = classStart.subtract(Duration(minutes: minutesBefore));
        final DateTime scheduleAt;
        final String body;
        if (notifyAt.isBefore(now)) {
          scheduleAt = now.add(const Duration(seconds: 30));
          body =
              '${cls.courseCode} · ${cls.courseName} starting soon · ${cls.classroom}';
        } else {
          scheduleAt = notifyAt;
          body =
              '${cls.courseCode} · ${cls.courseName} in $minutesBefore min · ${cls.classroom}';
        }

        final tzTime = tz.TZDateTime.from(scheduleAt, tz.local);
        final id = notificationIdFor(date, cls);

        try {
          await _plugin.zonedSchedule(
            id,
            'Class starting soon',
            body,
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
          scheduledIds.add(id);
        } catch (_) {
          // Skip individual schedule failures (timezone / OEM quirks).
        }
      }
    }

    await _persistScheduledIds(scheduledIds);
  }
}
