import 'package:vit_nextclass/core/database/json_record_normalizers.dart';
import 'package:vit_nextclass/core/constants/buildings.dart';
import 'package:vit_nextclass/core/utils/location_formatter.dart';

class Course {
  final String id;
  final String semesterId;
  final String code;
  final String name;
  final String faculty;
  final String ffcsSlot;
  final String building;
  final String floor;
  final String room;
  final int? color;

  Course({
    required this.id,
    required this.semesterId,
    required this.code,
    required this.name,
    required this.faculty,
    required this.ffcsSlot,
    required this.building,
    required this.floor,
    required this.room,
    this.color,
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

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: jsonStr(json['id']),
      semesterId: jsonStr(json['semesterId']),
      code: jsonStr(json['code'] ?? json['courseCode']),
      name: jsonStr(json['name'] ?? json['courseName']),
      faculty: jsonStr(json['faculty']),
      ffcsSlot: jsonStr(json['ffcsSlot'] ?? json['slot']),
      building: jsonStr(json['building']),
      floor: jsonStr(json['floor']),
      room: jsonStr(json['room']),
      color: jsonInt(json['color']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'semesterId': semesterId,
      'code': code,
      'name': name,
      'faculty': faculty,
      'ffcsSlot': ffcsSlot,
      'building': building,
      'floor': floor,
      'room': room,
      'color': color,
    };
  }
}
