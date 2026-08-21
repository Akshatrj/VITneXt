import 'package:vit_nextclass/core/database/json_record_normalizers.dart';

class Semester {
  final String id;
  final String name;
  final bool isActive;

  Semester({
    required this.id,
    required this.name,
    this.isActive = false,
  });

  Semester copyWith({
    String? id,
    String? name,
    bool? isActive,
  }) {
    return Semester(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }

  factory Semester.fromJson(Map<String, dynamic> json) {
    return Semester(
      id: jsonStr(json['id']),
      name: jsonStr(json['name'] ?? json['semesterName']),
      isActive: jsonBool(json['isActive']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
    };
  }
}
