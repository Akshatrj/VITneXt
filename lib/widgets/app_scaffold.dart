import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/features/home/presentation/home_screen.dart';
import 'package:vit_nextclass/features/timetable/presentation/weekly_timetable_screen.dart';
import 'package:vit_nextclass/features/calendar/presentation/calendar_screen.dart';
import 'package:vit_nextclass/features/manage/presentation/manage_screen.dart';
import 'package:vit_nextclass/features/settings/presentation/settings_screen.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/app_log.dart';

class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({super.key});

  static AppScaffoldState? of(BuildContext context) {
    return context.findAncestorStateOfType<AppScaffoldState>();
  }

  @override
  ConsumerState<AppScaffold> createState() => AppScaffoldState();
}

class AppScaffoldState extends ConsumerState<AppScaffold> {
  void switchTab(int index) {
    ref.read(appNavIndexProvider.notifier).state = index;
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    WeeklyTimetableScreen(),
    CalendarScreen(),
    ManageScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(appNavIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          AppLog.instance.info('nav', 'tab selected', data: {'index': index});
          ref.read(appNavIndexProvider.notifier).state = index;
        },
        animationDuration: const Duration(milliseconds: 400),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week_rounded),
            label: 'Weekly',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_calendar_outlined),
            selectedIcon: Icon(Icons.edit_calendar_rounded),
            label: 'Manage',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
