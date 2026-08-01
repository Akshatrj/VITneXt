import 'package:flutter_test/flutter_test.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/services/schedule_resolver.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';

class _TestStorage implements LocalStorage {
  Semester? activeSemester;
  List<Course> courses = [];
  List<ScheduleOverride> overrides = [];

  @override
  Future<Semester?> getActiveSemester() async => activeSemester;

  @override
  Future<List<Course>> getActiveSemesterCourses() async => courses;

  @override
  Future<List<ScheduleOverride>> getOverridesForDate(DateTime date) async {
    return overrides.where((o) =>
        o.date.year == date.year &&
        o.date.month == date.month &&
        o.date.day == date.day).toList();
  }

  @override
  Future<Holiday?> getHolidayForDate(DateTime date) async => null;

  @override
  Future<void> saveOverride(ScheduleOverride override_) async {
    overrides.removeWhere((o) => o.id == override_.id);
    overrides.add(override_);
  }

  @override
  Future<void> deleteOverride(String id) async {
    overrides.removeWhere((o) => o.id == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Cancel class flow', () {
    late _TestStorage storage;
    late ScheduleResolver resolver;
    final monday = DateTime(2026, 8, 3); // Monday

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

    test('resolved schedule includes class on Monday before cancellation', () async {
      final schedule = await resolver.resolveSchedule(monday);
      expect(schedule.any((c) => c.courseCode == 'CSE101'), true);
      expect(schedule.any((c) => c.status == ClassStatus.cancelled), false);
    });

    test('cancellation override marks class as cancelled for that date', () async {
      await storage.saveOverride(ScheduleOverride(
        id: 'ov1',
        date: monday,
        type: OverrideType.cancelled,
        linkedCourseId: 'course-1',
        reason: 'Cancelled by teacher',
      ));

      final schedule = await resolver.resolveSchedule(monday);
      final cancelled = schedule.where((c) => c.courseCode == 'CSE101').toList();
      expect(cancelled.length, 1);
      expect(cancelled.first.status, ClassStatus.cancelled);
      expect(cancelled.first.overrideReason, 'Cancelled by teacher');
    });

    test('restoring cancellation brings class back to upcoming', () async {
      await storage.saveOverride(ScheduleOverride(
        id: 'ov1',
        date: monday,
        type: OverrideType.cancelled,
        linkedCourseId: 'course-1',
        reason: 'Cancelled by teacher',
      ));

      await storage.deleteOverride('ov1');

      final schedule = await resolver.resolveSchedule(monday);
      final cls = schedule.firstWhere((c) => c.courseCode == 'CSE101');
      expect(cls.status, isNot(ClassStatus.cancelled));
    });

    test('editing cancellation reason updates resolved class', () async {
      await storage.saveOverride(ScheduleOverride(
        id: 'ov1',
        date: monday,
        type: OverrideType.cancelled,
        linkedCourseId: 'course-1',
        reason: 'Cancelled by teacher',
      ));

      await storage.saveOverride(ScheduleOverride(
        id: 'ov1',
        date: monday,
        type: OverrideType.cancelled,
        linkedCourseId: 'course-1',
        reason: 'Faculty on leave',
      ));

      final schedule = await resolver.resolveSchedule(monday);
      final cls = schedule.firstWhere((c) => c.courseCode == 'CSE101');
      expect(cls.overrideReason, 'Faculty on leave');
    });
  });
}
