import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/database/storage_migration_runner.dart';
import 'package:vit_nextclass/core/database/storage_schema.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/models/semester.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

/// Simulates data written by an older VITneXt build (schema v0).
Future<void> _writeLegacyV0Data(Directory dir) async {
  await File('${dir.path}/${StorageSchema.semestersFile}').writeAsString(
    jsonEncode([
      {
        'id': 'fall2026',
        'semesterName': 'Fall Semester 2026',
        'isActive': true,
      },
    ]),
  );

  await File('${dir.path}/${StorageSchema.coursesFile}').writeAsString(
    jsonEncode([
      {
        'id': 'math',
        'semesterId': 'fall2026',
        'courseCode': 'MAT101',
        'courseName': 'Mathematics',
        'ffcsSlot': 'A14',
        'building': 'AB',
        'floor': '2',
        'room': '201',
      },
      {
        'id': 'physics',
        'semesterId': 'fall2026',
        'courseCode': 'PHY101',
        'courseName': 'Physics',
        'faculty': 'Dr. Rao',
        'slot': 'B15',
        'building': 'AB',
        'floor': '1',
        'room': '105',
      },
    ]),
  );

  await File('${dir.path}/${StorageSchema.holidaysFile}').writeAsString(
    jsonEncode([
      {
        'id': 'h1',
        'date': '2026-08-15T00:00:00.000',
        'holidayName': 'Independence Day',
        'holidayType': 'university',
      },
    ]),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;

  setUpAll(() async {
    testDir = await Directory.systemTemp.createTemp('vit_upgrade_test_');
    PathProviderPlatform.instance = _FakePathProvider(testDir.path);
  });

  tearDownAll(() async {
    LocalStorage().resetForTest();
    try {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    } catch (_) {
      // Temp dir may still be locked by AppLog on Windows.
    }
  });

  tearDown(() async {
    LocalStorage().resetForTest();
    SharedPreferences.setMockInitialValues({});
    for (final name in StorageSchema.dataFiles) {
      final file = File('${testDir.path}/$name');
      if (await file.exists()) await file.delete();
      final bak = File('${file.path}.bak');
      if (await bak.exists()) await bak.delete();
    }
  });

  group('upgrade migration smoke', () {
    test('v0 legacy files migrate and load after simulated app update', () async {
      SharedPreferences.setMockInitialValues({});
      await _writeLegacyV0Data(testDir);

      // First launch of the new app version — migration runs before reads.
      await StorageMigrationRunner.run(testDir);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(StorageSchema.prefsKey), StorageSchema.currentVersion);

      final storage = LocalStorage();
      await storage.init();

      final semester = await storage.getActiveSemester();
      expect(semester?.name, 'Fall Semester 2026');

      final courses = await storage.getCourses('fall2026');
      expect(courses.length, 2);

      final math = courses.firstWhere((c) => c.id == 'math');
      expect(math.name, 'Mathematics');
      expect(math.code, 'MAT101');
      expect(math.room, '201');
      expect(math.faculty, '');

      final physics = courses.firstWhere((c) => c.id == 'physics');
      expect(physics.name, 'Physics');
      expect(physics.ffcsSlot, 'B15');
      expect(physics.faculty, 'Dr. Rao');
      expect(physics.room, '105');

      final holidays = await storage.getAllHolidays();
      expect(holidays.length, 1);
      expect(holidays.first.label, 'Independence Day');
      expect(holidays.first.type, HolidayType.university);

      // Normalized on disk — current field names present.
      final coursesOnDisk = jsonDecode(
        await File('${testDir.path}/${StorageSchema.coursesFile}').readAsString(),
      ) as List;
      expect(coursesOnDisk.first['name'], 'Mathematics');
      expect(coursesOnDisk.first.containsKey('courseName'), isFalse);
    });

    test('migration is idempotent on second launch', () async {
      SharedPreferences.setMockInitialValues({});
      await _writeLegacyV0Data(testDir);

      await StorageMigrationRunner.run(testDir);
      final afterFirst = await File(
        '${testDir.path}/${StorageSchema.coursesFile}',
      ).readAsString();

      await StorageMigrationRunner.run(testDir);
      final afterSecond = await File(
        '${testDir.path}/${StorageSchema.coursesFile}',
      ).readAsString();

      expect(afterSecond, afterFirst);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(StorageSchema.prefsKey), StorageSchema.currentVersion);
    });

    test('LocalStorage.init runs migration for fresh installs with legacy data', () async {
      SharedPreferences.setMockInitialValues({});
      await _writeLegacyV0Data(testDir);

      final storage = LocalStorage();
      await storage.init();

      final courses = await storage.getActiveSemesterCourses();
      expect(courses.map((c) => c.name), contains('Mathematics'));
      expect(courses.map((c) => c.name), contains('Physics'));
    });

    test('already-migrated v1 data is not modified', () async {
      SharedPreferences.setMockInitialValues({
        StorageSchema.prefsKey: StorageSchema.currentVersion,
      });

      final semester = Semester(id: 's1', name: 'Sem', isActive: true);
      final course = Course(
        id: 'c1',
        semesterId: 's1',
        code: 'CSE101',
        name: 'Prog',
        faculty: 'F',
        ffcsSlot: 'A14',
        building: 'AB',
        floor: '1',
        room: '101',
      );

      final storage = LocalStorage();
      await storage.saveSemester(semester);
      await storage.saveCourse(course);

      final before = await File(
        '${testDir.path}/${StorageSchema.coursesFile}',
      ).readAsString();

      await StorageMigrationRunner.run(testDir);

      final after = await File(
        '${testDir.path}/${StorageSchema.coursesFile}',
      ).readAsString();
      expect(after, before);

      final loaded = await storage.getCourses('s1');
      expect(loaded.single.code, 'CSE101');
    });

    test('export after migration roundtrips through import', () async {
      SharedPreferences.setMockInitialValues({});
      await _writeLegacyV0Data(testDir);

      final storage = LocalStorage();
      await storage.init();

      final exported = await storage.exportAll();
      await storage.resetAll();
      expect(await storage.getSemesters(), isEmpty);

      await storage.importAll(exported);

      final courses = await storage.getCourses('fall2026');
      expect(courses.length, 2);
      expect(courses.any((c) => c.name == 'Mathematics'), isTrue);
      expect(courses.any((c) => c.name == 'Physics'), isTrue);
    });
  });
}
