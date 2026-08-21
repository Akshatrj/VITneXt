import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/widget_health_monitor.dart';
import 'package:vit_nextclass/core/utils/prefs_utils.dart';

/// One class entry for the Android home-screen widget (today only).
class WidgetQueueEntry {
  final ResolvedClass resolved;
  final DateTime scheduleDate;

  const WidgetQueueEntry({
    required this.resolved,
    required this.scheduleDate,
  });
}

/// Bridges schedule data from Flutter to the native Android home screen widget.
class WidgetBridge {
  static const _platform = MethodChannel('com.vitnext/widget');

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _entryIdentity(WidgetQueueEntry entry) {
    final id = entry.resolved.linkedCourseId ?? entry.resolved.courseCode;
    return '${_dateKey(entry.scheduleDate)}|$id|${entry.resolved.startHour}:${entry.resolved.startMinute}';
  }

  static Map<String, dynamic> _queueItemJson(WidgetQueueEntry entry) {
    final cls = entry.resolved;
    final date = entry.scheduleDate;
    final isCurrent = cls.status == ClassStatus.current;
    final target = isCurrent
        ? DateTime(date.year, date.month, date.day, cls.endHour, cls.endMinute)
        : DateTime(date.year, date.month, date.day, cls.startHour, cls.startMinute);

    return {
      'status': cls.status.name,
      'courseName': cls.courseName,
      'courseCode': cls.courseCode,
      'faculty': cls.faculty,
      'time': '${cls.startTimeFormatted} – ${cls.endTimeFormatted}',
      'room': cls.classroom,
      'startHour': cls.startHour,
      'startMinute': cls.startMinute,
      'endHour': cls.endHour,
      'endMinute': cls.endMinute,
      'linkedCourseId': cls.linkedCourseId,
      'scheduleDate': _dateKey(date),
      'targetMillis': target.millisecondsSinceEpoch,
    };
  }

  static String? _holidayWidgetType(Holiday holiday) {
    if (!holiday.hidesClasses) return null;
    if (holiday.isExam) return 'exam';
    if (holiday.type == HolidayType.breakPeriod ||
        holiday.type == HolidayType.vacation) {
      return 'break';
    }
    return 'holiday';
  }

  static int _resolveQueueIndex({
    required List<WidgetQueueEntry> queue,
    required int previousIndex,
    required String? previousIdentitiesJson,
    ResolvedClass? currentClass,
    ResolvedClass? nextClass,
  }) {
    if (queue.isEmpty) return 0;

    // Prefer live current, then next — never jump to future days.
    final preferred = currentClass ?? nextClass;
    if (preferred != null) {
      final todayKey = _dateKey(DateTime.now());
      final idx = queue.indexWhere((e) {
        final sameId = preferred.linkedCourseId != null &&
            e.resolved.linkedCourseId == preferred.linkedCourseId;
        final sameSlot = e.resolved.startHour == preferred.startHour &&
            e.resolved.startMinute == preferred.startMinute &&
            e.resolved.courseCode == preferred.courseCode;
        return (sameId || sameSlot) && _dateKey(e.scheduleDate) == todayKey;
      });
      if (idx >= 0) return idx;
    }

    if (previousIdentitiesJson != null && previousIndex >= 0) {
      try {
        final prev = (jsonDecode(previousIdentitiesJson) as List)
            .map((e) => e.toString())
            .toList();
        if (previousIndex < prev.length) {
          final wanted = prev[previousIndex];
          final idx = queue.indexWhere((e) => _entryIdentity(e) == wanted);
          if (idx >= 0) return idx;
        }
      } catch (_) {}
    }

    final firstActive =
        queue.indexWhere((e) => e.resolved.status != ClassStatus.cancelled);
    return firstActive >= 0 ? firstActive : 0;
  }

