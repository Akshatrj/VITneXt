import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/app.dart';
import 'package:vit_nextclass/app_maintenance.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/crash_reporter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    await AppLog.instance.init();
    await CrashReporter.instance.init();
    await LocalStorage().init();
    AppLog.instance.info('lifecycle', 'main() start');

    runApp(const ProviderScope(child: VITNextClassApp()));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(runPostLaunchMaintenance());
    });
  }, (error, stack) {
    unawaited(CrashReporter.instance.recordError(error, stack, fatal: true, reason: 'zone'));
  });
}
