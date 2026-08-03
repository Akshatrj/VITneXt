import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vit_nextclass/core/services/app_log.dart';

/// Local crash capture with Crashlytics-ready keys.
///
/// Cloud Crashlytics can be wired later by forwarding [recordError] to
/// Firebase; builds do not require a google-services.json today.
class CrashReporter {
  CrashReporter._();
  static final CrashReporter instance = CrashReporter._();

  bool _installed = false;
  String? _appVersion;
  String? _buildNumber;

  Future<void> init() async {
    if (_installed) return;
    _installed = true;

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
      AppLog.instance.setKeys({
        'appVersion': info.version,
        'buildNumber': info.buildNumber,
        'packageName': info.packageName,
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
      });
    } catch (e, st) {
      AppLog.instance.error('crash', 'PackageInfo failed', error: e, stackTrace: st);
    }

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: false,
        reason: details.context?.toString(),
      ));
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(recordError(error, stack, fatal: true, reason: 'platform'));
      return true;
    };

    AppLog.instance.info('crash', 'CrashReporter installed', data: {
      'appVersion': _appVersion,
      'buildNumber': _buildNumber,
    });
  }

  Future<void> setCustomKeys(Map<String, String> keys) async {
    AppLog.instance.setKeys(keys);
  }

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? reason,
    Map<String, Object?>? data,
  }) async {
    AppLog.instance.error(
      'crash',
      fatal ? 'FATAL' : 'NON_FATAL',
      error: error,
      stackTrace: stack,
      data: {
        'fatal': fatal,
        if (reason != null) 'reason': reason,
        'appVersion': _appVersion,
        'buildNumber': _buildNumber,
        ...?data,
        ...AppLog.instance.customKeys,
      },
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/vitnext_last_crash.txt');
      await file.writeAsString(
        [
          'ts=${DateTime.now().toIso8601String()}',
          'fatal=$fatal',
          'reason=${reason ?? ''}',
          'error=$error',
          'keys=${AppLog.instance.customKeys}',
          'stack=\n$stack',
        ].join('\n'),
        flush: true,
      );
    } catch (_) {}
  }
}