  static Future<void> updateWidget({
    ResolvedClass? currentClass,
    ResolvedClass? nextClass,
    Holiday? holidayToday,
    List<WidgetQueueEntry>? upcomingQueue,
    bool dayComplete = false,
    bool noClassesToday = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    AppLog.instance.info('widget', 'updateWidget begin', data: {
      'hasCurrent': currentClass != null,
      'hasNext': nextClass != null,
      'queueIn': upcomingQueue?.length,
      'holiday': holidayToday?.label,
      'dayComplete': dayComplete,
      'noClassesToday': noClassesToday,
    });

    try {
      await _updateWidgetBody(
        prefs: prefs,
        currentClass: currentClass,
        nextClass: nextClass,
        holidayToday: holidayToday,
        upcomingQueue: upcomingQueue,
        dayComplete: dayComplete,
        noClassesToday: noClassesToday,
      );
      await WidgetHealthMonitor.instance.markUpdateOk(detail: 'bridge');
    } catch (e, st) {
      await WidgetHealthMonitor.instance.markUpdateFailed(e, st);
      rethrow;
    }
  }

  static Future<void> _updateWidgetBody({
    required SharedPreferences prefs,
    ResolvedClass? currentClass,
    ResolvedClass? nextClass,
    Holiday? holidayToday,
    List<WidgetQueueEntry>? upcomingQueue,
    bool dayComplete = false,
    bool noClassesToday = false,
  }) async {
    final previousIndex = prefs.getInt('widget_queue_index') ?? 0;
    final previousIdentities = prefs.getString('widget_queue_identities');
    final today = DateTime.now();
    final todayKey = _dateKey(today);

    // Today-only queue (caller should already filter; defend here too).
    final queue = <WidgetQueueEntry>[];
    if (upcomingQueue != null) {
      for (final entry in upcomingQueue) {
        if (_dateKey(entry.scheduleDate) == todayKey) {
          queue.add(entry);
        }
      }
    } else {
      if (currentClass != null) {
        queue.add(WidgetQueueEntry(resolved: currentClass, scheduleDate: today));
      }
      if (nextClass != null) {
        final already = queue.any(
          (e) =>
              e.resolved.linkedCourseId == nextClass.linkedCourseId &&
              e.resolved.startHour == nextClass.startHour &&
              e.resolved.startMinute == nextClass.startMinute,
        );
        if (!already) {
          queue.add(WidgetQueueEntry(resolved: nextClass, scheduleDate: today));
        }
      }
    }

    final holidayType = holidayToday != null ? _holidayWidgetType(holidayToday) : null;

    // Clear legacy "peek into tomorrow" skip flags.
    await prefs.remove('widget_holiday_skip');
    await prefs.remove('widget_day_complete_skip');

    if (holidayType != null) {
      await prefs.setString('widget_holiday_label', holidayToday!.label);
      await prefs.setString('widget_holiday_type', holidayType);
      await prefs.setString('widget_day_complete', 'false');
      await prefs.setString('widget_no_classes', 'false');
    } else {
      await prefs.remove('widget_holiday_label');
      await prefs.remove('widget_holiday_type');
      await prefs.setString('widget_day_complete', dayComplete ? 'true' : 'false');
      await prefs.setString('widget_no_classes', noClassesToday ? 'true' : 'false');
    }

    final cancelledKeys = <String>[];
    for (final entry in queue) {
      final id = entry.resolved.linkedCourseId;
      if (id != null && entry.resolved.status == ClassStatus.cancelled) {
        cancelledKeys.add('${_dateKey(entry.scheduleDate)}|$id');
      }
    }

    final identities = queue.map(_entryIdentity).toList();
    await prefs.setString('widget_queue_json', jsonEncode(queue.map(_queueItemJson).toList()));
    await prefs.setString('widget_queue_identities', jsonEncode(identities));

    final queueIndex = _resolveQueueIndex(
      queue: queue,
      previousIndex: previousIndex,
      previousIdentitiesJson: previousIdentities,
      currentClass: currentClass,
      nextClass: nextClass,
    );
    await prefs.setInt('widget_queue_index', queueIndex);
    // Native widget resets to live current/next on each bridge update.
    await prefs.remove('widget_browse_mode');

    final pendingScheduleSync = readPrefBool(prefs, 'pending_schedule_sync');
    if (!pendingScheduleSync) {
      await prefs.setString('widget_cancelled_keys', jsonEncode(cancelledKeys));
    }

    int? boundaryMillis;

    if (holidayType != null) {
      await _clearClassFields(prefs);
      if (holidayType == 'exam') {
        await prefs.setString('widget_status', 'exam');
        await prefs.setString('widget_course_name', 'Exam Day');
        await prefs.setString('widget_course_code', holidayToday!.label);
      } else if (holidayType == 'break') {
        await prefs.setString('widget_status', 'break');
        await prefs.setString('widget_course_name', 'No Classes Today');
        await prefs.setString(
          'widget_course_code',
          holidayToday!.label.isNotEmpty ? holidayToday.label : 'Semester Break',
        );
      } else {
        await prefs.setString('widget_status', 'holiday');
        await prefs.setString('widget_course_name', 'Holiday Today');
        await prefs.setString(
          'widget_course_code',
          holidayToday!.label.isNotEmpty ? holidayToday.label : 'No Classes',
        );
      }
    } else if (noClassesToday) {
      await _clearClassFields(prefs);
      await prefs.setString('widget_status', 'no_classes');
      await prefs.setString('widget_course_name', 'No Classes Today');
      await prefs.setString('widget_course_code', 'Enjoy your day!');
    } else if (dayComplete || (currentClass == null && nextClass == null)) {
      await _clearClassFields(prefs);
      await prefs.setString('widget_status', 'day_complete');
      await prefs.setString('widget_course_name', "Today's Classes Completed");
      await prefs.setString('widget_course_code', 'See you tomorrow!');
    } else {
      final classToShow = currentClass ?? nextClass!;
      final status = currentClass != null ? 'current' : 'next';

      await prefs.setString('widget_status', status);
      await prefs.setString('widget_course_name', classToShow.courseName);
      await prefs.setString('widget_course_code', classToShow.courseCode);
      await prefs.setString('widget_faculty', classToShow.faculty);
      await prefs.setString(
        'widget_time',
        '${classToShow.startTimeFormatted} – ${classToShow.endTimeFormatted}',
      );
      await prefs.setString('widget_room', classToShow.classroom);
      await prefs.setInt('widget_start_hour', classToShow.startHour);
      await prefs.setInt('widget_start_minute', classToShow.startMinute);
      await prefs.setInt('widget_end_hour', classToShow.endHour);
      await prefs.setInt('widget_end_minute', classToShow.endMinute);

      final targetDate = currentClass != null
          ? DateTime(today.year, today.month, today.day, classToShow.endHour, classToShow.endMinute)
          : DateTime(
              today.year,
              today.month,
              today.day,
              classToShow.startHour,
              classToShow.startMinute,
            );
      boundaryMillis = targetDate.millisecondsSinceEpoch;
      await prefs.setInt('widget_target_millis', boundaryMillis);

      final linkedId = classToShow.linkedCourseId;
      if (linkedId != null) {
        await prefs.setString('widget_linked_course_id', linkedId);
        await prefs.setString('widget_schedule_date', todayKey);
      } else {
        await prefs.remove('widget_linked_course_id');
        await prefs.remove('widget_schedule_date');
      }
    }

    if (boundaryMillis != null && boundaryMillis > DateTime.now().millisecondsSinceEpoch) {
      await prefs.setInt('widget_boundary_millis', boundaryMillis);
    } else {
      await prefs.remove('widget_boundary_millis');
    }

    try {
      await _platform.invokeMethod('updateWidget');
      AppLog.instance.info('widget', 'native updateWidget invoked', data: {
        'queue': queue.length,
        'index': prefs.getInt('widget_queue_index'),
        'status': prefs.getString('widget_status'),
      });
    } catch (e, st) {
      AppLog.instance.warn('widget', 'native channel unavailable', data: {
        'error': e.toString(),
        'stack': st.toString(),
      });
    }
  }

  static Future<void> _clearClassFields(SharedPreferences prefs) async {
    await prefs.remove('widget_faculty');
    await prefs.remove('widget_time');
    await prefs.remove('widget_room');
    await prefs.remove('widget_start_hour');
    await prefs.remove('widget_start_minute');
    await prefs.remove('widget_end_hour');
    await prefs.remove('widget_end_minute');
    await prefs.remove('widget_linked_course_id');
    await prefs.remove('widget_schedule_date');
    await prefs.remove('widget_target_millis');
  }
}
