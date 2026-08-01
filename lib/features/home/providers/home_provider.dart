import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/class_live_sync.dart';
import 'package:vit_nextclass/core/services/notification_scheduler.dart';
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
  final resolver = ref.read(scheduleResolverProvider);
  final schedule = await resolver.resolveSchedule(date);

  // Update widget when today's schedule is loaded
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    ResolvedClass? current;
    ResolvedClass? next;
    for (var cls in schedule) {
      if (cls.status == ClassStatus.current) current = cls;
      if (cls.status == ClassStatus.next) next = cls;
    }
    WidgetBridge.updateWidget(currentClass: current, nextClass: next);
  }

  return schedule;
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
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final schedule = await resolver.resolveSchedule(tomorrow);
  if (schedule.isNotEmpty) {
    return schedule.first;
  }
  return null;
});

// Helper to get tomorrow's holiday
final tomorrowHolidayProvider = FutureProvider<Holiday?>((ref) async {
  final resolver = ref.read(scheduleResolverProvider);
  final tomorrow = DateTime.now().add(const Duration(days: 1));
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
Future<void> refreshWidgetSchedule(WidgetRef ref) async {
  final resolver = ref.read(scheduleResolverProvider);
  final schedule = await resolver.resolveSchedule(DateTime.now());
  ResolvedClass? current;
  ResolvedClass? next;
  for (final cls in schedule) {
    if (cls.status == ClassStatus.current) current = cls;
    if (cls.status == ClassStatus.next) next = cls;
  }
  await WidgetBridge.updateWidget(currentClass: current, nextClass: next);
  await rescheduleClassNotifications(ref);
  invalidateClassLiveMonitorSync();
  await syncClassLiveMonitor(ref);
}
