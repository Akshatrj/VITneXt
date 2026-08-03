import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/theme/app_colors.dart';
import 'package:vit_nextclass/core/utils/time_utils.dart';
import 'package:vit_nextclass/widgets/cancel_class_sheet.dart';

class DashboardCard extends ConsumerWidget {
  final List<ResolvedClass> schedule;
  final DateTime currentTime;
  final DateTime scheduleDate;
  final ResolvedClass? tomorrowFirstClass;
  final Holiday? tomorrowHoliday;
  final Holiday? todayHoliday;

  const DashboardCard({
    super.key,
    required this.schedule,
    required this.currentTime,
    required this.scheduleDate,
    this.tomorrowFirstClass,
    this.tomorrowHoliday,
    this.todayHoliday,
  });

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = _isSameDay(scheduleDate, currentTime);
    final isTomorrow = _isSameDay(
      scheduleDate,
      DateTime(currentTime.year, currentTime.month, currentTime.day)
          .add(const Duration(days: 1)),
    );
    final isPastDay = scheduleDate.isBefore(
          DateTime(currentTime.year, currentTime.month, currentTime.day),
        ) &&
        !isToday;

    // Holiday with no classes for this day.
    if (schedule.isEmpty && todayHoliday != null && todayHoliday!.hidesClasses) {
      return _buildHolidayCard(context, todayHoliday!);
    }

    if (schedule.isEmpty) {
      return _buildNoClassesScheduledCard(context, isToday: isToday, isTomorrow: isTomorrow);
    }

    ResolvedClass? currentClass;
    ResolvedClass? nextClass;
    ResolvedClass? recentlyCancelled;

    if (isToday) {
      for (final cls in schedule) {
        // Never surface completed classes as current/next.
        if (cls.status == ClassStatus.completed) continue;

        if (cls.isCurrentlyRunning(currentTime)) {
          if (cls.status == ClassStatus.cancelled) {
            recentlyCancelled = cls;
          } else {
            currentClass = cls;
          }
        } else if (cls.isUpcoming(currentTime) &&
            nextClass == null &&
            cls.status != ClassStatus.cancelled) {
          nextClass = cls;
        }
      }
    } else if (isTomorrow) {
      // Tomorrow: show the first active class as "next", never compare against today's clock.
      for (final cls in schedule) {
        if (cls.status == ClassStatus.cancelled) continue;
        nextClass = cls;
        break;
      }
    } else if (isPastDay) {
      // Yesterday: day is over.
      currentClass = null;
      nextClass = null;
    }

    if (currentClass != null) {
      return _buildCurrentClassCard(context, ref, currentClass);
    }
    if (recentlyCancelled != null && nextClass != null) {
      return _buildCancelledCard(context, ref, recentlyCancelled, nextClass);
    }
    if (nextClass != null) {
      return _buildNextClassCard(context, ref, nextClass, isToday: isToday);
    }

    // All classes finished (or cancelled) for this day.
    AppLog.instance.info('home', 'Showing no-more-classes card', data: {
      'date': scheduleDate.toIso8601String(),
      'isToday': isToday,
      'count': schedule.length,
    });
    return _buildNoMoreClassesCard(context, isToday: isToday);
  }

  Widget _buildHolidayCard(BuildContext context, Holiday holiday) {
    final theme = Theme.of(context);
    return _buildBaseCard(
      context: context,
      building: 'Other',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            holiday.isExam ? 'EXAM DAY' : 'HOLIDAY',
            style: _headerStyle(theme),
          ),
          const SizedBox(height: 12),
          Text(holiday.label, style: _titleStyle(theme)),
          const SizedBox(height: 8),
          Text(
            holiday.isExam
                ? 'Good luck with your exams! No regular classes today.'
                : 'No classes today.',
            style: _subtitleStyle(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildNoClassesScheduledCard(
    BuildContext context, {
    required bool isToday,
    required bool isTomorrow,
  }) {
    final theme = Theme.of(context);
    final title = isToday
        ? 'No Classes Today'
        : isTomorrow
            ? 'No Classes Tomorrow'
            : 'No Classes';
    return _buildBaseCard(
      context: context,
      building: 'Other',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle(theme)),
          const SizedBox(height: 12),
          Text(
            'Nothing is scheduled for this day.',
            style: _subtitleStyle(theme),
          ),
          if (isToday) ...[
            const SizedBox(height: 20),
            if (tomorrowHoliday != null)
              Text(
                'Tomorrow is ${tomorrowHoliday!.label} — no classes',
                style: _subtitleStyle(theme),
              )
            else if (tomorrowFirstClass != null)
              Text(
                'Tomorrow: ${tomorrowFirstClass!.courseCode} at ${tomorrowFirstClass!.startTimeFormatted}',
                style: _subtitleStyle(theme),
              ),
          ],
        ],
      ),
    );
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
              if (cls.isOverride) Text('[Today only]', style: _headerStyle(theme)),
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
                child: Text('📍 ${cls.classroom}', style: _locationStyle(theme)),
              ),
              Text('Ends in ${TimeUtils.formatDuration(minsLeft)}', style: _timerStyle(theme)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextClassCard(
    BuildContext context,
    WidgetRef ref,
    ResolvedClass cls, {
    required bool isToday,
  }) {
    final theme = Theme.of(context);
    final minsUntil = isToday ? cls.minutesUntilStart(currentTime) : null;

    return _buildBaseCard(
      context: context,
      building: cls.building,
      onTap: cls.linkedCourseId != null
          ? () => showClassActionSheet(context, ref, cls, scheduleDate)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isToday ? 'NEXT CLASS' : 'FIRST CLASS', style: _headerStyle(theme)),
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
                child: Text('📍 ${cls.classroom}', style: _locationStyle(theme)),
              ),
              if (minsUntil != null)
                Text(
                  'Starts in ${TimeUtils.formatDuration(minsUntil)}',
                  style: _timerStyle(theme),
                ),
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

  Widget _buildNoMoreClassesCard(BuildContext context, {required bool isToday}) {
    final theme = Theme.of(context);

    return _buildBaseCard(
      context: context,
      building: 'Other',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isToday ? 'No More Classes Today' : 'No Classes Left',
            style: _titleStyle(theme),
          ),
          const SizedBox(height: 8),
          Text(
            isToday ? 'You are done for the day.' : 'All classes for this day are finished.',
            style: _subtitleStyle(theme),
          ),
          const SizedBox(height: 24),
          if (isToday && tomorrowHoliday != null) ...[
            Text(
              'Tomorrow is ${tomorrowHoliday!.label} — No classes',
              style: _subtitleStyle(theme),
            ),
          ] else if (isToday && tomorrowFirstClass != null) ...[
            Text("Tomorrow's First Class", style: _headerStyle(theme)),
            const SizedBox(height: 8),
            Text(
              '${tomorrowFirstClass!.courseCode} | ${tomorrowFirstClass!.startTimeFormatted} | ${tomorrowFirstClass!.classroom}',
              style: _subtitleStyle(theme).copyWith(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ] else if (isToday) ...[
            Text('No classes scheduled for tomorrow.', style: _subtitleStyle(theme)),
          ],
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
