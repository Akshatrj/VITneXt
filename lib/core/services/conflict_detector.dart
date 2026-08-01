import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/constants/ffcs_slots.dart';

class ConflictDetector {

  static bool _timesOverlap(int startMinA, int endMinA, int startMinB, int endMinB) {
    return startMinA < endMinB && endMinA > startMinB;
  }

  static List<String> checkCourseConflicts({
    required String newSlotCombo,
    required List<Course> existingCourses,
    String? excludeCourseId,
  }) {
    List<String> conflicts = [];

    for (int day = 1; day <= 7; day++) {
      final newTimings = FFCSSlotDatabase.getTimingsForDay(newSlotCombo, day);
      if (newTimings.isEmpty) continue;

      for (var existingCourse in existingCourses) {
        if (existingCourse.id == excludeCourseId) continue;

        final existingTimings = FFCSSlotDatabase.getTimingsForDay(existingCourse.ffcsSlot, day);
        if (existingTimings.isEmpty) continue;

        for (var newT in newTimings) {
          for (var existT in existingTimings) {
            if (_timesOverlap(
              newT.startTotalMinutes, newT.endTotalMinutes,
              existT.startTotalMinutes, existT.endTotalMinutes,
            )) {
              final name = '${existingCourse.code} - ${existingCourse.name}';
              if (!conflicts.contains(name)) {
                conflicts.add(name);
              }
            }
          }
        }
      }
    }

    return conflicts;
  }

  static Future<List<String>> checkOverrideConflicts({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required DateTime date,
    required List<ResolvedClass> existingSchedule,
    String? excludeOverrideId,
  }) async {
    List<String> conflicts = [];

    final newStart = startHour * 60 + startMinute;
    final newEnd = endHour * 60 + endMinute;

    for (var cls in existingSchedule) {
      if (cls.status == ClassStatus.cancelled) continue;

      final clsStart = cls.startHour * 60 + cls.startMinute;
      final clsEnd = cls.endHour * 60 + cls.endMinute;

      if (_timesOverlap(newStart, newEnd, clsStart, clsEnd)) {
        final name = '${cls.courseCode} - ${cls.courseName}';
        if (!conflicts.contains(name)) {
          conflicts.add(name);
        }
      }
    }

    return conflicts;
  }
}
