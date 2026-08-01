import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';
import 'package:vit_nextclass/features/manage/presentation/widgets/course_list.dart';
import 'package:vit_nextclass/features/manage/presentation/widgets/add_course_sheet.dart';
import 'package:vit_nextclass/features/manage/presentation/widgets/add_override_sheet.dart';
import 'package:vit_nextclass/features/manage/presentation/widgets/add_holiday_sheet.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';

class ManageScreen extends ConsumerStatefulWidget {
  const ManageScreen({super.key});

  @override
  ConsumerState<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends ConsumerState<ManageScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddCourseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const AddCourseSheet(),
    );
  }

  void _showAddOverrideSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const AddOverrideSheet(),
    );
  }

  void _showAddHolidaySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const AddHolidaySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Timetable'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Courses'),
            Tab(text: 'Overrides'),
            Tab(text: 'Holidays'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const CourseList(),
          _buildOverridesTab(),
          _buildHolidaysTab(),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    switch (_tabController.index) {
      case 0:
        return FloatingActionButton.extended(
          onPressed: _showAddCourseSheet,
          icon: const Icon(Icons.add),
          label: const Text('Add Course'),
        );
      case 1:
        return FloatingActionButton.extended(
          onPressed: _showAddOverrideSheet,
          icon: const Icon(Icons.add),
          label: const Text('Add Override'),
        );
      case 2:
        return FloatingActionButton.extended(
          onPressed: _showAddHolidaySheet,
          icon: const Icon(Icons.add),
          label: const Text('Add Holiday'),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverridesTab() {
    final overridesAsync = ref.watch(overridesProvider);

    return overridesAsync.when(
      data: (overrides) {
        if (overrides.isEmpty) {
          return _buildEmptyState('No upcoming schedule overrides.', Icons.event_busy);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, top: 8),
          itemCount: overrides.length,
          itemBuilder: (context, index) {
            final override = overrides[index];
            return Dismissible(
              key: ValueKey(override.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
              ),
              onDismissed: (_) async {
                final storage = ref.read(localStorageProvider);
                await storage.deleteOverride(override.id);
                ref.invalidate(overridesProvider);
                invalidateTodaySchedule(ref);
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildOverrideBadge(override.type),
                          Text(
                            DateFormat('EEE, MMM d, yyyy').format(override.date),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildOverrideContent(override),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Something went wrong. Pull down to retry.')),
    );
  }

  Widget _buildOverrideBadge(OverrideType type) {
    Color color;
    String label;
    switch (type) {
      case OverrideType.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
      case OverrideType.extra:
        color = Colors.green;
        label = 'Extra Class';
        break;
      case OverrideType.modified:
        color = Colors.orange;
        label = 'Modified';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOverrideContent(ScheduleOverride override) {
    final theme = Theme.of(context).textTheme;
    
    // For cancelled and modified, we ideally want to show the original course name.
    // For simplicity, we just display the linkedCourseId if available.
    // Real implementation would look up the course in coursesProvider.
    final courses = ref.read(coursesProvider).valueOrNull ?? [];
    final course = courses.where((c) => c.id == override.linkedCourseId).firstOrNull;
    final courseTitle = override.extraCourseName ?? course?.name ?? override.linkedCourseId ?? 'Unknown Course';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(courseTitle, style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        if (override.type == OverrideType.modified || override.type == OverrideType.extra) ...[
          const SizedBox(height: 4),
          if (override.overrideStartHour != null)
            Text('Time: ${TimeOfDay(hour: override.overrideStartHour!, minute: override.overrideStartMinute!).format(context)} - ${TimeOfDay(hour: override.overrideEndHour!, minute: override.overrideEndMinute!).format(context)}'),
          if (override.overrideClassroom != null)
            Text('Room: ${override.overrideClassroom}'),
        ],
        if (override.reason != null && override.reason!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Reason: ${override.reason}', style: theme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }

  Widget _buildHolidaysTab() {
    final holidaysAsync = ref.watch(holidaysProvider);

    return holidaysAsync.when(
      data: (holidays) {
        if (holidays.isEmpty) {
          return _buildEmptyState('No holidays configured.', Icons.beach_access);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, top: 8),
          itemCount: holidays.length,
          itemBuilder: (context, index) {
            final holiday = holidays[index];
            return Dismissible(
              key: ValueKey(holiday.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
              ),
              onDismissed: (_) async {
                final storage = ref.read(localStorageProvider);
                await storage.deleteHoliday(holiday.id);
                ref.invalidate(holidaysProvider);
                invalidateTodaySchedule(ref);
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.celebration),
                  ),
                  title: Text(holiday.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(holiday.date)),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Something went wrong. Pull down to retry.')),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}
