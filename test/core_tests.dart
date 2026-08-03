import 'package:flutter_test/flutter_test.dart';
import 'package:vit_nextclass/core/constants/ffcs_grid.dart';
import 'package:vit_nextclass/core/constants/ffcs_slots.dart';
import 'package:vit_nextclass/core/services/schedule_resolver.dart';
import 'package:vit_nextclass/core/services/conflict_detector.dart';
import 'package:vit_nextclass/core/services/slot_parser.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';

class MockLocalStorage implements LocalStorage {
  Semester? activeSemester;
  List<Course> courses = [];
  List<ScheduleOverride> overrides = [];
  Holiday? holiday;

  @override
  Future<Semester?> getActiveSemester() async => activeSemester;

  @override
  Future<List<Course>> getActiveSemesterCourses() async => courses;

  @override
  Future<List<ScheduleOverride>> getOverridesForDate(DateTime date) async => overrides;

  @override
  Future<Holiday?> getHolidayForDate(DateTime date, {String? semesterId}) async => holiday;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('FFCSTheoryGrid', () {
    test('contains all 42 official grid cell IDs', () {
      expect(FFCSTheoryGrid.allCellIds.length, 42);
    });

    test('A14 is Monday 14:50-16:20', () {
      final cell = FFCSTheoryGrid.getCell('A14');
      expect(cell, isNotNull);
      expect(cell!.dayOfWeek, 1);
      expect(cell.startHour, 14);
      expect(cell.startMinute, 50);
      expect(cell.endHour, 16);
      expect(cell.endMinute, 20);
    });

    test('D11 is Tuesday 08:30-10:00', () {
      final cell = FFCSTheoryGrid.getCell('D11');
      expect(cell, isNotNull);
      expect(cell!.dayOfWeek, 2);
      expect(cell.startHour, 8);
      expect(cell.startMinute, 30);
    });

    test('D12 is Thursday 08:30-10:00', () {
      final cell = FFCSTheoryGrid.getCell('D12');
      expect(cell, isNotNull);
      expect(cell!.dayOfWeek, 4);
    });
  });

  group('SlotParser', () {
    test('join builds combo string from slot list', () {
      expect(SlotParser.join(['A14', 'D11', 'D12']), 'A14+D11+D12');
    });

    test('parse and join roundtrip', () {
      final combo = 'A14+D11+D12';
      expect(SlotParser.join(SlotParser.parse(combo)), combo);
    });
  });

  group('FFCSSlotDatabase grid combos', () {
    test('A14+D11+D12 resolves to three sessions on Mon/Tue/Thu', () {
      final combo = 'A14+D11+D12';
      final timings = FFCSSlotDatabase.getTimingsForCombo(combo);
      expect(timings.length, 3);

      final monday = FFCSSlotDatabase.getTimingsForDay(combo, 1);
      expect(monday.length, 1);
      expect(monday.first.startHour, 14);
      expect(monday.first.startMinute, 50);

      final tuesday = FFCSSlotDatabase.getTimingsForDay(combo, 2);
      expect(tuesday.length, 1);
      expect(tuesday.first.startHour, 8);
      expect(tuesday.first.startMinute, 30);

      final thursday = FFCSSlotDatabase.getTimingsForDay(combo, 4);
      expect(thursday.length, 1);
    });
  });

  group('FFCSSlotDatabase', () {
    test('getTimingsForDay returns correct Monday timings for A1+TA1', () {
      final timings = FFCSSlotDatabase.getTimingsForDay('A1+TA1', 1);
      expect(timings.isNotEmpty, true);
      expect(timings.first.startHour, 8);
      expect(timings.first.startMinute, 0);
      expect(timings.first.endHour, 8);
      expect(timings.first.endMinute, 50);
    });

    test('Each slot combo returns non-empty timings for at least one day', () {
      for (var combo in FFCSSlotDatabase.slotCombos) {
        bool hasTimings = false;
        for (int i = 1; i <= 7; i++) {
          if (FFCSSlotDatabase.getTimingsForDay(combo.name, i).isNotEmpty) {
            hasTimings = true;
            break;
          }
        }
        expect(hasTimings, true, reason: 'Combo \${combo.name} has no timings on any day.');
      }
    });

    test('Weekend days (6, 7) return empty for standard slots like A1+TA1', () {
      final saturdayTimings = FFCSSlotDatabase.getTimingsForDay('A1+TA1', 6);
      final sundayTimings = FFCSSlotDatabase.getTimingsForDay('A1+TA1', 7);
      expect(saturdayTimings.isEmpty, true);
      expect(sundayTimings.isEmpty, true);
    });
  });

