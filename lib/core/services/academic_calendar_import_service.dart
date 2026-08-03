import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:vit_nextclass/core/models/holiday.dart';

/// Parses academic calendar files (CSV / JSON / XLSX) into [Holiday]s.
class AcademicCalendarImportService {
  AcademicCalendarImportService({this.semesterId});

  final String? semesterId;
  static const _uuid = Uuid();

  List<Holiday> parseCsv(String content) {
    final lines = const LineSplitter()
        .convert(content)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    var startIndex = 0;
    final headerCells = _splitCsvLine(lines.first).map((c) => c.toLowerCase()).toList();
    final looksLikeHeader = headerCells.any((h) =>
        h.contains('date') || h.contains('event') || h.contains('type') || h.contains('holiday'));
    if (looksLikeHeader) startIndex = 1;

    final dateCol = _columnIndex(headerCells, const ['date'], fallback: 0);
    final nameCol = _columnIndex(
      headerCells,
      const ['event name', 'event', 'holiday', 'name', 'label'],
      fallback: 1,
    );
    final typeCol = _columnIndex(
      headerCells,
      const ['type', 'holiday type', 'holiday'],
      fallback: 2,
    );

    final raw = <_RawEvent>[];
    for (var i = startIndex; i < lines.length; i++) {
      final cells = _splitCsvLine(lines[i]);
      if (cells.isEmpty) continue;
      final date = _parseDate(_cellAt(cells, dateCol));
      if (date == null) continue;
      final name = _cellAt(cells, nameCol).trim();
      if (name.isEmpty) continue;
      final type = HolidayTypeX.fromString(_cellAt(cells, typeCol));
      raw.add(_RawEvent(date: date, name: name, type: type));
    }

    return mergeConsecutive(_toHolidays(raw));
  }

  List<Holiday> parseJson(String content) {
    final decoded = jsonDecode(content);
    final List<dynamic> list;
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map<String, dynamic>) {
      list = (decoded['holidays'] ?? decoded['events'] ?? decoded['data'] ?? []) as List;
    } else {
      return [];
    }

    final raw = <_RawEvent>[];
    final ranged = <Holiday>[];

    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      // Full holiday objects (with ranges) — keep as-is after normalizing.
      if (map.containsKey('startDate') ||
          (map.containsKey('endDate') && map.containsKey('date'))) {
        try {
          final h = Holiday.fromJson({
            ...map,
            'id': map['id'] ?? _uuid.v4(),
            'semesterId': map['semesterId'] ?? semesterId,
            'source': map['source'] ?? 'Imported',
          });
          ranged.add(h.copyWith(
            id: h.id.isEmpty ? _uuid.v4() : h.id,
            semesterId: h.semesterId ?? semesterId,
            source: h.source.isEmpty ? 'Imported' : h.source,
          ));
          continue;
        } catch (_) {
          // Fall through to row-style parsing.
        }
      }

