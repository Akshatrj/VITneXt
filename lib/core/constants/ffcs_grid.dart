/// Official VIT Bhopal FFCS Theory timetable grid.
///
/// Each cell ID maps to exactly one session: row = day, column = time block.
library;

/// A single cell on the official theory timetable grid.
class FFCSGridCell {
  final String id;
  final int dayOfWeek; // 1 = Monday … 6 = Saturday
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const FFCSGridCell({
    required this.id,
    required this.dayOfWeek,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}

/// Time block metadata for grid column headers.
class FFCSGridTimeColumn {
  final String label;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const FFCSGridTimeColumn({
    required this.label,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}

/// Day row on the theory grid.
class FFCSGridDayRow {
  final String dayLabel;
  final int dayOfWeek;
  final List<String> cellIds; // 7 slots (excludes lunch column)

  const FFCSGridDayRow({
    required this.dayLabel,
    required this.dayOfWeek,
    required this.cellIds,
  });
}

/// Single source of truth for the visual FFCS theory grid layout and timings.
class FFCSTheoryGrid {
  FFCSTheoryGrid._();

  static const String lunchLabel = 'Lunch';

  static const List<FFCSGridTimeColumn> timeColumns = [
    FFCSGridTimeColumn(
      label: '08:30\n10:00',
      startHour: 8,
      startMinute: 30,
      endHour: 10,
      endMinute: 0,
    ),
    FFCSGridTimeColumn(
      label: '10:05\n11:35',
      startHour: 10,
      startMinute: 5,
      endHour: 11,
      endMinute: 35,
    ),
    FFCSGridTimeColumn(
      label: '11:40\n13:10',
      startHour: 11,
      startMinute: 40,
      endHour: 13,
      endMinute: 10,
    ),
    FFCSGridTimeColumn(
      label: '13:15\n14:45',
      startHour: 13,
      startMinute: 15,
      endHour: 14,
      endMinute: 45,
    ),
    FFCSGridTimeColumn(
      label: '14:50\n16:20',
      startHour: 14,
      startMinute: 50,
      endHour: 16,
      endMinute: 20,
    ),
    FFCSGridTimeColumn(
      label: '16:25\n17:55',
      startHour: 16,
      startMinute: 25,
      endHour: 17,
      endMinute: 55,
    ),
    FFCSGridTimeColumn(
      label: '18:00\n19:30',
      startHour: 18,
      startMinute: 0,
      endHour: 19,
      endMinute: 30,
    ),
  ];

  static const List<FFCSGridDayRow> dayRows = [
    FFCSGridDayRow(
      dayLabel: 'MON',
      dayOfWeek: 1,
      cellIds: ['A11', 'B11', 'C11', 'A21', 'A14', 'B21', 'C21'],
    ),
    FFCSGridDayRow(
      dayLabel: 'TUE',
      dayOfWeek: 2,
      cellIds: ['D11', 'E11', 'F11', 'D21', 'E14', 'E21', 'F21'],
    ),
    FFCSGridDayRow(
      dayLabel: 'WED',
      dayOfWeek: 3,
      cellIds: ['A12', 'B12', 'C12', 'A22', 'B14', 'B22', 'A24'],
    ),
    FFCSGridDayRow(
      dayLabel: 'THU',
      dayOfWeek: 4,
      cellIds: ['D12', 'E12', 'F12', 'D22', 'F14', 'E22', 'F22'],
    ),
    FFCSGridDayRow(
      dayLabel: 'FRI',
      dayOfWeek: 5,
      cellIds: ['A13', 'B13', 'C13', 'A23', 'C14', 'B23', 'B24'],
    ),
    FFCSGridDayRow(
      dayLabel: 'SAT',
      dayOfWeek: 6,
      cellIds: ['D13', 'E13', 'F13', 'D23', 'D14', 'D24', 'E23'],
    ),
  ];

  static final Map<String, FFCSGridCell> _cellById = _buildCellMap();

  static Map<String, FFCSGridCell> get cellById => _cellById;

  static bool isGridCell(String id) => _cellById.containsKey(id);

  static FFCSGridCell? getCell(String id) => _cellById[id];

  static List<String> get allCellIds => _cellById.keys.toList();

  static Map<String, FFCSGridCell> _buildCellMap() {
    final map = <String, FFCSGridCell>{};
    for (final row in dayRows) {
      for (int i = 0; i < row.cellIds.length; i++) {
        final id = row.cellIds[i];
        final col = timeColumns[i];
        map[id] = FFCSGridCell(
          id: id,
          dayOfWeek: row.dayOfWeek,
          startHour: col.startHour,
          startMinute: col.startMinute,
          endHour: col.endHour,
          endMinute: col.endMinute,
        );
      }
    }
    return map;
  }
}