  group('ScheduleResolver', () {
    late MockLocalStorage mockStorage;
    late ScheduleResolver resolver;

    setUp(() {
      mockStorage = MockLocalStorage();
      resolver = ScheduleResolver(mockStorage);
    });

    test('Classes are sorted by start time and status assigned correctly', () async {
      // 2026-07-27 is a Monday
      final now = DateTime(2026, 7, 27, 10, 15);
      mockStorage.activeSemester = Semester(id: 's1', name: 'Fall 2026', isActive: true);

      mockStorage.overrides = [
        ScheduleOverride(
          id: 'o1', type: OverrideType.extra,
          extraCourseCode: 'EXT1', extraCourseName: 'Extra', date: now,
          overrideStartHour: 8, overrideStartMinute: 0,
          overrideEndHour: 9, overrideEndMinute: 0,
        ),
        ScheduleOverride(
          id: 'o2', type: OverrideType.extra,
          extraCourseCode: 'EXT2', extraCourseName: 'Extra2', date: now,
          overrideStartHour: 10, overrideStartMinute: 0,
          overrideEndHour: 11, overrideEndMinute: 0,
        ),
        ScheduleOverride(
          id: 'o3', type: OverrideType.extra,
          extraCourseCode: 'EXT3', extraCourseName: 'Extra3', date: now,
          overrideStartHour: 12, overrideStartMinute: 0,
          overrideEndHour: 13, overrideEndMinute: 0,
        ),
        ScheduleOverride(
          id: 'o4', type: OverrideType.extra,
          extraCourseCode: 'EXT4', extraCourseName: 'Extra4', date: now,
          overrideStartHour: 14, overrideStartMinute: 0,
          overrideEndHour: 15, overrideEndMinute: 0,
        ),
      ];
      
      final schedule = await resolver.resolveSchedule(now, now: now);
      
      expect(schedule.length, 4);
      expect(schedule[0].startHour, 8);
      expect(schedule[1].startHour, 10);
      expect(schedule[2].startHour, 12);
      expect(schedule[3].startHour, 14);

      expect(schedule[0].status, ClassStatus.completed);
      expect(schedule[1].status, ClassStatus.current);
      expect(schedule[2].status, ClassStatus.upcoming);
      expect(schedule[3].status, ClassStatus.upcoming);
    });
  });

  group('ConflictDetector', () {
    test('Detects overlapping slot conflicts', () {
      final courses = [
        Course(id: '1', semesterId: 's1', code: 'C1', name: 'Course1', faculty: '', ffcsSlot: 'A1', building: '', floor: '', room: '')
      ];
      final conflicts = ConflictDetector.checkCourseConflicts(
        newSlotCombo: 'A11+A12+A13',
        existingCourses: courses,
      );
      expect(conflicts.length, 1);
      expect(conflicts.first, 'C1 - Course1');
    });

    test('Non-overlapping slots do not conflict', () {
      final courses = [
        Course(id: '1', semesterId: 's1', code: 'C1', name: 'Course1', faculty: '', ffcsSlot: 'A1', building: '', floor: '', room: '')
      ];
      final conflicts = ConflictDetector.checkCourseConflicts(
        newSlotCombo: 'B1', 
        existingCourses: courses,
      );
      expect(conflicts.isEmpty, true);
    });
  });

  group('ResolvedClass', () {
    final rc = ResolvedClass(
      courseCode: 'C1', courseName: 'Name', faculty: 'F1',
      startHour: 14, startMinute: 30, endHour: 15, endMinute: 20,
      building: 'AB', floor: '1', room: '101', status: ClassStatus.upcoming
    );

    test('copyWith preserves unchanged fields', () {
      final copy = rc.copyWith(status: ClassStatus.current);
      expect(copy.status, ClassStatus.current);
      expect(copy.courseCode, 'C1');
      expect(copy.startHour, 14);
    });

    test('startTimeFormatted and endTimeFormatted formatting', () {
      expect(rc.startTimeFormatted, '2:30 PM');
      expect(rc.endTimeFormatted, '3:20 PM');
      
      final rc2 = rc.copyWith(startHour: 9, startMinute: 5, endHour: 12, endMinute: 0);
      expect(rc2.startTimeFormatted, '9:05 AM');
      expect(rc2.endTimeFormatted, '12:00 PM');
      
      final rc3 = rc.copyWith(startHour: 0, startMinute: 15);
      expect(rc3.startTimeFormatted, '12:15 AM');
    });

    test('isCurrentlyRunning and isUpcoming', () {
      final before = DateTime(2026, 1, 1, 14, 0);
      final during = DateTime(2026, 1, 1, 15, 0);
      final after = DateTime(2026, 1, 1, 15, 30);

      expect(rc.isCurrentlyRunning(during), true);
      expect(rc.isCurrentlyRunning(before), false);
      expect(rc.isCurrentlyRunning(after), false);

      expect(rc.isUpcoming(before), true);
      expect(rc.isUpcoming(during), false);
      expect(rc.isUpcoming(after), false);
    });

    test('classroom getter', () {
      expect(rc.classroom, 'AB-1 101');

      final online = rc.copyWith(building: 'CR');
      expect(online.classroom, 'CR');

      final other = rc.copyWith(building: 'Other', room: 'Auditorium');
      expect(other.classroom, 'Auditorium');

      final ground = rc.copyWith(building: 'AB', floor: 'G', room: '102');
      expect(ground.classroom, 'AB-1 0102');
    });
  });

  group('Semester Model', () {
    final sem = Semester(id: 's1', name: 'Spring', isActive: false);

    test('copyWith', () {
      final copy = sem.copyWith(isActive: true);
      expect(copy.isActive, true);
      expect(copy.id, 's1');
      expect(copy.name, 'Spring');
    });

    test('fromJson and toJson roundtrip', () {
      final json = sem.toJson();
      final from = Semester.fromJson(json);
      expect(from.id, sem.id);
      expect(from.name, sem.name);
      expect(from.isActive, sem.isActive);
    });
  });

  group('Course Model', () {
    final course = Course(
      id: 'c1', semesterId: 's1', code: 'C1', name: 'Course1',
      faculty: 'F1', ffcsSlot: 'A1', building: 'CB', floor: '2', room: '201'
    );

    test('fromJson and toJson roundtrip', () {
      final json = course.toJson();
      final from = Course.fromJson(json);
      expect(from.id, course.id);
      expect(from.code, course.code);
      expect(from.room, course.room);
    });

    test('classroom getter', () {
      expect(course.classroom, 'CB 2201');
    });
  });
}