      final date = _parseDate(
        (map['date'] ?? map['startDate'] ?? map['eventDate'] ?? '').toString(),
      );
      if (date == null) continue;
      final name = (map['label'] ??
              map['eventName'] ??
              map['holidayName'] ??
              map['name'] ??
              map['event'] ??
              '')
          .toString()
          .trim();
      if (name.isEmpty) continue;
      final type = HolidayTypeX.fromString(
        (map['type'] ?? map['holidayType'] ?? '').toString(),
      );
      raw.add(_RawEvent(date: date, name: name, type: type));
    }

    return [...ranged, ...mergeConsecutive(_toHolidays(raw))];
  }

  List<Holiday> parseExcelBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    final sheet = excel.tables.values.first;
    if (sheet.maxRows == 0) return [];

    final rows = sheet.rows;
    var startIndex = 0;
    final headerCells = <String>[];
    for (var i = 0; i < rows.first.length; i++) {
      headerCells.add(_excelCell(rows.first, i).trim().toLowerCase());
    }
    final looksLikeHeader = headerCells.any((h) =>
        h.contains('date') || h.contains('event') || h.contains('type') || h.contains('holiday'));
    if (looksLikeHeader) startIndex = 1;

    final dateCol = _columnIndex(headerCells, const ['date'], fallback: 0);
    final nameCol = _columnIndex(
      headerCells,
      const ['event name', 'event', 'holiday', 'name', 'label'],
      fallback: 1,
    );
    final typeCol = _columnIndex(
      headerCells,
      const ['type', 'holiday type', 'holiday'],
      fallback: 2,
    );

    final raw = <_RawEvent>[];
    for (var i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      final dateStr = _excelCell(row, dateCol);
      final date = _parseDate(dateStr) ?? _parseExcelDate(row, dateCol);
      if (date == null) continue;
      final name = _excelCell(row, nameCol).trim();
      if (name.isEmpty) continue;
      final type = HolidayTypeX.fromString(_excelCell(row, typeCol));
      raw.add(_RawEvent(date: date, name: name, type: type));
    }

    return mergeConsecutive(_toHolidays(raw));
  }

  /// Merge consecutive same name+type single-day holidays into date ranges.
  List<Holiday> mergeConsecutive(List<Holiday> holidays) {
    if (holidays.isEmpty) return [];

    final sorted = [...holidays]
      ..sort((a, b) {
        final byStart = a.startDate.compareTo(b.startDate);
        if (byStart != 0) return byStart;
        final byName = a.label.compareTo(b.label);
        if (byName != 0) return byName;
        return a.type.index.compareTo(b.type.index);
      });

    final merged = <Holiday>[];
    Holiday? current;

    for (final h in sorted) {
      if (current == null) {
        current = h;
        continue;
      }

      final sameIdentity =
          current.label == h.label && current.type == h.type;
      final nextDay = DateTime(
        current.endDate.year,
        current.endDate.month,
        current.endDate.day,
      ).add(const Duration(days: 1));
      final hStart = DateTime(h.startDate.year, h.startDate.month, h.startDate.day);
      final contiguous = sameIdentity &&
          hStart.year == nextDay.year &&
          hStart.month == nextDay.month &&
          hStart.day == nextDay.day;

      if (contiguous) {
        current = current.copyWith(
          endDate: h.endDate.isAfter(current.endDate) ? h.endDate : current.endDate,
        );
      } else {
        merged.add(current);
        current = h;
      }
    }
    if (current != null) merged.add(current);
    return merged;
  }

  List<Holiday> _toHolidays(List<_RawEvent> raw) {
    return raw
        .map(
          (e) => Holiday(
            id: _uuid.v4(),
            semesterId: semesterId,
            startDate: DateTime(e.date.year, e.date.month, e.date.day),
            endDate: DateTime(e.date.year, e.date.month, e.date.day),
            label: e.name,
            type: e.type,
            source: 'Imported',
          ),
        )
        .toList();
  }

  static int _columnIndex(List<String> headers, List<String> candidates, {required int fallback}) {
    for (final candidate in candidates) {
      final idx = headers.indexWhere((h) => h == candidate || h.contains(candidate));
      if (idx >= 0) return idx;
    }
    return fallback;
  }

  static String _cellAt(List<String> cells, int index) {
    if (index < 0 || index >= cells.length) return '';
    return cells[index];
  }

  static String _excelCell(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    final cellValue = row[index]?.value;
    if (cellValue == null) return '';
    if (cellValue is TextCellValue) return cellValue.value.toString();
    if (cellValue is IntCellValue) return cellValue.value.toString();
    if (cellValue is DoubleCellValue) return cellValue.value.toString();
    if (cellValue is DateCellValue) {
      return DateFormat('yyyy-MM-dd').format(
        DateTime(cellValue.year, cellValue.month, cellValue.day),
      );
    }
    return cellValue.toString();
  }

  static DateTime? _parseExcelDate(List<Data?> row, int index) {
    if (index < 0 || index >= row.length) return null;
    final cellValue = row[index]?.value;
    if (cellValue is DateCellValue) {
      return DateTime(cellValue.year, cellValue.month, cellValue.day);
    }
    final asString = cellValue?.toString() ?? '';
    return _parseDate(asString);
  }

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    result.add(buffer.toString().trim());
    return result;
  }

  static DateTime? _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    // Excel serial date as number string
    final asNum = double.tryParse(value);
    if (asNum != null && asNum > 20000 && asNum < 80000) {
      final epoch = DateTime(1899, 12, 30);
      final dt = epoch.add(Duration(days: asNum.floor()));
      return DateTime(dt.year, dt.month, dt.day);
    }

    final formats = [
      DateFormat('dd-MM-yyyy'),
      DateFormat('d-M-yyyy'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('d/M/yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('dd MMM yyyy'),
      DateFormat('d MMM yyyy'),
    ];

    for (final format in formats) {
      try {
        final dt = format.parseStrict(value);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) {}
    }

    try {
      final dt = DateTime.parse(value);
      return DateTime(dt.year, dt.month, dt.day);
    } catch (_) {
      return null;
    }
  }
}

class _RawEvent {
  final DateTime date;
  final String name;
  final HolidayType type;

  _RawEvent({required this.date, required this.name, required this.type});
}
