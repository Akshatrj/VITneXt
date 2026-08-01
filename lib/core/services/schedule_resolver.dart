import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/constants/ffcs_slots.dart';

class ScheduleResolver {
  final LocalStorage _storage;

  ScheduleResolver(this._storage);

  Future<List<ResolvedClass>> resolveSchedule(DateTime date, {DateTime? now}) async {
    now ??= DateTime.now();

    // 1 & 2. Get active semester
    final activeSemester = await _storage.getActiveSemester();
    if (activeSemester == null) return [];

    // 3. Check for holiday
    final holiday = await getHolidayForDate(date);
    if (holiday != null) return [];

    // 4. Get active semester courses
    final courses = await _storage.getActiveSemesterCourses();

    final int dayOfWeek = date.weekday; // 1=Mon, 7=Sun
    List<ResolvedClass> resolvedClasses = [];

    // 5 & 6. Recurring pattern: for each course, get its FFCS timings for this day
    for (var course in courses) {
      final timings = FFCSSlotDatabase.getTimingsForDay(course.ffcsSlot, dayOfWeek);
      for (var timing in timings) {
        resolvedClasses.add(
          ResolvedClass(
            courseCode: course.code,
            courseName: course.name,
            faculty: course.faculty,
            startHour: timing.startHour,
            startMinute: timing.startMinute,
            endHour: timing.endHour,
            endMinute: timing.endMinute,
            building: course.building,
            floor: course.floor,
            room: course.room,
            status: ClassStatus.upcoming,
            isOverride: false,
            linkedCourseId: course.id,
          ),
        );
      }
    }

    // 7. Get overrides for this date
    final overrides = await _storage.getOverridesForDate(date);

    // 8. Apply overrides
    for (var override_ in overrides) {
      if (override_.type == OverrideType.cancelled) {
        // Mark matching course entries as cancelled
        for (int i = 0; i < resolvedClasses.length; i++) {
          if (resolvedClasses[i].linkedCourseId == override_.linkedCourseId) {
            resolvedClasses[i] = resolvedClasses[i].copyWith(
              status: ClassStatus.cancelled,
              isOverride: true,
              overrideReason: override_.reason,
            );
          }
        }
      } else if (override_.type == OverrideType.modified) {
        // Replace matching course time/room with override values
        for (int i = 0; i < resolvedClasses.length; i++) {
          if (resolvedClasses[i].linkedCourseId == override_.linkedCourseId) {
            resolvedClasses[i] = resolvedClasses[i].copyWith(
              startHour: override_.overrideStartHour ?? resolvedClasses[i].startHour,
              startMinute: override_.overrideStartMinute ?? resolvedClasses[i].startMinute,
              endHour: override_.overrideEndHour ?? resolvedClasses[i].endHour,
              endMinute: override_.overrideEndMinute ?? resolvedClasses[i].endMinute,
              building: override_.overrideBuilding ?? resolvedClasses[i].building,
              floor: override_.overrideFloor ?? resolvedClasses[i].floor,
              room: override_.overrideRoom ?? resolvedClasses[i].room,
              isOverride: true,
              overrideReason: override_.reason,
            );
          }
        }
      } else if (override_.type == OverrideType.extra) {
        // Add new entry
        if (override_.overrideStartHour != null && override_.overrideEndHour != null) {
          resolvedClasses.add(
            ResolvedClass(
              courseCode: override_.extraCourseCode ?? '',
              courseName: override_.extraCourseName ?? 'Extra Class',
              faculty: override_.extraFaculty ?? '',
              startHour: override_.overrideStartHour!,
              startMinute: override_.overrideStartMinute ?? 0,
              endHour: override_.overrideEndHour!,
              endMinute: override_.overrideEndMinute ?? 0,
              building: override_.overrideBuilding ?? 'Other',
              floor: override_.overrideFloor ?? 'G',
              room: override_.overrideRoom ?? '',
              status: ClassStatus.extra,
              isOverride: true,
              overrideReason: override_.reason,
              linkedCourseId: override_.linkedCourseId,
            ),
          );
        }
      }
    }

    // 9. Sort by start time
    resolvedClasses.sort((a, b) {
      final aStart = a.startHour * 60 + a.startMinute;
      final bStart = b.startHour * 60 + b.startMinute;
      return aStart.compareTo(bStart);
    });

    // 10. Update statuses based on current time
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    if (isToday) {
      final nowMinutes = now.hour * 60 + now.minute;
      bool nextFound = false;

      for (int i = 0; i < resolvedClasses.length; i++) {
        var cls = resolvedClasses[i];
        if (cls.status == ClassStatus.cancelled) continue;

        final startMins = cls.startHour * 60 + cls.startMinute;
        final endMins = cls.endHour * 60 + cls.endMinute;

        if (endMins <= nowMinutes) {
          resolvedClasses[i] = cls.copyWith(status: ClassStatus.completed);
        } else if (startMins <= nowMinutes && nowMinutes < endMins) {
          resolvedClasses[i] = cls.copyWith(status: ClassStatus.current);
          nextFound = true;
        } else if (startMins > nowMinutes) {
          if (!nextFound) {
            resolvedClasses[i] = cls.copyWith(status: ClassStatus.next);
            nextFound = true;
          } else {
            resolvedClasses[i] = cls.copyWith(status: ClassStatus.upcoming);
          }
        }
      }
    } else if (date.isBefore(now) && !isToday) {
      for (int i = 0; i < resolvedClasses.length; i++) {
        if (resolvedClasses[i].status != ClassStatus.cancelled) {
          resolvedClasses[i] = resolvedClasses[i].copyWith(status: ClassStatus.completed);
        }
      }
    }
    // Future dates keep their existing status (upcoming/extra)

    return resolvedClasses;
  }

  Future<Holiday?> getHolidayForDate(DateTime date) async {
    return _storage.getHolidayForDate(date);
  }

  Future<List<ResolvedClass>> getTodaySchedule() async {
    return resolveSchedule(DateTime.now());
  }

  Future<ResolvedClass?> getCurrentClass() async {
    final schedule = await getTodaySchedule();
    for (var cls in schedule) {
      if (cls.status == ClassStatus.current) return cls;
    }
    return null;
  }

  Future<ResolvedClass?> getNextClass() async {
    final schedule = await getTodaySchedule();
    for (var cls in schedule) {
      if (cls.status == ClassStatus.next) return cls;
    }
    return null;
  }

  Future<ResolvedClass?> getTomorrowFirstClass() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final schedule = await resolveSchedule(tomorrow);
    for (var cls in schedule) {
      if (cls.status != ClassStatus.cancelled) return cls;
    }
    return null;
  }
}
