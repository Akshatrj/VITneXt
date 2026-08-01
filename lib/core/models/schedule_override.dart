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
    if (overrideBuilding == 'CR') return 'Online';
    if (overrideBuilding == 'Other') return overrideRoom;
    String floorNum = overrideFloor == 'G' ? '0' : overrideFloor!;
    return '$overrideBuilding-$floorNum$overrideRoom';
  }

  factory ScheduleOverride.fromJson(Map<String, dynamic> json) {
    return ScheduleOverride(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      type: OverrideType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OverrideType.modified,
      ),
      linkedCourseId: json['linkedCourseId'] as String?,
      overrideStartHour: json['overrideStartHour'] as int?,
      overrideStartMinute: json['overrideStartMinute'] as int?,
      overrideEndHour: json['overrideEndHour'] as int?,
      overrideEndMinute: json['overrideEndMinute'] as int?,
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
