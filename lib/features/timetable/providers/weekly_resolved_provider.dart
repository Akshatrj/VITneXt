import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';

/// Resolved schedule for Mon–Sat of the current week (includes cancellations).
final weeklyResolvedProvider = FutureProvider<Map<int, List<ResolvedClass>>>((ref) async {
  final resolver = ref.read(scheduleResolverProvider);
  final now = DateTime.now();
  final monday = now.subtract(Duration(days: now.weekday - 1));

  final map = <int, List<ResolvedClass>>{};
  for (int i = 0; i < 6; i++) {
    final date = DateTime(monday.year, monday.month, monday.day + i);
    map[i + 1] = await resolver.resolveSchedule(date);
  }
  return map;
});

void invalidateWeeklySchedule(WidgetRef ref) {
  ref.invalidate(weeklyResolvedProvider);
}
