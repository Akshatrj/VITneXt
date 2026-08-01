import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/models/holiday.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  bool _initialized = false;
  late Directory _dir;

  Future<void> init() async {
    if (_initialized) return;
    _dir = await getApplicationDocumentsDirectory();
    _initialized = true;
  }

  File get _semestersFile => File('${_dir.path}/semesters.json');
  File get _coursesFile => File('${_dir.path}/courses.json');
  File get _overridesFile => File('${_dir.path}/overrides.json');
  File get _holidaysFile => File('${_dir.path}/holidays.json');

  Future<List<T>> _readList<T>(File file, T Function(Map<String, dynamic>) fromJson) async {
    await init();
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _writeList<T>(File file, List<T> list, Map<String, dynamic> Function(T) toJson) async {
    await init();
    final jsonList = list.map((e) => toJson(e)).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  // --- Semester Methods ---
  Future<List<Semester>> getSemesters() async {
    return _readList(_semestersFile, Semester.fromJson);
  }

  Future<Semester?> getActiveSemester() async {
    final semesters = await getSemesters();
    for (var s in semesters) {
      if (s.isActive) return s;
    }
    return null;
  }

  Future<void> saveSemester(Semester semester) async {
    final semesters = await getSemesters();
    final index = semesters.indexWhere((s) => s.id == semester.id);
    if (index >= 0) {
      semesters[index] = semester;
    } else {
      semesters.add(semester);
    }
    await _writeList(_semestersFile, semesters, (s) => s.toJson());
  }

  Future<void> deleteSemester(String id) async {
    final semesters = await getSemesters();
    semesters.removeWhere((s) => s.id == id);
    await _writeList(_semestersFile, semesters, (s) => s.toJson());
  }

  Future<void> setActiveSemester(String id) async {
    final semesters = await getSemesters();
    for (int i = 0; i < semesters.length; i++) {
      if (semesters[i].id == id) {
        semesters[i] = semesters[i].copyWith(isActive: true);
      } else if (semesters[i].isActive) {
        semesters[i] = semesters[i].copyWith(isActive: false);
      }
    }
    await _writeList(_semestersFile, semesters, (s) => s.toJson());
  }

  // --- Course Methods ---
  Future<List<Course>> getCourses(String semesterId) async {
    final courses = await _readList(_coursesFile, Course.fromJson);
    return courses.where((c) => c.semesterId == semesterId).toList();
  }

  Future<List<Course>> getActiveSemesterCourses() async {
    final activeSem = await getActiveSemester();
    if (activeSem == null) return [];
    return getCourses(activeSem.id);
  }

  Future<void> saveCourse(Course course) async {
    final courses = await _readList(_coursesFile, Course.fromJson);
    final index = courses.indexWhere((c) => c.id == course.id);
    if (index >= 0) {
      courses[index] = course;
    } else {
      courses.add(course);
    }
    await _writeList(_coursesFile, courses, (c) => c.toJson());
  }

  Future<void> deleteCourse(String id) async {
    final courses = await _readList(_coursesFile, Course.fromJson);
    courses.removeWhere((c) => c.id == id);
    await _writeList(_coursesFile, courses, (c) => c.toJson());
  }

  // --- Override Methods ---
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<List<ScheduleOverride>> getOverridesForDate(DateTime date) async {
    final overrides = await getAllOverrides();
    return overrides.where((o) => _isSameDay(o.date, date)).toList();
  }

  Future<List<ScheduleOverride>> getAllOverrides() async {
    return _readList(_overridesFile, ScheduleOverride.fromJson);
  }

  Future<void> saveOverride(ScheduleOverride override_) async {
    final overrides = await getAllOverrides();
    final index = overrides.indexWhere((o) => o.id == override_.id);
    if (index >= 0) {
      overrides[index] = override_;
    } else {
      overrides.add(override_);
    }
    await _writeList(_overridesFile, overrides, (o) => o.toJson());
  }

  Future<void> deleteOverride(String id) async {
    final overrides = await getAllOverrides();
    overrides.removeWhere((o) => o.id == id);
    await _writeList(_overridesFile, overrides, (o) => o.toJson());
  }

  // --- Holiday Methods ---
  Future<Holiday?> getHolidayForDate(DateTime date) async {
    final holidays = await getAllHolidays();
    for (var h in holidays) {
      if (_isSameDay(h.date, date)) return h;
    }
    return null;
  }

  Future<List<Holiday>> getAllHolidays() async {
    return _readList(_holidaysFile, Holiday.fromJson);
  }

  Future<void> saveHoliday(Holiday holiday) async {
    final holidays = await getAllHolidays();
    final index = holidays.indexWhere((h) => h.id == holiday.id);
    if (index >= 0) {
      holidays[index] = holiday;
    } else {
      holidays.add(holiday);
    }
    await _writeList(_holidaysFile, holidays, (h) => h.toJson());
  }

  Future<void> deleteHoliday(String id) async {
    final holidays = await getAllHolidays();
    holidays.removeWhere((h) => h.id == id);
    await _writeList(_holidaysFile, holidays, (h) => h.toJson());
  }

  // --- Export/Import/Reset ---
  Future<Map<String, dynamic>> exportAll() async {
    final semesters = await getSemesters();
    final courses = await _readList(_coursesFile, Course.fromJson);
    final overrides = await getAllOverrides();
    final holidays = await getAllHolidays();

    return {
      'semesters': semesters.map((e) => e.toJson()).toList(),
      'courses': courses.map((e) => e.toJson()).toList(),
      'overrides': overrides.map((e) => e.toJson()).toList(),
      'holidays': holidays.map((e) => e.toJson()).toList(),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    await init();
    if (data.containsKey('semesters')) {
      final list = (data['semesters'] as List).map((e) => Semester.fromJson(e)).toList();
      await _writeList(_semestersFile, list, (e) => e.toJson());
    }
    if (data.containsKey('courses')) {
      final list = (data['courses'] as List).map((e) => Course.fromJson(e)).toList();
      await _writeList(_coursesFile, list, (e) => e.toJson());
    }
    if (data.containsKey('overrides')) {
      final list = (data['overrides'] as List).map((e) => ScheduleOverride.fromJson(e)).toList();
      await _writeList(_overridesFile, list, (e) => e.toJson());
    }
    if (data.containsKey('holidays')) {
      final list = (data['holidays'] as List).map((e) => Holiday.fromJson(e)).toList();
      await _writeList(_holidaysFile, list, (e) => e.toJson());
    }
  }

  Future<void> resetAll() async {
    await init();
    if (await _semestersFile.exists()) await _semestersFile.delete();
    if (await _coursesFile.exists()) await _coursesFile.delete();
    if (await _overridesFile.exists()) await _overridesFile.delete();
    if (await _holidaysFile.exists()) await _holidaysFile.delete();
  }

  /// Deletes all courses and overrides linked to courses in [semesterId].
  Future<void> resetSemester(String semesterId) async {
    await init();
    final courses = await _readList(_coursesFile, Course.fromJson);
    final semesterCourseIds =
        courses.where((c) => c.semesterId == semesterId).map((c) => c.id).toSet();

    final keptCourses = courses.where((c) => c.semesterId != semesterId).toList();
    await _writeList(_coursesFile, keptCourses, (e) => e.toJson());

    final overrides = await getAllOverrides();
    final keptOverrides = overrides
        .where((o) => o.linkedCourseId == null || !semesterCourseIds.contains(o.linkedCourseId))
        .toList();
    await _writeList(_overridesFile, keptOverrides, (e) => e.toJson());
  }
}
