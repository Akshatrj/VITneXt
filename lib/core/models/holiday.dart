class Holiday {
  final String id;
  final DateTime date;
  final String label;

  Holiday({
    required this.id,
    required this.date,
    required this.label,
  });

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      label: json['label'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'label': label,
    };
  }
}
