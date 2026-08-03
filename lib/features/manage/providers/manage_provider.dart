import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';

final coursesProvider = FutureProvider<List<Course>>((ref) async {
  final storage = ref.watch(localStorageProvider);
  return storage.getActiveSemesterCourses();
});

final overridesProvider = FutureProvider<List<ScheduleOverride>>((ref) async {
  final storage = ref.watch(localStorageProvider);
  final allOverrides = await storage.getAllOverrides();
  // Filter for upcoming or all? We'll return all for management
  allOverrides.sort((a, b) => b.date.compareTo(a.date));
  return allOverrides;
});

final holidaysProvider = FutureProvider<List<Holiday>>((ref) async {
  final storage = ref.watch(localStorageProvider);
  final active = await ref.watch(activeSemesterProvider.future);
  final holidays = await storage.getHolidaysForSemester(active?.id);
  holidays.sort((a, b) => b.startDate.compareTo(a.startDate));
  return holidays;
});
