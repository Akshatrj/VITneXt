import 'package:vit_nextclass/core/constants/buildings.dart';
import 'package:vit_nextclass/core/utils/location_formatter.dart';

enum ClassStatus { upcoming, current, next, completed, cancelled, extra }

class ResolvedClass {
  final String courseCode;
  final String courseName;
  final String faculty;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String building;
  final String floor;
  final String room;
  final ClassStatus status;
  final bool isOverride;
  final String? overrideReason;
  final String? linkedCourseId;

  ResolvedClass({
    required this.courseCode,
    required this.courseName,
    required this.faculty,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.building,
    required this.floor,
    required this.room,
    required this.status,
    this.isOverride = false,
    this.overrideReason,
    this.linkedCourseId,
  });

  /// Abbreviated display location (e.g. `AB-1 105`).
  String get classroom =>
      LocationFormatter.formatFromParts(building: building, floor: floor, room: room);

  /// Full descriptive location for editing and export.
  String get classroomFull {
    final buildingName = Buildings.getFullName(building);
    if (building == 'CR') return buildingName;
    if (building == 'Other') return '$buildingName - $room';

    final floorName = Buildings.floorDisplayNames[floor] ?? '$floor Floor';
    return '$buildingName, $floorName, Room $room';
  }

  String get startTimeFormatted {
    final hour = startHour > 12 ? startHour - 12 : (startHour == 0 ? 12 : startHour);
    final min = startMinute.toString().padLeft(2, '0');
    final ampm = startHour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  String get endTimeFormatted {
    final hour = endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour);
    final min = endMinute.toString().padLeft(2, '0');
    final ampm = endHour >= 12 ? 'PM' : 'AM';
    return '$hour:$min $ampm';
  }

  int get startTotalMinutes => startHour * 60 + startMinute;
  int get endTotalMinutes => endHour * 60 + endMinute;

  bool isCurrentlyRunning(DateTime now) {
    final nowTotal = now.hour * 60 + now.minute;
    return nowTotal >= startTotalMinutes && nowTotal < endTotalMinutes;
  }

  bool isUpcoming(DateTime now) {
    final nowTotal = now.hour * 60 + now.minute;
    return nowTotal < startTotalMinutes;
  }

  int minutesUntilStart(DateTime now) {
    final nowTotal = now.hour * 60 + now.minute;
    return startTotalMinutes - nowTotal;
  }

  int minutesUntilEnd(DateTime now) {
    final nowTotal = now.hour * 60 + now.minute;
    return endTotalMinutes - nowTotal;
  }

  ResolvedClass copyWith({
    String? courseCode,
    String? courseName,
    String? faculty,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    String? building,
    String? floor,
    String? room,
    ClassStatus? status,
    bool? isOverride,
    String? overrideReason,
    String? linkedCourseId,
  }) {
    return ResolvedClass(
      courseCode: courseCode ?? this.courseCode,
      courseName: courseName ?? this.courseName,
      faculty: faculty ?? this.faculty,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      room: room ?? this.room,
      status: status ?? this.status,
      isOverride: isOverride ?? this.isOverride,
      overrideReason: overrideReason ?? this.overrideReason,
      linkedCourseId: linkedCourseId ?? this.linkedCourseId,
    );
  }
}
