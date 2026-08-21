import 'dart:async';

import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/crash_reporter.dart';
import 'package:vit_nextclass/core/services/class_live_sync.dart';
import 'package:vit_nextclass/core/services/notification_scheduler.dart';
import 'package:vit_nextclass/core/services/reliability_bridge.dart';
import 'package:vit_nextclass/core/services/schedule_resolver.dart';
import 'package:vit_nextclass/core/services/widget_bridge.dart';
import 'package:vit_nextclass/core/services/widget_health_monitor.dart';

/// Startup / background maintenance: widget, notifications, class focus, heal alarms.
Future<void> runPostLaunchMaintenance() async {
  AppLog.instance.info('lifecycle', 'postLaunchMaintenance start');
  try {
    await LocalStorage().init().timeout(const Duration(seconds: 8));
    AppLog.instance.info('db', 'LocalStorage init OK');
  } catch (e, st) {
    AppLog.instance.error('db', 'LocalStorage init failed', error: e, stackTrace: st);
  }

  try {
    final sem = await LocalStorage().getActiveSemester();
    await CrashReporter.instance.setCustomKeys({
      'currentSemester': sem?.name ?? 'none',
      'currentSemesterId': sem?.id ?? 'none',
    });
  } catch (e, st) {
    AppLog.instance.error('db', 'semester key load failed', error: e, stackTrace: st);
  }

  try {
    await refreshWidgetOnStartup().timeout(const Duration(seconds: 12));
    await WidgetHealthMonitor.instance.markUpdateOk(detail: 'startup');
  } catch (e, st) {
    await WidgetHealthMonitor.instance.markUpdateFailed(e, st);
  }

  try {
    await rescheduleClassNotificationsOnStartup()
        .timeout(const Duration(seconds: 12));
    AppLog.instance.info('notifications', 'startup reschedule done');
  } catch (e, st) {
    AppLog.instance.error('notifications', 'startup reschedule failed', error: e, stackTrace: st);
  }

  try {
    await syncClassLiveMonitorOnStartup().timeout(const Duration(seconds: 12));
    AppLog.instance.info('class_focus', 'startup sync done');
  } catch (e, st) {
    AppLog.instance.error('class_focus', 'startup sync failed', error: e, stackTrace: st);
  }

  try {
    await ReliabilityBridge.scheduleWidgetHeal();
    await ReliabilityBridge.scheduleDayRollover();
  } catch (e, st) {
    AppLog.instance.error('widget', 'schedule heal/rollover failed', error: e, stackTrace: st);
  }

  AppLog.instance.info('lifecycle', 'postLaunchMaintenance end');
}

Future<void> refreshWidgetOnStartup() async {
  AppLog.instance.info('widget', 'startup refresh begin');
  final storage = LocalStorage();
  final resolver = ScheduleResolver(storage);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final holidayToday = await resolver.getHolidayForDate(today);
  final schedule = await resolver.resolveSchedule(now, now: now);

  ResolvedClass? current;
  ResolvedClass? next;

  for (final cls in schedule) {
    if (cls.status == ClassStatus.current) current = cls;
    if (cls.status == ClassStatus.next) next = cls;
  }

  final queue = <WidgetQueueEntry>[];
  for (final cls in schedule) {
    if (cls.status == ClassStatus.completed) continue;
    queue.add(WidgetQueueEntry(resolved: cls, scheduleDate: today));
  }

  final hidingHoliday = holidayToday != null && holidayToday.hidesClasses;
  final noClassesToday = !hidingHoliday && schedule.isEmpty;
  final dayComplete =
      !hidingHoliday && !noClassesToday && current == null && next == null;

  await WidgetBridge.updateWidget(
    currentClass: current,
    nextClass: next,
    holidayToday: holidayToday,
    upcomingQueue: queue,
    dayComplete: dayComplete,
    noClassesToday: noClassesToday,
  );
  AppLog.instance.info('widget', 'startup refresh done', data: {
    'queue': queue.length,
    'holiday': holidayToday?.label,
    'current': current?.courseCode,
    'next': next?.courseCode,
    'dayComplete': dayComplete,
    'noClassesToday': noClassesToday,
  });
}
