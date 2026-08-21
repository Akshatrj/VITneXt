import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vit_nextclass/core/database/storage_migration_runner.dart';
import 'package:vit_nextclass/core/database/storage_schema.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/services/app_log.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  bool _initialized = false;
  late Directory _dir;

  Future<void> init() async {
    if (_initialized) return;
    _dir = await getApplicationDocumentsDirectory();
    await StorageMigrationRunner.run(_dir);
    _initialized = true;
    AppLog.instance.info('db', 'LocalStorage initialized', data: {'path': _dir.path});
  }

  /// Clears in-memory init flag so tests can re-run [init] against a fresh directory.
  @visibleForTesting
  void resetForTest() {
    _initialized = false;
  }

  static const _semestersFileName = StorageSchema.semestersFile;
  static const _coursesFileName = StorageSchema.coursesFile;
  static const _overridesFileName = StorageSchema.overridesFile;
  static const _holidaysFileName = StorageSchema.holidaysFile;

  File _backupFile(File file) => File('${file.path}.bak');

  Future<List<T>> _readList<T>(String filename, T Function(Map<String, dynamic>) fromJson) async {
    await init();
    final file = File('${_dir.path}/$filename');
    if (!await file.exists()) return [];

    Future<List<T>> parseFile(File f) async {
      final content = await f.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }

    try {
      return await parseFile(file);
    } catch (e, st) {
      AppLog.instance.error('db', 'read failed', data: {'path': file.path}, error: e, stackTrace: st);
      final backup = _backupFile(file);
      if (await backup.exists()) {
        try {
          AppLog.instance.warn('db', 'restoring from backup', data: {'path': backup.path});
          return await parseFile(backup);
        } catch (backupError, backupSt) {
          AppLog.instance.error(
            'db',
            'backup read failed',
            data: {'path': backup.path},
            error: backupError,
            stackTrace: backupSt,
          );
        }
      }
      return [];
    }
  }

  Future<void> _writeList<T>(
    String filename,
    List<T> list,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    await init();
    final file = File('${_dir.path}/$filename');
    final jsonList = list.map((e) => toJson(e)).toList();
    final content = jsonEncode(jsonList);
    if (await file.exists()) {
      try {
        await file.copy(_backupFile(file).path);
      } catch (e, st) {
        AppLog.instance.error('db', 'backup copy failed', data: {'path': file.path}, error: e, stackTrace: st);
      }
    }
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(content);
    try {
      await tempFile.rename(file.path);
    } catch (e, st) {
      await file.writeAsString(content);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      AppLog.instance.error('db', 'atomic rename failed', data: {'path': file.path}, error: e, stackTrace: st);
    }
  }

  // --- Semester Methods ---
  Future<List<Semester>> getSemesters() async {
    return _readList(_semestersFileName, Semester.fromJson);
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
    await _writeList(_semestersFileName, semesters, (s) => s.toJson());
  }

  Future<void> deleteSemester(String id) async {
    await resetSemester(id);
    final semesters = await getSemesters();
    semesters.removeWhere((s) => s.id == id);
    await _writeList(_semestersFileName, semesters, (s) => s.toJson());
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
    await _writeList(_semestersFileName, semesters, (s) => s.toJson());
  }

  // --- Course Methods ---
  Future<List<Course>> getCourses(String semesterId) async {
    final courses = await _readList(_coursesFileName, Course.fromJson);
    return courses.where((c) => c.semesterId == semesterId).toList();
  }

  Future<List<Course>> getActiveSemesterCourses() async {
    final activeSem = await getActiveSemester();
    if (activeSem == null) return [];
    return getCourses(activeSem.id);
  }

  Future<void> saveCourse(Course course) async {
    final courses = await _readList(_coursesFileName, Course.fromJson);
    final index = courses.indexWhere((c) => c.id == course.id);
    if (index >= 0) {
      courses[index] = course;
    } else {
      courses.add(course);
    }
    await _writeList(_coursesFileName, courses, (c) => c.toJson());
  }

  Future<void> deleteCourse(String id) async {
    final courses = await _readList(_coursesFileName, Course.fromJson);
    courses.removeWhere((c) => c.id == id);
    await _writeList(_coursesFileName, courses, (c) => c.toJson());
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
    return _readList(_overridesFileName, ScheduleOverride.fromJson);
  }

  Future<void> saveOverride(ScheduleOverride override_) async {
    final overrides = await getAllOverrides();
    final index = overrides.indexWhere((o) => o.id == override_.id);
    if (index >= 0) {
      overrides[index] = override_;
    } else {
      overrides.add(override_);
    }
    await _writeList(_overridesFileName, overrides, (o) => o.toJson());
  }

  Future<void> deleteOverride(String id) async {
    final overrides = await getAllOverrides();
    overrides.removeWhere((o) => o.id == id);
    await _writeList(_overridesFileName, overrides, (o) => o.toJson());
  }

  // --- Holiday Methods ---
  Future<Holiday?> getHolidayForDate(DateTime date, {String? semesterId}) async {
    final holidays = await getHolidaysForSemester(semesterId);
    final matches = <Holiday>[];
    for (final h in holidays) {
      if (h.covers(date)) {
        matches.add(h);
        continue;
      }
      if (h.isRecurring) {
        final start = DateTime(date.year, h.startDate.month, h.startDate.day);
        final end = DateTime(date.year, h.endDate.month, h.endDate.day);
        if (!date.isBefore(start) && !date.isAfter(end)) {
          matches.add(h);
        }
      }
    }
    if (matches.isEmpty) return null;

    // Prefer events that hide classes, then exams, then earliest created.
    matches.sort((a, b) {
      final hideCmp = (b.hidesClasses ? 1 : 0).compareTo(a.hidesClasses ? 1 : 0);
      if (hideCmp != 0) return hideCmp;
      final examCmp = (b.isExam ? 1 : 0).compareTo(a.isExam ? 1 : 0);
      if (examCmp != 0) return examCmp;
      return a.createdAt.compareTo(b.createdAt);
    });
    return matches.first;
  }

  /// Removes semester-scoped holidays that cover [date] for the given semester (or active).
  /// Global holidays (null/empty [Holiday.semesterId]) are never removed here.
  Future<int> deleteHolidaysCoveringDate(DateTime date, {String? semesterId}) async {
    final all = await getAllHolidays();
    if (semesterId == null) {
      final active = await getActiveSemester();
      semesterId = active?.id;
    }
    if (semesterId == null) return 0;

    final before = all.length;
    all.removeWhere((h) {
      if (h.semesterId == null || h.semesterId!.isEmpty) return false;
      if (h.semesterId != semesterId) return false;
      if (h.covers(date)) return true;
      if (h.isRecurring) {
        final start = DateTime(date.year, h.startDate.month, h.startDate.day);
        final end = DateTime(date.year, h.endDate.month, h.endDate.day);
        return !date.isBefore(start) && !date.isAfter(end);
      }
      return false;
    });
    if (all.length == before) return 0;
    await _writeList(_holidaysFileName, all, (h) => h.toJson());
    return before - all.length;
  }

  Future<List<Holiday>> getAllHolidays() async {
    return _readList(_holidaysFileName, Holiday.fromJson);
  }

  Future<List<Holiday>> getHolidaysForSemester(String? semesterId) async {
    final all = await getAllHolidays();
    if (semesterId == null) {
      final active = await getActiveSemester();
      semesterId = active?.id;
    }
    return all.where((h) {
      if (h.semesterId == null || h.semesterId!.isEmpty) return true;
      return h.semesterId == semesterId;
    }).toList();
  }

  Future<void> saveHoliday(Holiday holiday) async {
    final holidays = await getAllHolidays();
    final index = holidays.indexWhere((h) => h.id == holiday.id);
    if (index >= 0) {
      holidays[index] = holiday;
    } else {
      // Duplicate detection by date range + name + type + semester
      final dupIndex = holidays.indexWhere((h) =>
          h.label == holiday.label &&
          h.type == holiday.type &&
          h.semesterId == holiday.semesterId &&
          _isSameDay(h.startDate, holiday.startDate) &&
          _isSameDay(h.endDate, holiday.endDate));
      if (dupIndex >= 0) {
        holidays[dupIndex] = holiday.copyWith(id: holidays[dupIndex].id);
      } else {
        holidays.add(holiday);
      }
    }
    await _writeList(_holidaysFileName, holidays, (h) => h.toJson());
  }

  Future<void> saveHolidays(List<Holiday> toSave, {bool replaceDuplicates = true}) async {
    final holidays = await getAllHolidays();
    for (final holiday in toSave) {
      final dupIndex = holidays.indexWhere((h) =>
          h.label == holiday.label &&
          h.type == holiday.type &&
          h.semesterId == holiday.semesterId &&
          _isSameDay(h.startDate, holiday.startDate) &&
          _isSameDay(h.endDate, holiday.endDate));
      if (dupIndex >= 0) {
        if (replaceDuplicates) {
          holidays[dupIndex] = holiday.copyWith(id: holidays[dupIndex].id);
        }
      } else {
        holidays.add(holiday);
      }
    }
    await _writeList(_holidaysFileName, holidays, (h) => h.toJson());
  }

  Future<void> deleteHoliday(String id) async {
    final holidays = await getAllHolidays();
    holidays.removeWhere((h) => h.id == id);
    await _writeList(_holidaysFileName, holidays, (h) => h.toJson());
  }

  Future<void> deleteHolidays(Iterable<String> ids) async {
    final idSet = ids.toSet();
    final holidays = await getAllHolidays();
    holidays.removeWhere((h) => idSet.contains(h.id));
    await _writeList(_holidaysFileName, holidays, (h) => h.toJson());
  }

  // --- Export/Import/Reset ---
  Future<Map<String, dynamic>> exportAll() async {
    final semesters = await getSemesters();
    final courses = await _readList(_coursesFileName, Course.fromJson);
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
    AppLog.instance.info('import', 'importAll begin', data: {
      'keys': data.keys.toList(),
    });

    List<Semester>? semesters;
    List<Course>? courses;
    List<ScheduleOverride>? overrides;
    List<Holiday>? holidays;

    try {
      if (data.containsKey('semesters')) {
        semesters = (data['semesters'] as List)
            .map((e) => Semester.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data.containsKey('courses')) {
        courses = (data['courses'] as List)
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data.containsKey('overrides')) {
        overrides = (data['overrides'] as List)
            .map((e) => ScheduleOverride.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data.containsKey('holidays')) {
        holidays = (data['holidays'] as List)
            .map((e) => Holiday.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e, st) {
      AppLog.instance.error('import', 'importAll parse failed', error: e, stackTrace: st);
      rethrow;
    }

    final backups = <String, File>{};
    Future<void> backupIfExists(String filename) async {
      final file = File('${_dir.path}/$filename');
      if (await file.exists()) {
        backups[filename] = file;
      }
    }

    try {
      if (semesters != null) await backupIfExists(_semestersFileName);
      if (courses != null) await backupIfExists(_coursesFileName);
      if (overrides != null) await backupIfExists(_overridesFileName);
      if (holidays != null) await backupIfExists(_holidaysFileName);

      if (semesters != null) {
        await _writeList(_semestersFileName, semesters, (e) => e.toJson());
      }
      if (courses != null) {
        await _writeList(_coursesFileName, courses, (e) => e.toJson());
      }
      if (overrides != null) {
        await _writeList(_overridesFileName, overrides, (e) => e.toJson());
      }
      if (holidays != null) {
        await _writeList(_holidaysFileName, holidays, (e) => e.toJson());
      }
      AppLog.instance.info('import', 'importAll success');
    } catch (e, st) {
      AppLog.instance.error('import', 'importAll failed, restoring backups', error: e, stackTrace: st);
      for (final entry in backups.entries) {
        final backup = _backupFile(entry.value);
        if (await backup.exists()) {
          try {
            await backup.copy(entry.value.path);
          } catch (_) {}
        }
      }
      rethrow;
    }
  }

  Future<void> resetAll() async {
    await init();
    for (final name in [
      _semestersFileName,
      _coursesFileName,
      _overridesFileName,
      _holidaysFileName,
    ]) {
      final file = File('${_dir.path}/$name');
      if (await file.exists()) await file.delete();
    }
  }

  /// Deletes all courses, linked overrides, and semester-scoped holidays for [semesterId].
  Future<void> resetSemester(String semesterId) async {
    await init();
    final courses = await _readList(_coursesFileName, Course.fromJson);
    final semesterCourseIds =
        courses.where((c) => c.semesterId == semesterId).map((c) => c.id).toSet();

    final keptCourses = courses.where((c) => c.semesterId != semesterId).toList();
    await _writeList(_coursesFileName, keptCourses, (e) => e.toJson());

    final overrides = await getAllOverrides();
    final keptOverrides = overrides
        .where((o) => o.linkedCourseId == null || !semesterCourseIds.contains(o.linkedCourseId))
        .toList();
    await _writeList(_overridesFileName, keptOverrides, (e) => e.toJson());

    final holidays = await getAllHolidays();
    await _writeList(
      _holidaysFileName,
      holidays.where((h) => h.semesterId != semesterId).toList(),
      (e) => e.toJson(),
    );
  }
}
