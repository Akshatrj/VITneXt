import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';

final allSemestersProvider = FutureProvider.autoDispose<List<Semester>>((ref) async {
  final storage = ref.read(localStorageProvider);
  return await storage.getSemesters();
});
