import 'package:vit_nextclass/core/constants/buildings.dart';
import 'package:vit_nextclass/core/services/app_log.dart';

/// Standardizes classroom locations for display (e.g. `AB-1 105`).
/// Original building/floor/room values in storage are never modified.
class LocationFormatter {
  LocationFormatter._();

  static final Map<String, String> _cache = {};

  /// Display abbreviation from structured course/schedule fields.
  static String formatFromParts({
    required String building,
    required String floor,
    required String room,
  }) {
    final key = 'parts|$building|$floor|$room';
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = _formatFromParts(building, floor, room);
    _cache[key] = result;
    return result;
  }

  /// Parse a full location string (imported/legacy text) into abbreviated form.
  static String formatFromFullText(String fullLocation) {
    final trimmed = fullLocation.trim();
    if (trimmed.isEmpty) return trimmed;

    final key = 'full|$trimmed';
    final cached = _cache[key];
    if (cached != null) return cached;

    final parsed = _parseFullText(trimmed);
    if (parsed != null) {
      final result = _formatFromParts(parsed.building, parsed.floor, parsed.room);
      _cache[key] = result;
      return result;
    }

    AppLog.instance.warn('location', 'Could not parse location', data: {'input': trimmed});
    _cache[key] = trimmed;
    return trimmed;
  }

  static String _formatFromParts(String building, String floor, String room) {
    final code = building.trim().toUpperCase();
    if (code == Buildings.cr) return 'CR';
    if (code == Buildings.other) return room.trim().isEmpty ? Buildings.getFullName(code) : room.trim();

    final prefix = _buildingPrefix(code);
    if (prefix == null) {
      // Unknown building code — fall back to legacy compact or raw room.
      if (room.trim().isNotEmpty) return room.trim();
      return Buildings.getFullName(building);
    }

    final suffix = _floorRoomSuffix(floor, room);
    if (suffix.isEmpty) return prefix;
    return '$prefix $suffix';
  }

  static String? _buildingPrefix(String buildingCode) {
    switch (buildingCode) {
      case Buildings.ab:
        return 'AB-1';
      case Buildings.ab02:
        return 'AB-2';
      case Buildings.ar:
        return 'AR';
      case Buildings.lc:
        return 'LC';
      case Buildings.cr:
        return 'CR';
      case Buildings.cb:
        return 'CB';
      default:
        return null;
    }
  }

  /// Floor digit + room number (e.g. floor 1 + room 05 → `105`).
  static String _floorRoomSuffix(String floor, String room) {
    final floorDigit = _floorToDigit(floor);
    final roomDigits = _extractDigits(room);
    if (roomDigits.isEmpty) return floorDigit;

    final roomPart = roomDigits.length >= 2 ? roomDigits : roomDigits.padLeft(2, '0');
    return '$floorDigit$roomPart';
  }

  static String _floorToDigit(String floor) {
    final f = floor.trim().toUpperCase();
    if (f == 'G' || f == 'GF' || f.contains('GROUND')) return '0';
    final match = RegExp(r'\d+').firstMatch(f);
    if (match != null) return match.group(0)!;
    return '0';
  }

  static String _extractDigits(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits;
  }

  static _ParsedLocation? _parseFullText(String text) {
    final normalized = text
        .replaceAll(RegExp(r'[,;]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

    if (normalized.isEmpty) return null;

    if (_containsAny(normalized, ['online class', 'online'])) {
      return const _ParsedLocation(building: Buildings.cr, floor: '1', room: '');
    }

    String? buildingCode;
    if (_matchesAcademicBlock1(normalized)) {
      buildingCode = Buildings.ab;
    } else if (_matchesAcademicBlock2(normalized)) {
      buildingCode = Buildings.ab02;
    } else if (normalized.contains('architecture block') || normalized.contains('architecture')) {
      buildingCode = Buildings.ar;
    } else if (normalized.contains('lab complex') || normalized == 'lc') {
      buildingCode = Buildings.lc;
    } else if (normalized.contains('central block')) {
      buildingCode = Buildings.cb;
    }

    if (buildingCode == null) return null;

    final floor = _parseFloorFromText(normalized);
    final room = _parseRoomFromText(text);
    if (room == null) return null;

    return _ParsedLocation(building: buildingCode, floor: floor, room: room);
  }

  static bool _matchesAcademicBlock1(String normalized) {
    if (normalized.contains('academic block -1') ||
        normalized.contains('academic block-1') ||
        normalized.contains('academic block 1') ||
        RegExp(r'academic block\s*-\s*1\b').hasMatch(normalized)) {
      return true;
    }
    // "Academic Block 1" without hyphen variant in getFullName
    return RegExp(r'academic block\s+1\b').hasMatch(normalized) &&
        !RegExp(r'academic block\s+2').hasMatch(normalized);
  }

  static bool _matchesAcademicBlock2(String normalized) {
    return normalized.contains('academic block -2') ||
        normalized.contains('academic block-2') ||
        normalized.contains('academic block 2') ||
        RegExp(r'academic block\s*-\s*2\b').hasMatch(normalized) ||
        RegExp(r'academic block\s+2\b').hasMatch(normalized);
  }

  static String _parseFloorFromText(String normalized) {
    if (normalized.contains('ground floor') || normalized.contains('ground')) return 'G';
    final ordinal = RegExp(r'(\d)(?:st|nd|rd|th)\s+floor').firstMatch(normalized);
    if (ordinal != null) return ordinal.group(1)!;
    final floorNo = RegExp(r'floor\s*(?:no\.?|number)?\s*(\d)').firstMatch(normalized);
    if (floorNo != null) return floorNo.group(1)!;
    return '1';
  }

  static String? _parseRoomFromText(String text) {
    final patterns = [
      RegExp(r'room\s*(?:no\.?|number)?\s*[#:]?\s*(\d+)', caseSensitive: false),
      RegExp(r'rm\s*(?:no\.?)?\s*(\d+)', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1)!;
    }
    return null;
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }

  /// Clears memoized formats (tests only).
  static void clearCacheForTesting() {
    _cache.clear();
  }
}

class _ParsedLocation {
  final String building;
  final String floor;
  final String room;

  const _ParsedLocation({
    required this.building,
    required this.floor,
    required this.room,
  });
}
