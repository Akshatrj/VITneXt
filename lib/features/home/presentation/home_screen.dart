import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/home/presentation/widgets/dashboard_card.dart';
import 'package:vit_nextclass/features/home/presentation/widgets/today_schedule_slider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late PageController _pageController;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });

    final now = DateTime.now();
    DateTime newDate;
    if (index == 0) {
      newDate = now.subtract(const Duration(days: 1));
    } else if (index == 2) {
      newDate = now.add(const Duration(days: 1));
    } else {
      newDate = now;
    }

    Future.microtask(() {
      ref.read(selectedDateProvider.notifier).state = normalizeScheduleDate(newDate);
    });
  }

  Future<void> _markHolidayForDate(DateTime date) async {
    final day = normalizeScheduleDate(date);
    final isToday = day == normalizeScheduleDate(DateTime.now());

    final storage = ref.read(localStorageProvider);
    await storage.init();
    final semester = await storage.getActiveSemester();
    await storage.deleteHolidaysCoveringDate(day, semesterId: semester?.id);

    final holiday = Holiday(
      id: const Uuid().v4(),
      semesterId: semester?.id,
      startDate: day,
      endDate: day,
      label: 'Holiday',
      type: HolidayType.university,
      source: 'Manual',
    );

    await storage.saveHoliday(holiday);
    ref.invalidate(holidaysProvider);
    invalidateScheduleForDate(ref, day);
    invalidateTodaySchedule(ref);
    await refreshWidgetSchedule(ref);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isToday ? 'Today marked as holiday' : 'Tomorrow marked as holiday',
          ),
        ),
      );
    }
  }

  Future<void> _removeHoliday(Holiday holiday) async {
    final storage = ref.read(localStorageProvider);
    await storage.init();
    await storage.deleteHoliday(holiday.id);
    ref.invalidate(holidaysProvider);
    invalidateScheduleForDate(ref, holiday.startDate);
    invalidateTodaySchedule(ref);
    await refreshWidgetSchedule(ref);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final activeSemesterAsync = ref.watch(activeSemesterProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHeader(context, selectedDate, activeSemesterAsync),
            const SizedBox(height: 16),
            _buildDateTabs(),
            const SizedBox(height: 16),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildDayContent(
                    context,
                    ref,
                    normalizeScheduleDate(DateTime.now().subtract(const Duration(days: 1))),
                    showHolidayAction: false,
                    dayLabel: 'Yesterday',
                  ),
                  _buildDayContent(
                    context,
                    ref,
                    normalizeScheduleDate(DateTime.now()),
                    showHolidayAction: true,
                    dayLabel: 'Today',
                  ),
                  _buildDayContent(
                    context,
                    ref,
                    normalizeScheduleDate(DateTime.now().add(const Duration(days: 1))),
                    showHolidayAction: true,
                    dayLabel: 'Tomorrow',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidayAction(DateTime date, String dayLabel) {
    final holidayAsync = ref.watch(dayHolidayProvider(date));
    return holidayAsync.when(
      data: (holiday) {
        if (holiday != null) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.celebration,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$dayLabel is a holiday · ${holiday.label}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => _removeHoliday(holiday),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _markHolidayForDate(date),
              icon: const Icon(Icons.beach_access, size: 18),
              label: Text('Mark $dayLabel as Holiday'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDayContent(
    BuildContext context,
    WidgetRef ref,
    DateTime selectedDate, {
    required bool showHolidayAction,
    required String dayLabel,
  }) {
    final scheduleAsync = ref.watch(dayScheduleProvider(selectedDate));
    // Watch the tick so the dashboard rebuilds each minute, but always use a
    // fresh wall-clock time (stream values can be stale after resume).
    ref.watch(currentTimeProvider);
    final currentTime = DateTime.now();
    final tomorrowFirstAsync = ref.watch(tomorrowFirstClassProvider);
    final tomorrowHolidayAsync = ref.watch(tomorrowHolidayProvider);
    final todayHolidayAsync = ref.watch(dayHolidayProvider(selectedDate));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dayScheduleProvider(selectedDate));
        ref.invalidate(dayHolidayProvider(selectedDate));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHolidayAction) _buildHolidayAction(selectedDate, dayLabel),
            scheduleAsync.when(
              skipLoadingOnReload: true,
              data: (schedule) {
                return DashboardCard(
                  schedule: schedule,
                  currentTime: currentTime,
                  scheduleDate: selectedDate,
                  tomorrowFirstClass: tomorrowFirstAsync.value,
                  tomorrowHoliday: tomorrowHolidayAsync.value,
                  todayHoliday: todayHolidayAsync.value,
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (err, stack) => const Center(child: Text('Something went wrong. Pull down to retry.')),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "$dayLabel's Schedule",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            scheduleAsync.when(
              skipLoadingOnReload: true,
              data: (schedule) => TodayScheduleSlider(schedule: schedule, date: selectedDate),
              loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => const SizedBox(height: 180),
            ),
            const SizedBox(height: 40),
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(appNavIndexProvider.notifier).state = 1;
                },
                icon: const Icon(Icons.calendar_view_week),
                label: const Text('View Weekly Timetable'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DateTime selectedDate, AsyncValue activeSemesterAsync) {
    final theme = Theme.of(context);

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final dayName = days[selectedDate.weekday - 1];
    final monthName = months[selectedDate.month - 1];
    final dateStr = '${selectedDate.day} $monthName ${selectedDate.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          activeSemesterAsync.when(
            data: (semester) => Text(
              semester?.name ?? 'No Active Semester',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            loading: () => Text(
              'Loading...',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            error: (_, __) => Text(
              'No Active Semester',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dayName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            dateStr,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildDateTabItem('Yesterday', 0),
        _buildDateTabItem('Today', 1),
        _buildDateTabItem('Tomorrow', 2),
      ],
    );
  }

  Widget _buildDateTabItem(String text, int index) {
    final isSelected = _currentPage == index;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Column(
        children: [
          Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? theme.colorScheme.primary : Colors.grey,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 24,
              color: theme.colorScheme.primary,
            )
          else
            const SizedBox(height: 6),
        ],
      ),
    );
  }
}
