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
  late final DateTime _todayKey;
  bool _listenersAttached = false;

  @override
  void initState() {
    super.initState();
    _todayKey = normalizeScheduleDate(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncClassLiveMonitor(ref, force: true);
      _attachListeners();
    });
  }

  void _attachListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    ref.listen(dayScheduleProvider(_todayKey), (prev, next) {
      if (next.hasValue) {
        invalidateClassLiveMonitorSync();
        syncClassLiveMonitor(ref);
      }
    });

    ref.listen(autoSilentDuringClassProvider, (_, __) {
      invalidateClassLiveMonitorSync();
      syncClassLiveMonitor(ref, force: true);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
