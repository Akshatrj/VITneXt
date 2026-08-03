import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';

/// Handles pending actions from the Android home-screen widget.
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _processPendingWidgetCancel());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _processPendingWidgetCancel();
    }
  }

  Future<void> _processPendingWidgetCancel() async {
    if (_processing) return;
    _processing = true;
    try {
      final prefs = await SharedPreferences.getInstance();

      // SharedPreferences plugin adds the "flutter." prefix — do NOT include it here.
      final pending = prefs.getBool('pending_widget_cancel_toggle') == true ||
          prefs.getString('pending_widget_cancel_toggle') == 'true';
      if (!pending) return;

      await prefs.remove('pending_widget_cancel_toggle');
      final key = prefs.getString('pending_widget_cancel_key');
      await prefs.remove('pending_widget_cancel_key');
      if (key == null || key.isEmpty || !mounted) return;

      final parts = key.split('|');
      if (parts.length != 2) return;
      final dateStr = parts[0];
      final courseId = parts[1];
      if (courseId.isEmpty) return;

      final DateTime date;
      try {
        final segs = dateStr.split('-');
        if (segs.length != 3) return;
        date = DateTime(
          int.parse(segs[0]),
          int.parse(segs[1]),
          int.parse(segs[2]),
        );
      } catch (_) {
        return;
      }

      final storage = ref.read(localStorageProvider);
      final overrides = await storage.getOverridesForDate(date);
      ScheduleOverride? existing;
      for (final o in overrides) {
        if (o.type == OverrideType.cancelled && o.linkedCourseId == courseId) {
          existing = o;
          break;
        }
      }

      if (existing != null) {
        await storage.deleteOverride(existing.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class restored')),
          );
        }
      } else {
        final override = ScheduleOverride(
          id: const Uuid().v4(),
          date: date,
          type: OverrideType.cancelled,
          linkedCourseId: courseId,
          reason: 'Cancelled by Teacher',
        );
        await storage.saveOverride(override);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class marked as cancelled')),
          );
        }
      }

      ref.invalidate(overridesProvider);
      invalidateScheduleForDate(ref, date);
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
