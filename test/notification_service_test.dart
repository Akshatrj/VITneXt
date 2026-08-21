import 'package:flutter_test/flutter_test.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('notificationIdFor is stable and distinct per slot', () {
      final service = NotificationService.instance;
      final date = DateTime(2026, 8, 21);
      final clsA = ResolvedClass(
        courseCode: 'CSE1001',
        courseName: 'A',
        faculty: '',
        startHour: 8,
        startMinute: 0,
        endHour: 8,
        endMinute: 50,
        building: 'AB',
        floor: '1',
        room: '101',
        status: ClassStatus.upcoming,
        linkedCourseId: 'course-a',
      );
      final clsB = clsA.copyWith(
        startHour: 9,
        startMinute: 0,
        linkedCourseId: 'course-b',
      );

      final idA1 = service.notificationIdFor(date, clsA);
      final idA2 = service.notificationIdFor(date, clsA);
      final idB = service.notificationIdFor(date, clsB);

      expect(idA1, idA2);
      expect(idA1, isNot(idB));
      expect(idA1, greaterThan(0));
    });
  });
}
