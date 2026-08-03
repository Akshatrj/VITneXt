import 'package:flutter/material.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/theme/app_colors.dart';

class ClassCard extends StatelessWidget {
  final ResolvedClass cls;
  final VoidCallback? onTap;

  const ClassCard({
    Key? key,
    required this.cls,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCancelled = cls.status == ClassStatus.cancelled;
    final isCompleted = cls.status == ClassStatus.completed;
    final isCurrent = cls.status == ClassStatus.current;
    
    double opacity = 1.0;
    if (isCompleted || isCancelled) {
      opacity = 0.5;
    }

    return Container(
      width: 300,
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        elevation: isCurrent ? 8.0 : 2.0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Opacity(
            opacity: opacity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: AppColors.getBuildingGradient(cls.building, context),
                border: isCurrent
                    ? Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2)
                    : null,
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          cls.courseCode,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(context, theme),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cls.courseName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (isCancelled && cls.overrideReason != null) ...[
                    Text(
                      cls.overrideReason!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (cls.isOverride) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Today only',
                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (onTap != null && !isCompleted && cls.linkedCourseId != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tap to cancel or restore',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${cls.startTimeFormatted} – ${cls.endTimeFormatted}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('📍 ', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          cls.classroom,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, ThemeData theme) {
    String text = '';
    Color bgColor = Colors.transparent;
    IconData? icon;

    switch (cls.status) {
      case ClassStatus.current:
        text = 'NOW';
        bgColor = Colors.white;
        break;
      case ClassStatus.next:
        text = 'NEXT';
        bgColor = Colors.white.withValues(alpha: 0.3);
        break;
      case ClassStatus.cancelled:
        text = 'CANCELLED';
        bgColor = Colors.redAccent;
        break;
      case ClassStatus.completed:
        icon = Icons.check_circle;
        break;
      case ClassStatus.extra:
        text = 'EXTRA';
        bgColor = AppColors.ab02Purple;
        break;
      case ClassStatus.upcoming:
        return const SizedBox.shrink();
    }

    if (icon != null) {
      return Icon(icon, color: Colors.white, size: 24);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: cls.status == ClassStatus.current
              ? AppColors.getBuildingColor(cls.building, context)
              : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
