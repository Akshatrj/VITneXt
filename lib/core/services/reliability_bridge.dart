import 'package:flutter/services.dart';
import 'package:vit_nextclass/core/services/app_log.dart';

/// Native bridge for battery optimization + widget health.
class ReliabilityBridge {
  static const _channel = MethodChannel('com.vitnext/reliability');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      AppLog.instance.info('battery', 'isIgnoringBatteryOptimizations', data: {
        'value': result,
      });
      return result ?? false;
    } catch (e, st) {
      AppLog.instance.error('battery', 'isIgnoring check failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Opens system battery-optimization settings for this app (non-forcing).
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
      AppLog.instance.info('battery', 'Opened battery optimization settings');
    } catch (e, st) {
      AppLog.instance.error('battery', 'open settings failed', error: e, stackTrace: st);
    }
  }

  /// Optional soft prompt via system dialog (user can deny).
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      AppLog.instance.info('battery', 'requestIgnoreBatteryOptimizations', data: {
        'acceptedOrAlready': result,
      });
      return result ?? false;
    } catch (e, st) {
      AppLog.instance.error('battery', 'request ignore failed', error: e, stackTrace: st);
      return false;
    }
  }

  static Future<void> scheduleWidgetHeal() async {
    try {
      await _channel.invokeMethod('scheduleWidgetHeal');
      AppLog.instance.info('widget', 'Scheduled widget heal alarms');
    } catch (e, st) {
      AppLog.instance.error('widget', 'scheduleWidgetHeal failed', error: e, stackTrace: st);
    }
  }

  /// Schedules a midnight alarm to refresh widget + class focus without opening the app.
  static Future<void> scheduleDayRollover() async {
    try {
      await _channel.invokeMethod('scheduleDayRollover');
      AppLog.instance.info('lifecycle', 'Scheduled day rollover alarm');
    } catch (e, st) {
      AppLog.instance.error('lifecycle', 'scheduleDayRollover failed', error: e, stackTrace: st);
    }
  }

  static Future<void> forceWidgetRefresh() async {
    try {
      await _channel.invokeMethod('forceWidgetRefresh');
      AppLog.instance.info('widget', 'Forced native widget refresh');
    } catch (e, st) {
      AppLog.instance.error('widget', 'forceWidgetRefresh failed', error: e, stackTrace: st);
    }
  }

  static Future<Map<String, Object?>> widgetHealth() async {
    try {
      final raw = await _channel.invokeMethod<Map>('widgetHealth');
      final map = Map<String, Object?>.from(raw ?? {});
      AppLog.instance.info('widget', 'widgetHealth', data: map);
      return map;
    } catch (e, st) {
      AppLog.instance.error('widget', 'widgetHealth failed', error: e, stackTrace: st);
      return {};
    }
  }
}
