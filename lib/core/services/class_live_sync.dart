import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/class_focus_bridge.dart';
import 'package:vit_nextclass/core/services/schedule_resolver.dart';

const _syncDebounceMinutes = 5;

DateTime? _lastSyncTime;
bool _scheduleInvalidated = false;

/// Mark the next sync as required (bypasses debounce), e.g. after schedule edits.
void invalidateClassLiveMonitorSync() {
  _scheduleInvalidated = true;
}

/// Pushes today's schedule and user prefs to the native live-class monitor.
Future<void> syncClassLiveMonitor(dynamic ref, {bool force = false}) async {
  final liveEnabled = ref.read(liveClassStatusProvider);
  final autoSilent = ref.read(autoSilentDuringClassProvider);

  if (!force && !_scheduleInvalidated && _lastSyncTime != null) {
    final elapsed = DateTime.now().difference(_lastSyncTime!);
    if (elapsed.inMinutes < _syncDebounceMinutes) {
      return;
    }
  }

  _scheduleInvalidated = false;

  if (!liveEnabled && !autoSilent) {
    await ClassFocusBridge.stopMonitor();
    _lastSyncTime = DateTime.now();
    return;
  }

  final resolver = ref.read(scheduleResolverProvider);
  final schedule = await resolver.resolveSchedule(DateTime.now());

  await ClassFocusBridge.syncMonitor(
    liveStatusEnabled: liveEnabled,
    autoSilentEnabled: autoSilent,
    todaySchedule: schedule,
  );
  _lastSyncTime = DateTime.now();
}

/// Same as [syncClassLiveMonitor] without Riverpod (startup).
Future<void> syncClassLiveMonitorOnStartup() async {
  final prefs = await SharedPreferences.getInstance();
  final liveEnabled = prefs.getBool('live_class_status_enabled') ?? false;
  final autoSilent = prefs.getBool('auto_silent_during_class') ?? false;

  if (!liveEnabled && !autoSilent) {
    await ClassFocusBridge.stopMonitor();
    return;
  }

  final storage = LocalStorage();
  final resolver = ScheduleResolver(storage);
  final schedule = await resolver.resolveSchedule(DateTime.now());

  await ClassFocusBridge.syncMonitor(
    liveStatusEnabled: liveEnabled,
    autoSilentEnabled: autoSilent,
    todaySchedule: schedule,
  );
  _lastSyncTime = DateTime.now();
}
