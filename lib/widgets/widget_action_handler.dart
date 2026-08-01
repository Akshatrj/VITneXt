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

class _WidgetActionHandlerState extends ConsumerState<WidgetActionHandler> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _processPendingWidgetCancel());
  }

  Future<void> _processPendingWidgetCancel() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('flutter.pending_widget_cancel') != true) return;

    await prefs.remove('flutter.pending_widget_cancel');
    final courseId = prefs.getString('flutter.widget_linked_course_id');
    final dateStr = prefs.getString('flutter.widget_schedule_date');
    if (courseId == null || dateStr == null || !mounted) return;

    final date = DateTime.parse(dateStr);
    final storage = ref.read(localStorageProvider);
    final overrides = await storage.getOverridesForDate(date);
    bool alreadyCancelled = false;
    for (final o in overrides) {
      if (o.type == OverrideType.cancelled && o.linkedCourseId == courseId) {
        alreadyCancelled = true;
        break;
      }
    }
    if (alreadyCancelled) return;

    final override = ScheduleOverride(
      id: const Uuid().v4(),
      date: date,
      type: OverrideType.cancelled,
      linkedCourseId: courseId,
      reason: 'Cancelled by teacher',
    );
    await storage.saveOverride(override);
    ref.invalidate(overridesProvider);
    invalidateTodaySchedule(ref);
    await refreshWidgetSchedule(ref);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Next class marked as cancelled')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
