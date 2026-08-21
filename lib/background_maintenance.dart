import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:vit_nextclass/app_maintenance.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/crash_reporter.dart';
import 'package:flutter/services.dart';

const _backgroundChannel = MethodChannel('com.vitnext/background');

/// Headless entry point for midnight / day-rollover maintenance (no UI).
@pragma('vm:entry-point')
void backgroundMaintenance() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppLog.instance.init();
    await CrashReporter.instance.init();
    await LocalStorage().init();
    AppLog.instance.info('lifecycle', 'backgroundMaintenance start');
    try {
      await runPostLaunchMaintenance().timeout(const Duration(seconds: 45));
      AppLog.instance.info('lifecycle', 'backgroundMaintenance done');
    } catch (e, st) {
      AppLog.instance.error('lifecycle', 'backgroundMaintenance failed', error: e, stackTrace: st);
    }
    try {
      await _backgroundChannel.invokeMethod('maintenanceComplete');
    } catch (_) {}
  }, (error, stack) {
    unawaited(CrashReporter.instance.recordError(error, stack, fatal: false, reason: 'background'));
    unawaited(_backgroundChannel.invokeMethod('maintenanceComplete'));
  });
}
