enum HolidayType {
  university,
  exam,
  festival,
  personal,
  emergency,
  vacation,
  sick,
  orientation,
  convocation,
  breakPeriod,
  other,
}

extension HolidayTypeX on HolidayType {
  String get label {
    switch (this) {
      case HolidayType.university:
        return 'University Holiday';
      case HolidayType.exam:
        return 'Exam Period';
      case HolidayType.festival:
        return 'Festival';
      case HolidayType.personal:
        return 'Personal Leave';
      case HolidayType.emergency:
        return 'Emergency Closure';
      case HolidayType.vacation:
        return 'Vacation';
      case HolidayType.sick:
        return 'Sick Leave';
      case HolidayType.orientation:
        return 'Orientation';
      case HolidayType.convocation:
        return 'Convocation';
      case HolidayType.breakPeriod:
        return 'Semester Break';
      case HolidayType.other:
        return 'Other';
    }
  }

  static HolidayType fromString(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    switch (value) {
      case 'university':
      case 'university holiday':
        return HolidayType.university;
      case 'exam':
      case 'exam holiday':
      case 'exam period':
        return HolidayType.exam;
      case 'festival':
        return HolidayType.festival;
      case 'personal':
      case 'personal leave':
      case 'personal holiday':
        return HolidayType.personal;
      case 'emergency':
      case 'emergency closure':
        return HolidayType.emergency;
      case 'vacation':
        return HolidayType.vacation;
      case 'break':
      case 'semester break':
      case 'breakperiod':
      case 'break_period':
        return HolidayType.breakPeriod;
      case 'sick':
      case 'sick leave':
        return HolidayType.sick;
      case 'orientation':
        return HolidayType.orientation;
      case 'convocation':
        return HolidayType.convocation;
      default:
        return HolidayType.other;
    }
  }
}

class Holiday {
  final String id;
  final String? semesterId;
  final DateTime startDate;
  final DateTime endDate;
  final String label;
  final HolidayType type;
  final String notes;
  final bool isRecurring;
  final String source; // Imported / Manual
  final DateTime createdAt;

  Holiday({
    required this.id,
    required this.startDate,
    DateTime? endDate,
    required this.label,
    this.semesterId,
    this.type = HolidayType.university,
    this.notes = '',
    this.isRecurring = false,
    this.source = 'Manual',
    DateTime? createdAt,
  })  : endDate = endDate ?? startDate,
        createdAt = createdAt ?? DateTime.now();

  /// Backward-compatible single-day accessor.
  DateTime get date => startDate;

  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  bool get hidesClasses =>
      type != HolidayType.orientation && type != HolidayType.convocation;

  bool get isExam => type == HolidayType.exam;

  factory Holiday.fromJson(Map<String, dynamic> json) {
    final start = DateTime.parse(
      (json['startDate'] ?? json['date']) as String,
    );
    final endRaw = json['endDate'] as String?;
    var end = endRaw != null ? DateTime.parse(endRaw) : start;
    // Normalize inverted ranges from bad imports.
    if (end.isBefore(start)) end = start;
    return Holiday(
      id: json['id'] as String,
      semesterId: json['semesterId'] as String?,
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(end.year, end.month, end.day),
      label: (json['label'] ?? json['holidayName'] ?? json['eventName'] ?? 'Holiday')
          as String,
      type: HolidayTypeX.fromString(json['type'] as String? ?? json['holidayType'] as String?),
      notes: (json['notes'] as String?) ?? '',
      isRecurring: (json['isRecurring'] as bool?) ?? false,
      source: (json['source'] as String?) ?? 'Manual',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'semesterId': semesterId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'date': startDate.toIso8601String(), // legacy readers
      'label': label,
      'holidayName': label,
      'type': type.name,
      'holidayType': type.name,
      'notes': notes,
      'isRecurring': isRecurring,
      'source': source,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Holiday copyWith({
    String? id,
    String? semesterId,
    DateTime? startDate,
    DateTime? endDate,
    String? label,
    HolidayType? type,
    String? notes,
    bool? isRecurring,
    String? source,
    DateTime? createdAt,
  }) {
    return Holiday(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      label: label ?? this.label,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      isRecurring: isRecurring ?? this.isRecurring,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
