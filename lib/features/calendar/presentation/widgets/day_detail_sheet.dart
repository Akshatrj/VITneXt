import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/features/calendar/providers/calendar_provider.dart';
import 'package:vit_nextclass/core/theme/app_colors.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/widgets/cancel_class_sheet.dart';
import 'package:intl/intl.dart';

class DayDetailSheet extends ConsumerWidget {
  final DateTime date;

  const DayDetailSheet({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(selectedDateScheduleProvider(date));
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(date);
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            dateStr,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: scheduleAsync.when(
              data: (classes) {
                if (classes.isEmpty) {
                  return FutureBuilder(
                    future: ref.read(scheduleResolverProvider).getHolidayForDate(date),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final holiday = snapshot.data;
                      if (holiday != null) {
                        final noClasses = holiday.hidesClasses;
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                holiday.isExam ? Icons.edit_note : Icons.celebration,
                                size: 64,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                holiday.label,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                noClasses
                                    ? (holiday.isExam
                                        ? 'Exam period — regular classes are off.'
                                        : "It's a holiday! No classes today.")
                                    : '${holiday.type.label} — classes may still run.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                      return const Center(child: Text('No classes scheduled for this day.'));
                    },
                  );
                }

                return ListView.builder(
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    final cls = classes[index];
                    final buildingColor = AppColors.getBuildingColor(cls.building, context);
                    final isCancelled = cls.status == ClassStatus.cancelled;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: cls.isOverride
                            ? BorderSide(color: theme.colorScheme.tertiary, width: 2)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        onTap: cls.linkedCourseId != null
                            ? () => showClassActionSheet(context, ref, cls, date)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                buildingColor.withValues(alpha: isCancelled ? 0.45 : 0.85),
                                buildingColor.withValues(alpha: isCancelled ? 0.25 : 0.55),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cls.courseCode,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          decoration: isCancelled
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    if (isCancelled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.error,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'CANCELLED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (cls.isOverride && !isCancelled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.tertiary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'OVERRIDE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${cls.startTimeFormatted} - ${cls.endTimeFormatted}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          decoration: isCancelled
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  cls.courseName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                if (cls.overrideReason != null && isCancelled) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    cls.overrideReason!,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      cls.classroom,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Something went wrong. Pull down to retry.')),
            ),
          ),
        ],
      ),
    );
  }
}
