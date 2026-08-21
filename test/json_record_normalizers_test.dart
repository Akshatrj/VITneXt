import 'package:flutter_test/flutter_test.dart';
import 'package:vit_nextclass/core/database/json_record_normalizers.dart';

void main() {
  group('json_record_normalizers', () {
    test('normalizeCourseRecord maps legacy keys', () {
      final out = normalizeCourseRecord({
        'id': 'c1',
        'semesterId': 's1',
        'courseCode': 'MAT101',
        'courseName': 'Mathematics',
        'slot': 'A14',
        'room': '201',
      });

      expect(out, isNotNull);
      expect(out!['code'], 'MAT101');
      expect(out['name'], 'Mathematics');
      expect(out['ffcsSlot'], 'A14');
      expect(out['faculty'], '');
      expect(out['building'], '');
    });

    test('normalizeSemesterRecord maps semesterName', () {
      final out = normalizeSemesterRecord({
        'id': 's1',
        'semesterName': 'Fall 2026',
      });

      expect(out, isNotNull);
      expect(out!['name'], 'Fall 2026');
      expect(out['isActive'], isFalse);
    });

    test('normalizeHolidayRecord maps date and holidayName', () {
      final out = normalizeHolidayRecord({
        'id': 'h1',
        'date': '2026-08-15T00:00:00.000',
        'holidayName': 'Test Day',
        'holidayType': 'festival',
      });

      expect(out, isNotNull);
      expect(out!['label'], 'Test Day');
      expect(out['startDate'], '2026-08-15T00:00:00.000');
      expect(out['type'], 'festival');
    });

    test('normalizeCourseRecord rejects missing id', () {
      expect(
        normalizeCourseRecord({'semesterId': 's1', 'name': 'X'}),
        isNull,
      );
    });
  });
}
