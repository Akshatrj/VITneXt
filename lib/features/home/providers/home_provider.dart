import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/notification_scheduler.dart';
import 'package:vit_nextclass/core/services/class_live_sync.dart';
import 'package:vit_nextclass/core/services/widget_bridge.dart';
import 'package:vit_nextclass/features/timetable/providers/weekly_resolved_provider.dart';

/// Normalize to date-only key for schedule family providers (stable cache keys).
DateTime normalizeScheduleDate(DateTime date) =>
    DateTime(date.year, date.month, date.day);

// Selected date (for swipe navigation)
final selectedDateProvider = StateProvider<DateTime>(
  (ref) => normalizeScheduleDate(DateTime.now()),
);

// Resolved schedule for selected date
final dayScheduleProvider = FutureProvider.family<List<ResolvedClass>, DateTime>((ref, date) async {
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;

  // Re-resolve every minute for today so statuses (current/next/completed) stay fresh.
  if (isToday) {
    ref.watch(currentTimeProvider);
  }

  final resolver = ref.read(scheduleResolverProvider);
  return resolver.resolveSchedule(date, now: now);
});

// Holiday for selected date
final dayHolidayProvider = FutureProvider.family<Holiday?, DateTime>((ref, date) async {
  final resolver = ref.read(scheduleResolverProvider);
  return resolver.getHolidayForDate(date);
});

// Current time (auto-refreshing every minute)
final currentTimeProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
    yield DateTime.now();
  }
});

// Helper to get tomorrow's first class if no more classes today
final tomorrowFirstClassProvider = FutureProvider<ResolvedClass?>((ref) async {
  final resolver = ref.read(scheduleResolverProvider);
  final tomorrow = normalizeScheduleDate(DateTime.now().add(const Duration(days: 1)));
  final schedule = await resolver.resolveSchedule(tomorrow);
  for (final cls in schedule) {
    if (cls.status != ClassStatus.cancelled) return cls;
  }
  return null;
});

// Helper to get tomorrow's holiday
final tomorrowHolidayProvider = FutureProvider<Holiday?>((ref) async {
  final resolver = ref.read(scheduleResolverProvider);
  final tomorrow = normalizeScheduleDate(DateTime.now().add(const Duration(days: 1)));
  return resolver.getHolidayForDate(tomorrow);
});

/// Invalidate schedule providers for a given date (typically today after data changes).
void invalidateScheduleForDate(WidgetRef ref, DateTime date) {
  final key = normalizeScheduleDate(date);
  ref.invalidate(dayScheduleProvider(key));
  ref.invalidate(dayHolidayProvider(key));
  invalidateWeeklySchedule(ref);
}

/// Invalidate today's schedule after course/override/holiday mutations.
void invalidateTodaySchedule(WidgetRef ref) {
  invalidateScheduleForDate(ref, DateTime.now());
}

/// Push current/next class info to the Android home-screen widget.
///
/// [syncClassFocus] and [syncNotifications] should stay false for UI-only
/// refreshes (e.g. pull-to-refresh display) to avoid cancel/reschedule churn.
Future<void> refreshWidgetSchedule(
  dynamic ref, {
  bool syncClassFocus = true,
  bool syncNotifications = true,
}) async {
  try {
    final resolver = ref.read(scheduleResolverProvider);
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

    // Today only — never look ahead to tomorrow for the widget.
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
    if (syncClassFocus) {
      invalidateClassLiveMonitorSync();
      await syncClassLiveMonitor(ref);
    }
    if (syncNotifications) {
      await rescheduleClassNotifications(ref);
    }
  } catch (_) {
    // Never let widget/notification refresh crash the UI.
  }
}

/// Widget display refresh only — no Class Focus or notification reschedule.
Future<void> refreshWidgetDisplayOnly(dynamic ref) =>
    refreshWidgetSchedule(ref, syncClassFocus: false, syncNotifications: false);
