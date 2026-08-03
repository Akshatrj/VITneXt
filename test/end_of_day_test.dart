import 'package:flutter_test/flutter_test.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/services/schedule_resolver.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';

class _TestStorage implements LocalStorage {
  Semester? activeSemester;
  List<Course> courses = [];
  List<ScheduleOverride> overrides = [];
  Holiday? holiday;

  @override
  Future<Semester?> getActiveSemester() async => activeSemester;

  @override
  Future<List<Course>> getActiveSemesterCourses() async => courses;

  @override
  Future<List<ScheduleOverride>> getOverridesForDate(DateTime date) async {
    return overrides
        .where((o) =>
            o.date.year == date.year &&
            o.date.month == date.month &&
            o.date.day == date.day)
        .toList();
  }

  @override
  Future<Holiday?> getHolidayForDate(DateTime date, {String? semesterId}) async =>
      holiday;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('End of day schedule', () {
    late _TestStorage storage;
    late ScheduleResolver resolver;
    // Monday 2026-08-03 — A14 has a morning theory slot.
    final monday = DateTime(2026, 8, 3);

    setUp(() {
      storage = _TestStorage();
      storage.activeSemester = Semester(id: 's1', name: 'Odd 2026', isActive: true);
      storage.courses = [
        Course(
          id: 'course-1',
          semesterId: 's1',
          code: 'CSE101',
          name: 'Programming',
          faculty: 'Dr. Smith',
          ffcsSlot: 'A14',
          building: 'AB',
          floor: '1',
          room: '101',
        ),
      ];
      resolver = ScheduleResolver(storage);
    });

    test('after last class ends there is no current or next class', () async {
      final lateEvening = DateTime(2026, 8, 3, 20, 0);
      final schedule = await resolver.resolveSchedule(monday, now: lateEvening);

      expect(schedule, isNotEmpty);
      expect(schedule.every((c) => c.status == ClassStatus.completed), isTrue);
      expect(schedule.any((c) => c.status == ClassStatus.current), isFalse);
      expect(schedule.any((c) => c.status == ClassStatus.next), isFalse);
    });

    test('live helpers agree nothing is running or upcoming after day ends', () async {
      final lateEvening = DateTime(2026, 8, 3, 20, 0);
      final schedule = await resolver.resolveSchedule(monday, now: lateEvening);

      final current = schedule.where((c) => c.isCurrentlyRunning(lateEvening)).toList();
      final upcoming = schedule
          .where((c) => c.isUpcoming(lateEvening) && c.status != ClassStatus.cancelled)
          .toList();

      expect(current, isEmpty);
      expect(upcoming, isEmpty);
    });

    test('mid-day still exposes a next class', () async {
      final morning = DateTime(2026, 8, 3, 7, 0);
      final schedule = await resolver.resolveSchedule(monday, now: morning);

      expect(schedule.any((c) => c.status == ClassStatus.next), isTrue);
      expect(schedule.any((c) => c.status == ClassStatus.completed), isFalse);
    });
  });
}
