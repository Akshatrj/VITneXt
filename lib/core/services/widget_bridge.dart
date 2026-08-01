import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';

/// Bridges schedule data from Flutter to the native Android home screen widget.
/// 
/// Writes current/next class info to SharedPreferences which the native
/// [NextClassWidgetProvider] reads to render the widget.
class WidgetBridge {
  static const _platform = MethodChannel('com.vitnextclass/widget');

  /// Update the widget with the current or next class info.
  /// Call this whenever the schedule changes or periodically from the home screen.
  static Future<void> updateWidget({
    ResolvedClass? currentClass,
    ResolvedClass? nextClass,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Prioritize current class, fall back to next class
    final classToShow = currentClass ?? nextClass;

    if (classToShow != null) {
      final status = currentClass != null ? 'current' : 'next';

      await prefs.setString('widget_status', status);
      await prefs.setString('widget_course_name', classToShow.courseName);
      await prefs.setString('widget_course_code', classToShow.courseCode);
      await prefs.setString('widget_faculty', classToShow.faculty);
      await prefs.setString('widget_time',
          '${classToShow.startTimeFormatted} – ${classToShow.endTimeFormatted}');
      await prefs.setString('widget_room', classToShow.classroom);
      await prefs.setInt('widget_start_hour', classToShow.startHour);
      await prefs.setInt('widget_start_minute', classToShow.startMinute);
      await prefs.setInt('widget_end_hour', classToShow.endHour);
      await prefs.setInt('widget_end_minute', classToShow.endMinute);
      if (nextClass != null && nextClass.linkedCourseId != null) {
        await prefs.setString('widget_linked_course_id', nextClass.linkedCourseId!);
        final now = DateTime.now();
        await prefs.setString(
          'widget_schedule_date',
          DateTime(now.year, now.month, now.day).toIso8601String(),
        );
      } else {
        await prefs.remove('widget_linked_course_id');
        await prefs.remove('widget_schedule_date');
      }
    } else {
      // No class to show — clear widget data
      await prefs.remove('widget_status');
      await prefs.remove('widget_course_name');
      await prefs.remove('widget_course_code');
      await prefs.remove('widget_faculty');
      await prefs.remove('widget_time');
      await prefs.remove('widget_room');
      await prefs.remove('widget_start_hour');
      await prefs.remove('widget_start_minute');
      await prefs.remove('widget_end_hour');
      await prefs.remove('widget_end_minute');
      await prefs.remove('widget_linked_course_id');
      await prefs.remove('widget_schedule_date');
    }

    // Trigger native widget refresh
    try {
      await _platform.invokeMethod('updateWidget');
    } catch (e) {
      // Widget update channel not available (e.g. no widget placed)
      // This is fine — the widget will update on its own schedule
    }
  }
}
