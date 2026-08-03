import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/constants/buildings.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/features/manage/presentation/widgets/add_course_sheet.dart';

class CourseStep extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback? onBack;

  const CourseStep({
    super.key,
    required this.onComplete,
    this.onBack,
  });

  @override
  ConsumerState<CourseStep> createState() => _CourseStepState();
}

class _CourseStepState extends ConsumerState<CourseStep> {
  List<Course> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final storage = ref.read(localStorageProvider);
    final semester = await storage.getActiveSemester();
    List<Course> courses = [];
    if (semester != null) {
      courses = await storage.getCourses(semester.id);
    }
    
    if (mounted) {
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    }
  }

  void _showAddCourseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const AddCourseSheet(),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
            )
          else
            const SizedBox(height: 16),
          Text(
            'Add your courses',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You can always add more later',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          Expanded(
            child: _courses.isEmpty
                ? _buildEmptyState(theme, colorScheme)
                : _buildCourseList(),
          ),
          
          const SizedBox(height: 16),
          
          if (_courses.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _showAddCourseSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add Another Course'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
          const SizedBox(height: 24),
          
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: widget.onComplete,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onComplete,
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 64,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No courses added yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            onPressed: _showAddCourseSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Course'),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    return ListView.builder(
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        final buildingColor = Buildings.getColor(course.building);
        
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: buildingColor.withValues(alpha: 0.5), width: 1),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: buildingColor.withValues(alpha: 0.2),
              child: Text(
                course.building,
                style: TextStyle(color: buildingColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              course.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${course.code} | ${course.ffcsSlot}\n${course.classroomFull}'),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
