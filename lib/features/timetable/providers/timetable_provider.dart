import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/constants/ffcs_slots.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';

class DayClassEntry {
  final Course course;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  DayClassEntry({
    required this.course,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
  
  int get startTotalMinutes => startHour * 60 + startMinute;
  int get endTotalMinutes => endHour * 60 + endMinute;
}

final weeklyPatternProvider = FutureProvider<Map<int, List<DayClassEntry>>>((ref) async {
  final localStorage = ref.watch(localStorageProvider);
  final courses = await localStorage.getActiveSemesterCourses();
  
  Map<int, List<DayClassEntry>> weekSchedule = {
    1: [], 2: [], 3: [], 4: [], 5: [], 6: [] // Mon-Sat
  };

  for (final course in courses) {
    for (int day = 1; day <= 6; day++) {
      final timings = FFCSSlotDatabase.getTimingsForDay(course.ffcsSlot, day);
      for (final timing in timings) {
        weekSchedule[day]!.add(DayClassEntry(
          course: course,
          startHour: timing.startHour,
          startMinute: timing.startMinute,
          endHour: timing.endHour,
          endMinute: timing.endMinute,
        ));
      }
    }
  }

  // Sort by start time
  for (int day = 1; day <= 6; day++) {
    weekSchedule[day]!.sort((a, b) {
      return a.startTotalMinutes.compareTo(b.startTotalMinutes);
    });
  }

  return weekSchedule;
});
