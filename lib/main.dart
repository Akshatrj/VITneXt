import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/app.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/crash_reporter.dart';
import 'package:vit_nextclass/core/services/notification_scheduler.dart';
import 'package:vit_nextclass/core/services/reliability_bridge.dart';
import 'package:vit_nextclass/core/services/schedule_resolver.dart';
import 'package:vit_nextclass/core/services/widget_bridge.dart';
import 'package:vit_nextclass/core/services/widget_health_monitor.dart';

Future<void> _postLaunchMaintenance() async {
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
    await _refreshWidgetOnStartup().timeout(const Duration(seconds: 12));
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
    await ReliabilityBridge.scheduleWidgetHeal();
  } catch (e, st) {
    AppLog.instance.error('widget', 'schedule heal failed', error: e, stackTrace: st);
  }

  AppLog.instance.info('lifecycle', 'postLaunchMaintenance end');
}

Future<void> _refreshWidgetOnStartup() async {
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    await AppLog.instance.init();
    await CrashReporter.instance.init();
    AppLog.instance.info('lifecycle', 'main() start');

    runApp(const ProviderScope(child: VITNextClassApp()));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_postLaunchMaintenance());
    });
  }, (error, stack) {
    unawaited(CrashReporter.instance.recordError(error, stack, fatal: true, reason: 'zone'));
  });
}
