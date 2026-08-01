import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/features/timetable/providers/weekly_resolved_provider.dart';
import 'package:vit_nextclass/features/timetable/presentation/widgets/day_schedule_list.dart';

class WeeklyTimetableScreen extends ConsumerStatefulWidget {
  const WeeklyTimetableScreen({super.key});

  @override
  ConsumerState<WeeklyTimetableScreen> createState() => _WeeklyTimetableScreenState();
}

class _WeeklyTimetableScreenState extends ConsumerState<WeeklyTimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    int initialIndex = DateTime.now().weekday - 1;
    if (initialIndex > 5) initialIndex = 0;

    _tabController = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _dateForDayIndex(int dayOfWeek) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day + (dayOfWeek - 1));
  }

  @override
  Widget build(BuildContext context) {
    final weeklyAsync = ref.watch(weeklyResolvedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Timetable'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _days.map((day) => Tab(text: day)).toList(),
          indicatorSize: TabBarIndicatorSize.tab,
        ),
      ),
      body: weeklyAsync.when(
        data: (weekSchedule) {
          return TabBarView(
            controller: _tabController,
            children: [
              for (int day = 1; day <= 6; day++)
                DayScheduleList(
                  classes: weekSchedule[day] ?? [],
                  date: _dateForDayIndex(day),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Something went wrong. Pull down to retry.')),
      ),
    );
  }
}
