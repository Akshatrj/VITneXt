import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/home/presentation/widgets/dashboard_card.dart';
import 'package:vit_nextclass/features/home/presentation/widgets/today_schedule_slider.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/widgets/app_scaffold.dart';

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
                  ),
                  _buildDayContent(
                    context,
                    ref,
                    normalizeScheduleDate(DateTime.now()),
                  ),
                  _buildDayContent(
                    context,
                    ref,
                    normalizeScheduleDate(DateTime.now().add(const Duration(days: 1))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayContent(BuildContext context, WidgetRef ref, DateTime selectedDate) {
    final scheduleAsync = ref.watch(dayScheduleProvider(selectedDate));
    final currentTimeAsync = ref.watch(currentTimeProvider);
    final tomorrowFirstAsync = ref.watch(tomorrowFirstClassProvider);
    final tomorrowHolidayAsync = ref.watch(tomorrowHolidayProvider);

    final currentTime = currentTimeAsync.value ?? DateTime.now();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dayScheduleProvider(selectedDate));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Card
            scheduleAsync.when(
              data: (schedule) {
                return DashboardCard(
                  schedule: schedule,
                  currentTime: currentTime,
                  scheduleDate: selectedDate,
                  tomorrowFirstClass: tomorrowFirstAsync.value,
                  tomorrowHoliday: tomorrowHolidayAsync.value,
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (err, stack) => Center(child: Text('Something went wrong. Pull down to retry.')),
            ),
            
            const SizedBox(height: 32),
            
            // Today's Schedule Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Today's Schedule",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            scheduleAsync.when(
              data: (schedule) => TodayScheduleSlider(schedule: schedule, date: selectedDate),
              loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
              error: (err, stack) => const SizedBox(height: 180),
            ),
            
            const SizedBox(height: 40),
            
            // Bottom Button
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
