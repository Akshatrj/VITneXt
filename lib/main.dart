import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/app.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/services/class_live_sync.dart';
import 'package:vit_nextclass/core/services/notification_scheduler.dart';
import 'package:vit_nextclass/core/services/schedule_resolver.dart';
import 'package:vit_nextclass/core/services/widget_bridge.dart';

Future<void> _refreshWidgetOnStartup() async {
  final storage = LocalStorage();
  final resolver = ScheduleResolver(storage);
  final schedule = await resolver.resolveSchedule(DateTime.now());
  ResolvedClass? current;
  ResolvedClass? next;
  for (final cls in schedule) {
    if (cls.status == ClassStatus.current) current = cls;
    if (cls.status == ClassStatus.next) next = cls;
  }
  await WidgetBridge.updateWidget(currentClass: current, nextClass: next);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage().init();
  await _refreshWidgetOnStartup();
  await rescheduleClassNotificationsOnStartup();
  await syncClassLiveMonitorOnStartup();
  runApp(const ProviderScope(child: VITNextClassApp()));
}
