import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/theme/app_colors.dart';
import 'package:vit_nextclass/widgets/cancel_class_sheet.dart';

class DayScheduleList extends ConsumerWidget {
  final List<ResolvedClass> classes;
  final DateTime date;

  const DayScheduleList({
    super.key,
    required this.classes,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No classes this day',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final cls = classes[index];
        final isCancelled = cls.status == ClassStatus.cancelled;
        final buildingColor = AppColors.getBuildingColor(cls.building, context);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    buildingColor.withValues(alpha: isCancelled ? 0.35 : 0.85),
                    buildingColor.withValues(alpha: isCancelled ? 0.2 : 0.55),
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
                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (isCancelled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'CANCELLED',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cls.courseName,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (isCancelled && cls.overrideReason != null) ...[
                      const SizedBox(height: 4),
                      Text(cls.overrideReason!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${cls.startTimeFormatted} - ${cls.endTimeFormatted}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          cls.classroomFull,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (cls.linkedCourseId != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tap to cancel or restore',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
