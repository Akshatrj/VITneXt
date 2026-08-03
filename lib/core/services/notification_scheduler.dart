import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/notification_service.dart';
import 'package:vit_nextclass/core/services/schedule_resolver.dart';

/// Reschedules class reminder notifications for the next 7 days.
Future<void> rescheduleClassNotifications(dynamic ref) async {
  try {
    final minutes = ref.read(notificationMinutesProvider);
    final resolver = ref.read(scheduleResolverProvider);
    final now = DateTime.now();
    AppLog.instance.info('notifications', 'reschedule begin', data: {
      'minutesBefore': minutes,
    });

    final dates = List.generate(7, (i) => DateTime(now.year, now.month, now.day + i));
    final schedules = dates.map<Future<List<ResolvedClass>>>((d) => resolver.resolveSchedule(d)).toList();

    await NotificationService.instance.rescheduleForWeek(
      dailySchedules: schedules,
      dates: dates,
      minutesBefore: minutes,
    );
    AppLog.instance.info('notifications', 'reschedule done');
  } catch (e, st) {
    AppLog.instance.error('notifications', 'reschedule failed', error: e, stackTrace: st);
  }
}

/// Startup reschedule without Riverpod (called from main.dart).
Future<void> rescheduleClassNotificationsOnStartup() async {
  await NotificationService.instance.init();
  final prefs = await SharedPreferences.getInstance();
  final minutes = prefs.getInt('notification_minutes') ?? 0;
  AppLog.instance.info('notifications', 'startup schedule', data: {
    'minutesBefore': minutes,
  });
  if (minutes <= 0) return;

  final storage = LocalStorage();
  final resolver = ScheduleResolver(storage);
  final now = DateTime.now();
  final dates = List.generate(7, (i) => DateTime(now.year, now.month, now.day + i));
  final schedules = dates.map<Future<List<ResolvedClass>>>((d) => resolver.resolveSchedule(d)).toList();

  await NotificationService.instance.rescheduleForWeek(
    dailySchedules: schedules,
    dates: dates,
    minutesBefore: minutes,
  );
}
