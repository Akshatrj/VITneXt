import 'package:vit_nextclass/core/database/json_record_normalizers.dart';
import 'package:vit_nextclass/core/utils/location_formatter.dart';

enum OverrideType { cancelled, extra, modified }

class ScheduleOverride {
  final String id;
  final DateTime date;
  final OverrideType type;
  final String? linkedCourseId;
  final int? overrideStartHour;
  final int? overrideStartMinute;
  final int? overrideEndHour;
  final int? overrideEndMinute;
  final String? overrideBuilding;
  final String? overrideFloor;
  final String? overrideRoom;
  final String? reason;
  final String? extraCourseCode;
  final String? extraCourseName;
  final String? extraFaculty;

  ScheduleOverride({
    required this.id,
    required this.date,
    required this.type,
    this.linkedCourseId,
    this.overrideStartHour,
    this.overrideStartMinute,
    this.overrideEndHour,
    this.overrideEndMinute,
    this.overrideBuilding,
    this.overrideFloor,
    this.overrideRoom,
    this.reason,
    this.extraCourseCode,
    this.extraCourseName,
    this.extraFaculty,
  });

  String? get overrideClassroom {
    if (overrideBuilding == null || overrideFloor == null || overrideRoom == null) return null;
    return LocationFormatter.formatFromParts(
      building: overrideBuilding!,
      floor: overrideFloor!,
      room: overrideRoom!,
    );
  }

  /// Full descriptive override room for editing views.
  String? get overrideClassroomFull {
    if (overrideBuilding == null || overrideFloor == null || overrideRoom == null) return null;
    if (overrideBuilding == 'CR') return 'Online Class';
    if (overrideBuilding == 'Other') return overrideRoom;
    return '${overrideBuilding}, Floor ${overrideFloor}, Room ${overrideRoom}';
  }

  factory ScheduleOverride.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'] ?? json['scheduleDate'];
    return ScheduleOverride(
      id: jsonStr(json['id']),
      date: DateTime.parse(jsonStr(dateRaw)),
      type: OverrideType.values.firstWhere(
        (e) => e.name == jsonStr(json['type'], fallback: 'modified'),
        orElse: () => OverrideType.modified,
      ),
      linkedCourseId: json['linkedCourseId'] as String?,
      overrideStartHour: jsonInt(json['overrideStartHour']),
      overrideStartMinute: jsonInt(json['overrideStartMinute']),
      overrideEndHour: jsonInt(json['overrideEndHour']),
      overrideEndMinute: jsonInt(json['overrideEndMinute']),
      overrideBuilding: json['overrideBuilding'] as String?,
      overrideFloor: json['overrideFloor'] as String?,
      overrideRoom: json['overrideRoom'] as String?,
      reason: json['reason'] as String?,
      extraCourseCode: json['extraCourseCode'] as String?,
      extraCourseName: json['extraCourseName'] as String?,
      extraFaculty: json['extraFaculty'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'type': type.name,
      'linkedCourseId': linkedCourseId,
      'overrideStartHour': overrideStartHour,
      'overrideStartMinute': overrideStartMinute,
      'overrideEndHour': overrideEndHour,
      'overrideEndMinute': overrideEndMinute,
      'overrideBuilding': overrideBuilding,
      'overrideFloor': overrideFloor,
      'overrideRoom': overrideRoom,
      'reason': reason,
      'extraCourseCode': extraCourseCode,
      'extraCourseName': extraCourseName,
      'extraFaculty': extraFaculty,
    };
  }
}
