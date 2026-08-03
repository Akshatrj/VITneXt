import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/utils/prefs_utils.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';

/// Handles pending schedule sync from the Android home-screen widget.
class WidgetActionHandler extends ConsumerStatefulWidget {
  final Widget child;

  const WidgetActionHandler({super.key, required this.child});

  @override
  ConsumerState<WidgetActionHandler> createState() => _WidgetActionHandlerState();
}

class _WidgetActionHandlerState extends ConsumerState<WidgetActionHandler>
    with WidgetsBindingObserver {
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _processPendingScheduleSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _processPendingScheduleSync();
    }
  }

  Future<void> _processPendingScheduleSync() async {
    if (_processing) return;
    _processing = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      final needsSync = readPrefBool(prefs, 'pending_schedule_sync') ||
          readPrefBool(prefs, 'pending_widget_cancel_toggle');
      if (!needsSync) return;

      await prefs.remove('pending_schedule_sync');
      await prefs.remove('pending_widget_cancel_toggle');
      await prefs.remove('pending_widget_cancel_key');

      ref.invalidate(overridesProvider);
      invalidateTodaySchedule(ref);
      await refreshWidgetSchedule(ref);
    } catch (_) {
      // Never crash the app from a widget action.
    } finally {
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
