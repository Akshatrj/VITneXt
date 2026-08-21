/// Normalizes raw JSON maps from legacy app versions into the current schema.
library;

String jsonStr(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

int? jsonInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool jsonBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is String) return value == 'true';
  return fallback;
}

/// Returns null when the record cannot be normalized (missing required id).
Map<String, dynamic>? normalizeSemesterRecord(Map<String, dynamic> raw) {
  final id = jsonStr(raw['id']).trim();
  if (id.isEmpty) return null;

  return {
    'id': id,
    'name': jsonStr(raw['name'] ?? raw['semesterName']),
    'isActive': jsonBool(raw['isActive']),
  };
}

/// Maps legacy field names (`courseName`, `courseCode`, `slot`) to current keys.
Map<String, dynamic>? normalizeCourseRecord(Map<String, dynamic> raw) {
  final id = jsonStr(raw['id']).trim();
  final semesterId = jsonStr(raw['semesterId']).trim();
  if (id.isEmpty || semesterId.isEmpty) return null;

  return {
    'id': id,
    'semesterId': semesterId,
    'code': jsonStr(raw['code'] ?? raw['courseCode']),
    'name': jsonStr(raw['name'] ?? raw['courseName']),
    'faculty': jsonStr(raw['faculty']),
    'ffcsSlot': jsonStr(raw['ffcsSlot'] ?? raw['slot']),
    'building': jsonStr(raw['building']),
    'floor': jsonStr(raw['floor']),
    'room': jsonStr(raw['room']),
    if (raw['color'] != null) 'color': jsonInt(raw['color']),
  };
}

Map<String, dynamic>? normalizeOverrideRecord(Map<String, dynamic> raw) {
  final id = jsonStr(raw['id']).trim();
  if (id.isEmpty) return null;

  final dateRaw = raw['date'] ?? raw['scheduleDate'];
  if (dateRaw == null) return null;

  final dateStr = jsonStr(dateRaw);
  if (dateStr.isEmpty) return null;

  final type = jsonStr(raw['type'], fallback: 'modified');
  final normalized = <String, dynamic>{
    'id': id,
    'date': dateStr,
    'type': type,
  };

  void putIfPresent(String key) {
    final v = raw[key];
    if (v != null) normalized[key] = v;
  }

  putIfPresent('linkedCourseId');
  putIfPresent('overrideStartHour');
  putIfPresent('overrideStartMinute');
  putIfPresent('overrideEndHour');
  putIfPresent('overrideEndMinute');
  putIfPresent('overrideBuilding');
  putIfPresent('overrideFloor');
  putIfPresent('overrideRoom');
  putIfPresent('reason');
  putIfPresent('extraCourseCode');
  putIfPresent('extraCourseName');
  putIfPresent('extraFaculty');

  return normalized;
}

/// Converts legacy single `date` / `holidayName` fields to the current shape.
Map<String, dynamic>? normalizeHolidayRecord(Map<String, dynamic> raw) {
  final id = jsonStr(raw['id']).trim();
  if (id.isEmpty) return null;

  final startRaw = raw['startDate'] ?? raw['date'];
  if (startRaw == null) return null;

  final startStr = jsonStr(startRaw);
  if (startStr.isEmpty) return null;

  final endRaw = raw['endDate'];
  final endStr = endRaw != null ? jsonStr(endRaw) : startStr;

  final label = jsonStr(
    raw['label'] ?? raw['holidayName'] ?? raw['eventName'],
    fallback: 'Holiday',
  );
  final type = jsonStr(raw['type'] ?? raw['holidayType'], fallback: 'other');

  final normalized = <String, dynamic>{
    'id': id,
    'startDate': startStr,
    'endDate': endStr,
    'date': startStr,
    'label': label,
    'holidayName': label,
    'type': type,
    'holidayType': type,
    'notes': jsonStr(raw['notes']),
    'isRecurring': jsonBool(raw['isRecurring']),
    'source': jsonStr(raw['source'], fallback: 'Manual'),
  };

  final semesterId = raw['semesterId'];
  if (semesterId != null && jsonStr(semesterId).isNotEmpty) {
    normalized['semesterId'] = jsonStr(semesterId);
  }

  if (raw['createdAt'] != null) {
    normalized['createdAt'] = jsonStr(raw['createdAt']);
  }

  return normalized;
}
