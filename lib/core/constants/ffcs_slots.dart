import 'package:vit_nextclass/core/constants/ffcs_grid.dart';

/// Complete FFCS Theory Slot Database for VIT Bhopal.
///
/// Maps every theory slot identifier to its weekly schedule (day + start/end time).
/// Lab slots are excluded per project requirements.
///
/// Slot categories:
/// - Morning theory: A1–G1 (50-min periods, 08:00–12:50)
/// - Evening theory: A2–G2 (50-min periods, 14:00–18:50)
/// - Morning tutorials: TA1–TG1, TAA1–TDD1
/// - Evening tutorials: TA2–TG2, TAA2–TDD2
/// - 90-min sub-slots (VIT Bhopal): A11–D13, A21–D23

/// Represents a single scheduled session within a week.
class SlotTiming {
  /// Day of the week (1 = Monday, 7 = Sunday).
  final int day;

  /// Start time as hour and minute.
  final int startHour;
  final int startMinute;

  /// End time as hour and minute.
  final int endHour;
  final int endMinute;

  const SlotTiming({
    required this.day,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  /// Human-readable day name.
  String get dayName => const [
        '',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][day];

  /// Formatted start time (e.g. "08:00 AM").
  String get startTimeFormatted => _formatTime(startHour, startMinute);

  /// Formatted end time (e.g. "08:50 AM").
  String get endTimeFormatted => _formatTime(endHour, endMinute);

  /// Start time as total minutes from midnight.
  int get startTotalMinutes => startHour * 60 + startMinute;

  /// End time as total minutes from midnight.
  int get endTotalMinutes => endHour * 60 + endMinute;

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${h.toString()}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Check if this timing overlaps with another.
  bool overlaps(SlotTiming other) {
    if (day != other.day) return false;
    return startTotalMinutes < other.endTotalMinutes &&
        endTotalMinutes > other.startTotalMinutes;
  }
}

/// Represents a predefined FFCS slot combination (e.g. "A1+TA1").
class FFCSSlotCombo {
  /// Display name shown in the dropdown (e.g. "A1+TA1").
  final String name;

  /// Individual slot identifiers that make up this combo.
  final List<String> slots;

  /// Description of the slot type.
  final String description;

  const FFCSSlotCombo({
    required this.name,
    required this.slots,
    required this.description,
  });

  /// Get all timings for this combo by resolving each slot.
  List<SlotTiming> get timings {
    final result = <SlotTiming>[];
    for (final slot in slots) {
      final t = FFCSSlotDatabase.getSlotTimings(slot);
      if (t != null) result.addAll(t);
    }
    return result;
  }
}

/// The complete FFCS slot database.
///
/// Contains all theory slot timings and predefined slot combinations.
class FFCSSlotDatabase {
  FFCSSlotDatabase._();

  // ─────────────────────────────────────────────
  // Individual Slot → Timing Mapping
  // ─────────────────────────────────────────────

  static const Map<String, List<SlotTiming>> _slotTimings = {
    // ── Morning Theory Slots (50 min) ──

    'A1': [
      SlotTiming(day: 1, startHour: 8, startMinute: 0, endHour: 8, endMinute: 50),
      SlotTiming(day: 3, startHour: 9, startMinute: 0, endHour: 9, endMinute: 50),
    ],
    'B1': [
      SlotTiming(day: 2, startHour: 8, startMinute: 0, endHour: 8, endMinute: 50),
      SlotTiming(day: 4, startHour: 9, startMinute: 0, endHour: 9, endMinute: 50),
    ],
    'C1': [
      SlotTiming(day: 3, startHour: 8, startMinute: 0, endHour: 8, endMinute: 50),
      SlotTiming(day: 5, startHour: 9, startMinute: 0, endHour: 9, endMinute: 50),
    ],
    'D1': [
      SlotTiming(day: 1, startHour: 10, startMinute: 0, endHour: 10, endMinute: 50),
      SlotTiming(day: 4, startHour: 8, startMinute: 0, endHour: 8, endMinute: 50),
    ],
    'E1': [
      SlotTiming(day: 2, startHour: 10, startMinute: 0, endHour: 10, endMinute: 50),
      SlotTiming(day: 5, startHour: 8, startMinute: 0, endHour: 8, endMinute: 50),
    ],
    'F1': [
      SlotTiming(day: 1, startHour: 9, startMinute: 0, endHour: 9, endMinute: 50),
      SlotTiming(day: 3, startHour: 10, startMinute: 0, endHour: 10, endMinute: 50),
    ],
    'G1': [
      SlotTiming(day: 2, startHour: 9, startMinute: 0, endHour: 9, endMinute: 50),
      SlotTiming(day: 4, startHour: 10, startMinute: 0, endHour: 10, endMinute: 50),
    ],

    // ── Morning Tutorial Slots (50 min) ──

    'TA1': [
      SlotTiming(day: 5, startHour: 10, startMinute: 0, endHour: 10, endMinute: 50),
    ],
    'TB1': [
      SlotTiming(day: 1, startHour: 11, startMinute: 0, endHour: 11, endMinute: 50),
    ],
    'TC1': [
      SlotTiming(day: 2, startHour: 11, startMinute: 0, endHour: 11, endMinute: 50),
    ],
    'TD1': [
      SlotTiming(day: 3, startHour: 11, startMinute: 0, endHour: 11, endMinute: 50),
    ],
    'TE1': [
      SlotTiming(day: 4, startHour: 11, startMinute: 0, endHour: 11, endMinute: 50),
    ],
    'TF1': [
      SlotTiming(day: 5, startHour: 11, startMinute: 0, endHour: 11, endMinute: 50),
    ],
    'TG1': [
      SlotTiming(day: 1, startHour: 12, startMinute: 0, endHour: 12, endMinute: 50),
    ],
    'TAA1': [
      SlotTiming(day: 2, startHour: 12, startMinute: 0, endHour: 12, endMinute: 50),
    ],
    'TBB1': [
      SlotTiming(day: 3, startHour: 12, startMinute: 0, endHour: 12, endMinute: 50),
    ],
    'TCC1': [
      SlotTiming(day: 4, startHour: 12, startMinute: 0, endHour: 12, endMinute: 50),
    ],
    'TDD1': [
      SlotTiming(day: 5, startHour: 12, startMinute: 0, endHour: 12, endMinute: 50),
    ],

    // ── Evening Theory Slots (50 min) ──

    'A2': [
      SlotTiming(day: 1, startHour: 14, startMinute: 0, endHour: 14, endMinute: 50),
      SlotTiming(day: 3, startHour: 15, startMinute: 0, endHour: 15, endMinute: 50),
    ],
    'B2': [
      SlotTiming(day: 2, startHour: 14, startMinute: 0, endHour: 14, endMinute: 50),
      SlotTiming(day: 4, startHour: 15, startMinute: 0, endHour: 15, endMinute: 50),
    ],
    'C2': [
      SlotTiming(day: 3, startHour: 14, startMinute: 0, endHour: 14, endMinute: 50),
      SlotTiming(day: 5, startHour: 15, startMinute: 0, endHour: 15, endMinute: 50),
    ],
    'D2': [
      SlotTiming(day: 1, startHour: 16, startMinute: 0, endHour: 16, endMinute: 50),
      SlotTiming(day: 4, startHour: 14, startMinute: 0, endHour: 14, endMinute: 50),
    ],
    'E2': [
      SlotTiming(day: 2, startHour: 16, startMinute: 0, endHour: 16, endMinute: 50),
      SlotTiming(day: 5, startHour: 14, startMinute: 0, endHour: 14, endMinute: 50),
    ],
    'F2': [
      SlotTiming(day: 1, startHour: 15, startMinute: 0, endHour: 15, endMinute: 50),
      SlotTiming(day: 3, startHour: 16, startMinute: 0, endHour: 16, endMinute: 50),
    ],
    'G2': [
      SlotTiming(day: 2, startHour: 15, startMinute: 0, endHour: 15, endMinute: 50),
      SlotTiming(day: 4, startHour: 16, startMinute: 0, endHour: 16, endMinute: 50),
    ],

    // ── Evening Tutorial Slots (50 min) ──

    'TA2': [
      SlotTiming(day: 5, startHour: 16, startMinute: 0, endHour: 16, endMinute: 50),
    ],
    'TB2': [
      SlotTiming(day: 1, startHour: 17, startMinute: 0, endHour: 17, endMinute: 50),
    ],
    'TC2': [
      SlotTiming(day: 2, startHour: 17, startMinute: 0, endHour: 17, endMinute: 50),
    ],
    'TD2': [
      SlotTiming(day: 3, startHour: 17, startMinute: 0, endHour: 17, endMinute: 50),
    ],
    'TE2': [
      SlotTiming(day: 4, startHour: 17, startMinute: 0, endHour: 17, endMinute: 50),
    ],
    'TF2': [
      SlotTiming(day: 5, startHour: 17, startMinute: 0, endHour: 17, endMinute: 50),
    ],
    'TG2': [
      SlotTiming(day: 1, startHour: 18, startMinute: 0, endHour: 18, endMinute: 50),
    ],
    'TAA2': [
      SlotTiming(day: 2, startHour: 18, startMinute: 0, endHour: 18, endMinute: 50),
    ],
    'TBB2': [
      SlotTiming(day: 3, startHour: 18, startMinute: 0, endHour: 18, endMinute: 50),
    ],
    'TCC2': [
      SlotTiming(day: 4, startHour: 18, startMinute: 0, endHour: 18, endMinute: 50),
    ],
    'TDD2': [
      SlotTiming(day: 5, startHour: 18, startMinute: 0, endHour: 18, endMinute: 50),
    ],

    // ── 90-Minute Sub-Slots (VIT Bhopal Specific) ──

    'A11': [
      SlotTiming(day: 1, startHour: 8, startMinute: 30, endHour: 10, endMinute: 0),
    ],
    'A12': [
      SlotTiming(day: 3, startHour: 8, startMinute: 30, endHour: 10, endMinute: 0),
    ],
    'A13': [
      SlotTiming(day: 5, startHour: 8, startMinute: 30, endHour: 10, endMinute: 0),
    ],
    'B11': [
      SlotTiming(day: 2, startHour: 8, startMinute: 30, endHour: 10, endMinute: 0),
    ],
    'B12': [
      SlotTiming(day: 4, startHour: 8, startMinute: 30, endHour: 10, endMinute: 0),
    ],
    'B13': [
      SlotTiming(day: 6, startHour: 8, startMinute: 30, endHour: 10, endMinute: 0),
    ],
    'C11': [
      SlotTiming(day: 3, startHour: 10, startMinute: 30, endHour: 12, endMinute: 0),
    ],
    'C12': [
      SlotTiming(day: 5, startHour: 10, startMinute: 30, endHour: 12, endMinute: 0),
    ],
    'C13': [
      SlotTiming(day: 1, startHour: 10, startMinute: 30, endHour: 12, endMinute: 0),
    ],
    'D11': [
      SlotTiming(day: 4, startHour: 10, startMinute: 30, endHour: 12, endMinute: 0),
    ],
    'D12': [
      SlotTiming(day: 2, startHour: 10, startMinute: 30, endHour: 12, endMinute: 0),
    ],
    'D13': [
      SlotTiming(day: 6, startHour: 10, startMinute: 30, endHour: 12, endMinute: 0),
    ],

    // ── Evening 90-Minute Sub-Slots ──

    'A21': [
      SlotTiming(day: 1, startHour: 13, startMinute: 30, endHour: 15, endMinute: 0),
    ],
    'A22': [
      SlotTiming(day: 3, startHour: 13, startMinute: 30, endHour: 15, endMinute: 0),
    ],
    'A23': [
      SlotTiming(day: 5, startHour: 13, startMinute: 30, endHour: 15, endMinute: 0),
    ],
    'B21': [
      SlotTiming(day: 2, startHour: 13, startMinute: 30, endHour: 15, endMinute: 0),
    ],
    'B22': [
      SlotTiming(day: 4, startHour: 13, startMinute: 30, endHour: 15, endMinute: 0),
    ],
    'B23': [
      SlotTiming(day: 6, startHour: 13, startMinute: 30, endHour: 15, endMinute: 0),
    ],
    'C21': [
      SlotTiming(day: 3, startHour: 15, startMinute: 30, endHour: 17, endMinute: 0),
    ],
    'C22': [
      SlotTiming(day: 5, startHour: 15, startMinute: 30, endHour: 17, endMinute: 0),
    ],
    'C23': [
      SlotTiming(day: 1, startHour: 15, startMinute: 30, endHour: 17, endMinute: 0),
    ],
    'D21': [
      SlotTiming(day: 4, startHour: 15, startMinute: 30, endHour: 17, endMinute: 0),
    ],
    'D22': [
      SlotTiming(day: 2, startHour: 15, startMinute: 30, endHour: 17, endMinute: 0),
    ],
    'D23': [
      SlotTiming(day: 6, startHour: 15, startMinute: 30, endHour: 17, endMinute: 0),
    ],
  };

  /// Get timings for an individual slot identifier.
  /// Grid cell IDs (A11, A14, D11, …) resolve from [FFCSTheoryGrid] first.
  static List<SlotTiming>? getSlotTimings(String slot) {
    final gridCell = FFCSTheoryGrid.getCell(slot);
    if (gridCell != null) {
      return [
        SlotTiming(
          day: gridCell.dayOfWeek,
          startHour: gridCell.startHour,
          startMinute: gridCell.startMinute,
          endHour: gridCell.endHour,
          endMinute: gridCell.endMinute,
        ),
      ];
    }
    return _slotTimings[slot];
  }

  /// All available individual slot identifiers.
  static List<String> get allSlotIds => _slotTimings.keys.toList();

  // ─────────────────────────────────────────────
  // Predefined Slot Combinations (Dropdown Options)
  // ─────────────────────────────────────────────

  static final List<FFCSSlotCombo> slotCombos = [
    // ── 90-Minute Triplets (VIT Bhopal 3-Credit Theory) ──

    const FFCSSlotCombo(
      name: 'A11+A12+A13',
      slots: ['A11', 'A12', 'A13'],
      description: 'Mon/Wed/Fri 8:30–10:00 AM',
    ),
    const FFCSSlotCombo(
      name: 'B11+B12+B13',
      slots: ['B11', 'B12', 'B13'],
      description: 'Tue/Thu/Sat 8:30–10:00 AM',
    ),
    const FFCSSlotCombo(
      name: 'C11+C12+C13',
      slots: ['C11', 'C12', 'C13'],
      description: 'Mon/Wed/Fri 10:30 AM–12:00 PM',
    ),
    const FFCSSlotCombo(
      name: 'D11+D12+D13',
      slots: ['D11', 'D12', 'D13'],
      description: 'Tue/Thu/Sat 10:30 AM–12:00 PM',
    ),
    const FFCSSlotCombo(
      name: 'A21+A22+A23',
      slots: ['A21', 'A22', 'A23'],
      description: 'Mon/Wed/Fri 1:30–3:00 PM',
    ),
    const FFCSSlotCombo(
      name: 'B21+B22+B23',
      slots: ['B21', 'B22', 'B23'],
      description: 'Tue/Thu/Sat 1:30–3:00 PM',
    ),
    const FFCSSlotCombo(
      name: 'C21+C22+C23',
      slots: ['C21', 'C22', 'C23'],
      description: 'Mon/Wed/Fri 3:30–5:00 PM',
    ),
    const FFCSSlotCombo(
      name: 'D21+D22+D23',
      slots: ['D21', 'D22', 'D23'],
      description: 'Tue/Thu/Sat 3:30–5:00 PM',
    ),

    // ── Standard 3-Credit Theory + Tutorial (Morning) ──

    const FFCSSlotCombo(
      name: 'A1+TA1',
      slots: ['A1', 'TA1'],
      description: 'Mon/Wed + Fri tutorial',
    ),
    const FFCSSlotCombo(
      name: 'B1+TB1',
      slots: ['B1', 'TB1'],
      description: 'Tue/Thu + Mon tutorial',
    ),
    const FFCSSlotCombo(
      name: 'C1+TC1',
      slots: ['C1', 'TC1'],
      description: 'Wed/Fri + Tue tutorial',
    ),
    const FFCSSlotCombo(
      name: 'D1+TD1',
      slots: ['D1', 'TD1'],
      description: 'Mon/Thu + Wed tutorial',
    ),
    const FFCSSlotCombo(
      name: 'E1+TE1',
      slots: ['E1', 'TE1'],
      description: 'Tue/Fri + Thu tutorial',
    ),
    const FFCSSlotCombo(
      name: 'F1+TF1',
      slots: ['F1', 'TF1'],
      description: 'Mon/Wed + Fri tutorial',
    ),
    const FFCSSlotCombo(
      name: 'G1+TG1',
      slots: ['G1', 'TG1'],
      description: 'Tue/Thu + Mon tutorial',
    ),

    // ── Standard 3-Credit Theory + Tutorial (Evening) ──

    const FFCSSlotCombo(
      name: 'A2+TA2',
      slots: ['A2', 'TA2'],
      description: 'Mon/Wed + Fri tutorial',
    ),
    const FFCSSlotCombo(
      name: 'B2+TB2',
      slots: ['B2', 'TB2'],
      description: 'Tue/Thu + Mon tutorial',
    ),
    const FFCSSlotCombo(
      name: 'C2+TC2',
      slots: ['C2', 'TC2'],
      description: 'Wed/Fri + Tue tutorial',
    ),
    const FFCSSlotCombo(
      name: 'D2+TD2',
      slots: ['D2', 'TD2'],
      description: 'Mon/Thu + Wed tutorial',
    ),
    const FFCSSlotCombo(
      name: 'E2+TE2',
      slots: ['E2', 'TE2'],
      description: 'Tue/Fri + Thu tutorial',
    ),
    const FFCSSlotCombo(
      name: 'F2+TF2',
      slots: ['F2', 'TF2'],
      description: 'Mon/Wed + Fri tutorial',
    ),
    const FFCSSlotCombo(
      name: 'G2+TG2',
      slots: ['G2', 'TG2'],
      description: 'Tue/Thu + Mon tutorial',
    ),

    // ── 4-Credit Theory + Tutorial + Extra Tutorial (Morning) ──

    const FFCSSlotCombo(
      name: 'A1+TA1+TAA1',
      slots: ['A1', 'TA1', 'TAA1'],
      description: '4-credit: Mon/Wed + Fri + Tue',
    ),
    const FFCSSlotCombo(
      name: 'B1+TB1+TCC1',
      slots: ['B1', 'TB1', 'TCC1'],
      description: '4-credit: Tue/Thu + Mon + Thu',
    ),
    const FFCSSlotCombo(
      name: 'C1+TC1+TBB1',
      slots: ['C1', 'TC1', 'TBB1'],
      description: '4-credit: Wed/Fri + Tue + Wed',
    ),
    const FFCSSlotCombo(
      name: 'D1+TD1+TCC1',
      slots: ['D1', 'TD1', 'TCC1'],
      description: '4-credit: Mon/Thu + Wed + Thu',
    ),
    const FFCSSlotCombo(
      name: 'E1+TE1+TDD1',
      slots: ['E1', 'TE1', 'TDD1'],
      description: '4-credit: Tue/Fri + Thu + Fri',
    ),
    const FFCSSlotCombo(
      name: 'F1+TF1+TDD1',
      slots: ['F1', 'TF1', 'TDD1'],
      description: '4-credit: Mon/Wed + Fri + Fri',
    ),
    const FFCSSlotCombo(
      name: 'G1+TG1+TAA1',
      slots: ['G1', 'TG1', 'TAA1'],
      description: '4-credit: Tue/Thu + Mon + Tue',
    ),

    // ── 4-Credit Theory + Tutorial + Extra Tutorial (Evening) ──

    const FFCSSlotCombo(
      name: 'A2+TA2+TAA2',
      slots: ['A2', 'TA2', 'TAA2'],
      description: '4-credit: Mon/Wed + Fri + Tue',
    ),
    const FFCSSlotCombo(
      name: 'B2+TB2+TCC2',
      slots: ['B2', 'TB2', 'TCC2'],
      description: '4-credit: Tue/Thu + Mon + Thu',
    ),
    const FFCSSlotCombo(
      name: 'C2+TC2+TBB2',
      slots: ['C2', 'TC2', 'TBB2'],
      description: '4-credit: Wed/Fri + Tue + Wed',
    ),
    const FFCSSlotCombo(
      name: 'D2+TD2+TCC2',
      slots: ['D2', 'TD2', 'TCC2'],
      description: '4-credit: Mon/Thu + Wed + Thu',
    ),
    const FFCSSlotCombo(
      name: 'E2+TE2+TDD2',
      slots: ['E2', 'TE2', 'TDD2'],
      description: '4-credit: Tue/Fri + Thu + Fri',
    ),
    const FFCSSlotCombo(
      name: 'F2+TF2+TDD2',
      slots: ['F2', 'TF2', 'TDD2'],
      description: '4-credit: Mon/Wed + Fri + Fri',
    ),
    const FFCSSlotCombo(
      name: 'G2+TG2+TAA2',
      slots: ['G2', 'TG2', 'TAA2'],
      description: '4-credit: Tue/Thu + Mon + Tue',
    ),
  ];

  /// Find a slot combo by its name.
  static FFCSSlotCombo? findCombo(String name) {
    try {
      return slotCombos.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Get all timings for a combo name string.
  static List<SlotTiming> getTimingsForCombo(String comboName) {
    final combo = findCombo(comboName);
    if (combo != null) return combo.timings;

    // If not a predefined combo, try parsing as "+"-separated individual slots.
    final parts = comboName.split('+');
    final result = <SlotTiming>[];
    for (final part in parts) {
      final t = getSlotTimings(part.trim());
      if (t != null) result.addAll(t);
    }
    return result;
  }

  /// Get all classes scheduled on a specific day of week for a given slot combo.
  /// [dayOfWeek]: 1 = Monday, 7 = Sunday.
  static List<SlotTiming> getTimingsForDay(String comboName, int dayOfWeek) {
    return getTimingsForCombo(comboName)
        .where((t) => t.day == dayOfWeek)
        .toList()
      ..sort((a, b) => a.startTotalMinutes.compareTo(b.startTotalMinutes));
  }
}
