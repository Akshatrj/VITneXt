import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/class_live_sync.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';

/// Syncs native live-class monitor on launch and when today's schedule changes.
class ClassFocusHandler extends ConsumerStatefulWidget {
  final Widget child;

  const ClassFocusHandler({super.key, required this.child});

  @override
  ConsumerState<ClassFocusHandler> createState() => _ClassFocusHandlerState();
}

class _ClassFocusHandlerState extends ConsumerState<ClassFocusHandler> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncClassLiveMonitor(ref, force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(currentTimeProvider).maybeWhen(
          data: (now) => normalizeScheduleDate(now),
          orElse: () => normalizeScheduleDate(DateTime.now()),
        );

    ref.listen(dayScheduleProvider(today), (prev, next) {
      if (next.hasValue) {
        invalidateClassLiveMonitorSync();
        syncClassLiveMonitor(ref);
      }
    });

    ref.listen(autoSilentDuringClassProvider, (_, __) {
      invalidateClassLiveMonitorSync();
      syncClassLiveMonitor(ref, force: true);
    });

    return widget.child;
  }
}
