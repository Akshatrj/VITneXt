import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';

class CalendarDayInfo {
  final int classCount;
  final int cancelledCount;
  final bool isHoliday;
  final bool hasOverride;

  CalendarDayInfo({
    required this.classCount,
    required this.cancelledCount,
    required this.isHoliday,
    required this.hasOverride,
  });
}

final selectedCalendarDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final calendarEventsProvider =
    FutureProvider.family<Map<DateTime, CalendarDayInfo>, DateTime>((ref, month) async {
  final resolver = ref.read(scheduleResolverProvider);
  final map = <DateTime, CalendarDayInfo>{};

  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

  for (int i = 1; i <= daysInMonth; i++) {
    final date = DateTime(month.year, month.month, i);
    final schedule = await resolver.resolveSchedule(date);
    final holiday = await resolver.getHolidayForDate(date);
    final isHoliday = holiday != null && holiday.hidesClasses;

    final cancelledCount =
        schedule.where((c) => c.status == ClassStatus.cancelled).length;
    final classCount =
        schedule.where((c) => c.status != ClassStatus.cancelled).length;
    final hasOverride = schedule.any((c) => c.isOverride);

    if (classCount > 0 || cancelledCount > 0 || isHoliday || hasOverride) {
      map[date] = CalendarDayInfo(
        classCount: classCount,
        cancelledCount: cancelledCount,
        isHoliday: isHoliday,
        hasOverride: hasOverride,
      );
    }
  }

  return map;
});

final selectedDateScheduleProvider =
    FutureProvider.family<List<ResolvedClass>, DateTime>((ref, date) async {
  final resolver = ref.read(scheduleResolverProvider);
  return resolver.resolveSchedule(date);
});
