import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';

/// Bridges silent-during-class mode to the native Android monitor service.
class ClassFocusBridge {
  static const _channel = MethodChannel('com.vitnext/class_focus');

  static Future<void> syncMonitor({
    required bool autoSilentEnabled,
    required List<ResolvedClass> todaySchedule,
  }) async {
    if (!autoSilentEnabled) {
      await stopMonitor();
      return;
    }

    final scheduleJson = jsonEncode(todaySchedule.map(_slotToJson).toList());

    try {
      await _channel.invokeMethod('syncClassMonitor', {
        'autoSilent': autoSilentEnabled,
        'scheduleJson': scheduleJson,
      });
    } catch (_) {
      // Native channel unavailable (non-Android).
    }
  }

  static Future<void> stopMonitor() async {
    try {
      await _channel.invokeMethod('stopClassMonitor');
    } catch (_) {}
  }

  static Future<bool> canModifyRingerMode() async {
    try {
      final result = await _channel.invokeMethod<bool>('canModifyRingerMode');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSoundSettings() async {
    try {
      await _channel.invokeMethod('openSoundSettings');
    } catch (_) {}
  }

  static Map<String, dynamic> _slotToJson(ResolvedClass cls) {
    return {
      'startHour': cls.startHour,
      'startMinute': cls.startMinute,
      'endHour': cls.endHour,
      'endMinute': cls.endMinute,
      'cancelled': cls.status == ClassStatus.cancelled,
    };
  }
}
