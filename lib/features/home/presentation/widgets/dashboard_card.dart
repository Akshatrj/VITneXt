import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/theme/app_colors.dart';
import 'package:vit_nextclass/widgets/cancel_class_sheet.dart';

class DashboardCard extends ConsumerWidget {
  final List<ResolvedClass> schedule;
  final DateTime currentTime;
  final DateTime scheduleDate;
  final ResolvedClass? tomorrowFirstClass;
  final Holiday? tomorrowHoliday;

  const DashboardCard({
    super.key,
    required this.schedule,
    required this.currentTime,
    required this.scheduleDate,
    this.tomorrowFirstClass,
    this.tomorrowHoliday,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find states based on current time
    ResolvedClass? currentClass;
    ResolvedClass? nextClass;
    ResolvedClass? recentlyCancelled;

    for (var cls in schedule) {
      if (cls.isCurrentlyRunning(currentTime)) {
        if (cls.status == ClassStatus.cancelled) {
          recentlyCancelled = cls;
        } else {
          currentClass = cls;
        }
      } else if (cls.isUpcoming(currentTime) && nextClass == null) {
        if (cls.status != ClassStatus.cancelled) {
          nextClass = cls;
        }
      }
    }

    // Fallback if no classes are running but we have an upcoming cancelled class
    if (currentClass == null && recentlyCancelled == null && nextClass == null) {
      // Just check if any class was cancelled today
      try {
        recentlyCancelled = schedule.firstWhere((c) => c.status == ClassStatus.cancelled && c.isUpcoming(currentTime));
      } catch (_) {}
    }

    if (currentClass != null) {
      return _buildCurrentClassCard(context, ref, currentClass);
    } else if (recentlyCancelled != null && nextClass != null) {
      return _buildCancelledCard(context, ref, recentlyCancelled, nextClass);
    } else if (nextClass != null) {
      return _buildNextClassCard(context, ref, nextClass);
    } else {
      return _buildNoMoreClassesCard(context);
    }
  }

  Widget _buildCurrentClassCard(BuildContext context, WidgetRef ref, ResolvedClass cls) {
    final theme = Theme.of(context);
    final minsLeft = cls.minutesUntilEnd(currentTime);

    return _buildBaseCard(
      context: context,
      building: cls.building,
      onTap: cls.linkedCourseId != null
          ? () => showClassActionSheet(context, ref, cls, scheduleDate)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CURRENT CLASS', style: _headerStyle(theme)),
              if (cls.isOverride)
                Text('[Today only]', style: _headerStyle(theme)),
            ],
          ),
          const SizedBox(height: 16),
          Text(cls.courseCode, style: _titleStyle(theme)),
          Text(cls.courseName, style: _subtitleStyle(theme)),
          const SizedBox(height: 8),
          Text('${cls.startTimeFormatted} – ${cls.endTimeFormatted}', style: _timeStyle(theme)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('📍 ${cls.classroomFull}', style: _locationStyle(theme)),
              ),
              Text('Ends in $minsLeft minutes', style: _timerStyle(theme)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextClassCard(BuildContext context, WidgetRef ref, ResolvedClass cls) {
    final theme = Theme.of(context);
    final minsUntil = cls.minutesUntilStart(currentTime);

    return _buildBaseCard(
      context: context,
      building: cls.building,
      onTap: cls.linkedCourseId != null
          ? () => showClassActionSheet(context, ref, cls, scheduleDate)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT CLASS', style: _headerStyle(theme)),
          const SizedBox(height: 16),
          Text(cls.courseCode, style: _titleStyle(theme)),
          Text(cls.courseName, style: _subtitleStyle(theme)),
          const SizedBox(height: 8),
          Text('${cls.startTimeFormatted} – ${cls.endTimeFormatted}', style: _timeStyle(theme)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('📍 ${cls.classroomFull}', style: _locationStyle(theme)),
              ),
              Text('Starts in $minsUntil minutes', style: _timerStyle(theme)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledCard(
    BuildContext context,
    WidgetRef ref,
    ResolvedClass cancelledCls,
    ResolvedClass nextCls,
  ) {
    final theme = Theme.of(context);

    return _buildBaseCard(
      context: context,
      building: 'CR',
      onTap: cancelledCls.linkedCourseId != null
          ? () => showClassActionSheet(context, ref, cancelledCls, scheduleDate)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${cancelledCls.courseCode} — Cancelled Today',
            style: _titleStyle(theme).copyWith(color: Colors.redAccent),
          ),
          if (cancelledCls.overrideReason != null) ...[
            const SizedBox(height: 4),
            Text(cancelledCls.overrideReason!, style: _subtitleStyle(theme)),
          ],
          const SizedBox(height: 8),
          Text(
            '${cancelledCls.courseName} was originally\nscheduled ${cancelledCls.startTimeFormatted} – ${cancelledCls.endTimeFormatted}',
            style: _subtitleStyle(theme),
          ),
          const SizedBox(height: 24),
          Text(
            'Next: ${nextCls.courseCode} at ${nextCls.startTimeFormatted}, ${nextCls.classroom}',
            style: _timeStyle(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMoreClassesCard(BuildContext context) {
    final theme = Theme.of(context);

    return _buildBaseCard(
      context: context,
      building: 'Other',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No More Classes Today 🎉', style: _titleStyle(theme)),
          const SizedBox(height: 24),
          if (tomorrowHoliday != null) ...[
            Text('Tomorrow is ${tomorrowHoliday!.label} 🎊 - No classes', style: _subtitleStyle(theme)),
          ] else if (tomorrowFirstClass != null) ...[
            Text("Tomorrow's First Class", style: _headerStyle(theme)),
            const SizedBox(height: 8),
            Text(
              '${tomorrowFirstClass!.courseCode} • ${tomorrowFirstClass!.startTimeFormatted} • ${tomorrowFirstClass!.classroom}',
              style: _subtitleStyle(theme).copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ] else ...[
            Text('No classes scheduled for tomorrow.', style: _subtitleStyle(theme)),
          ]
        ],
      ),
    );
  }

  Widget _buildBaseCard({
    required BuildContext context,
    required String building,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: AppColors.getBuildingGradient(building, context),
            boxShadow: [
              BoxShadow(
                color: AppColors.getBuildingColor(building, context).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // Styles
  TextStyle _headerStyle(ThemeData theme) => theme.textTheme.labelMedium!.copyWith(
    color: Colors.white.withValues(alpha: 0.8),
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );

  TextStyle _titleStyle(ThemeData theme) => theme.textTheme.headlineSmall!.copyWith(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );

  TextStyle _subtitleStyle(ThemeData theme) => theme.textTheme.titleMedium!.copyWith(
    color: Colors.white.withValues(alpha: 0.9),
  );

  TextStyle _timeStyle(ThemeData theme) => theme.textTheme.titleSmall!.copyWith(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  TextStyle _locationStyle(ThemeData theme) => theme.textTheme.titleSmall!.copyWith(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  TextStyle _timerStyle(ThemeData theme) => theme.textTheme.titleSmall!.copyWith(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  );
}
