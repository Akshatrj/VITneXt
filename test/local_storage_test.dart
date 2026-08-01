import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/models/semester.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;

  setUpAll(() async {
    testDir = await Directory.systemTemp.createTemp('vit_nextclass_test_');
    PathProviderPlatform.instance = _FakePathProvider(testDir.path);
  });

  tearDownAll(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('LocalStorage integration', () {
    late LocalStorage storage;

    setUp(() async {
      storage = LocalStorage();
      await storage.resetAll();
    });

    test('saveSemester and getActiveSemester roundtrip', () async {
      final semester = Semester(id: 's1', name: 'Test Sem', isActive: true);
      await storage.saveSemester(semester);

      final active = await storage.getActiveSemester();
      expect(active?.id, 's1');
      expect(active?.name, 'Test Sem');
    });

    test('saveCourse persists and retrieves by semester', () async {
      await storage.saveSemester(Semester(id: 's1', name: 'Sem', isActive: true));
      await storage.saveCourse(Course(
        id: 'c1',
        semesterId: 's1',
        code: 'CSE101',
        name: 'Prog',
        faculty: 'F',
        ffcsSlot: 'A14',
        building: 'AB',
        floor: '1',
        room: '101',
      ));

      final courses = await storage.getCourses('s1');
      expect(courses.length, 1);
      expect(courses.first.code, 'CSE101');
    });

    test('resetSemester removes courses and linked overrides only for that semester', () async {
      await storage.saveSemester(Semester(id: 's1', name: 'Sem 1', isActive: true));
      await storage.saveSemester(Semester(id: 's2', name: 'Sem 2', isActive: false));
      await storage.saveCourse(Course(
        id: 'c1',
        semesterId: 's1',
        code: 'A',
        name: 'A',
        faculty: '',
        ffcsSlot: 'A14',
        building: 'AB',
        floor: '1',
        room: '101',
      ));
      await storage.saveCourse(Course(
        id: 'c2',
        semesterId: 's2',
        code: 'B',
        name: 'B',
        faculty: '',
        ffcsSlot: 'D11',
        building: 'LC',
        floor: '1',
        room: '102',
      ));
      await storage.saveOverride(ScheduleOverride(
        id: 'o1',
        date: DateTime(2026, 8, 3),
        type: OverrideType.cancelled,
        linkedCourseId: 'c1',
        reason: 'Test',
      ));
      await storage.saveOverride(ScheduleOverride(
        id: 'o2',
        date: DateTime(2026, 8, 4),
        type: OverrideType.cancelled,
        linkedCourseId: 'c2',
        reason: 'Test',
      ));

      await storage.resetSemester('s1');

      final s1Courses = await storage.getCourses('s1');
      final s2Courses = await storage.getCourses('s2');
      final overrides = await storage.getAllOverrides();

      expect(s1Courses, isEmpty);
      expect(s2Courses.length, 1);
      expect(overrides.any((o) => o.id == 'o1'), false);
      expect(overrides.any((o) => o.id == 'o2'), true);
    });

    test('resetAll clears all data files', () async {
      await storage.saveSemester(Semester(id: 's1', name: 'Sem', isActive: true));
      await storage.saveCourse(Course(
        id: 'c1',
        semesterId: 's1',
        code: 'X',
        name: 'X',
        faculty: '',
        ffcsSlot: 'A14',
        building: 'AB',
        floor: '1',
        room: '101',
      ));

      await storage.resetAll();

      expect(await storage.getSemesters(), isEmpty);
      expect(await storage.getActiveSemesterCourses(), isEmpty);
    });
  });
}
