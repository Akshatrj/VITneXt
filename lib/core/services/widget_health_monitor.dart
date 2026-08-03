import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/reliability_bridge.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';

/// Detects stale widget data and forces a refresh / native heal.
class WidgetHealthMonitor {
  WidgetHealthMonitor._();
  static final WidgetHealthMonitor instance = WidgetHealthMonitor._();

  static const _lastOkKey = 'widget_last_ok_millis';
  static const _staleAfter = Duration(hours: 2);

  Future<void> markUpdateOk({String? detail}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_lastOkKey, now);
    AppLog.instance.setKey('widgetUpdateStatus', 'ok');
    AppLog.instance.setKey('widgetLastOk', DateTime.now().toIso8601String());
    AppLog.instance.info('widget', 'Update OK', data: {
      'detail': detail,
      'millis': now,
    });
  }

  Future<void> markUpdateFailed(Object error, StackTrace stack) async {
    AppLog.instance.setKey('widgetUpdateStatus', 'failed');
    AppLog.instance.error('widget', 'Update failed', error: error, stackTrace: stack);
  }

  /// Call on app resume / startup. Heals if last success is too old.
  Future<void> checkAndHeal(dynamic ref) async {
    try {
      await ReliabilityBridge.scheduleWidgetHeal();
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastOkKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - last;
      final stale = last == 0 || age > _staleAfter.inMilliseconds;
      final health = await ReliabilityBridge.widgetHealth();

      AppLog.instance.info('widget', 'Health check', data: {
        'stale': stale,
        'ageMs': age,
        'native': health,
      });

      if (stale) {
        AppLog.instance.warn('widget', 'Widget stale — self-healing');
        await ReliabilityBridge.forceWidgetRefresh();
        await refreshWidgetSchedule(ref);
        await markUpdateOk(detail: 'self-heal');
      }
    } catch (e, st) {
      AppLog.instance.error('widget', 'checkAndHeal failed', error: e, stackTrace: st);
    }
  }
}

/// Observes app lifecycle for logging + widget heal.
class AppLifecycleLogger extends StatefulWidget {
  const AppLifecycleLogger({super.key, required this.child, required this.onResumed});

  final Widget child;
  final VoidCallback onResumed;

  @override
  State<AppLifecycleLogger> createState() => _AppLifecycleLoggerState();
}

class _AppLifecycleLoggerState extends State<AppLifecycleLogger>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLog.instance.info('lifecycle', 'observer attached');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLog.instance.info('lifecycle', 'observer detached');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLog.instance.info('lifecycle', state.name);
    if (state == AppLifecycleState.resumed) {
      widget.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
