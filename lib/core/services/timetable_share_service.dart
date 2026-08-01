import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vit_nextclass/core/constants/ffcs_slots.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/models/course.dart';

/// Builds a human-readable timetable summary for sharing.
class TimetableShareService {
  TimetableShareService(this._storage);

  final LocalStorage _storage;

  Future<String> buildShareText() async {
    final semester = await _storage.getActiveSemester();
    final courses = await _storage.getActiveSemesterCourses();

    final buffer = StringBuffer();
    buffer.writeln('VIT NextClass — FFCS Timetable');
    if (semester != null) {
      buffer.writeln('Semester: ${semester.name}');
    }
    buffer.writeln('Generated: ${DateFormat('d MMM yyyy').format(DateTime.now())}');
    buffer.writeln('');
    buffer.writeln('── Courses ──');

    if (courses.isEmpty) {
      buffer.writeln('No courses added yet.');
    } else {
      for (final course in courses) {
        buffer.writeln(_formatCourse(course));
      }
    }

    buffer.writeln('');
    buffer.writeln('── Weekly pattern ──');
    buffer.writeln(_buildWeeklySummary(courses));

    buffer.writeln('');
    buffer.writeln('Managed with VIT NextClass');
    return buffer.toString();
  }

  String _formatCourse(Course course) {
    return '${course.code} — ${course.name}\n'
        '  Slot: ${course.ffcsSlot}\n'
        '  Faculty: ${course.faculty}\n'
        '  Room: ${course.classroomFull}';
  }

  String _buildWeeklySummary(List<Course> courses) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final lines = <String>[];

    for (int day = 1; day <= 6; day++) {
      final entries = <String>[];
      for (final course in courses) {
        final timings = FFCSSlotDatabase.getTimingsForDay(course.ffcsSlot, day);
        for (final t in timings) {
          entries.add(
            '${_formatShortTime(t.startHour, t.startMinute)} ${course.code}',
          );
        }
      }
      if (entries.isEmpty) {
        lines.add('${days[day - 1]}: —');
      } else {
        entries.sort();
        lines.add('${days[day - 1]}: ${entries.join(', ')}');
      }
    }
    return lines.join('\n');
  }

  String _formatShortTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${h}:${minute.toString().padLeft(2, '0')}$period';
  }

  Future<void> shareTimetable() async {
    final text = await buildShareText();
    await Share.share(text, subject: 'My FFCS Timetable');
  }
}
