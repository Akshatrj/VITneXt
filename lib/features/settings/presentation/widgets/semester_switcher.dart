import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';
import 'package:vit_nextclass/features/settings/providers/settings_provider.dart';

class SemesterSwitcher extends ConsumerWidget {
  const SemesterSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSemesterAsync = ref.watch(activeSemesterProvider);
    final allSemestersAsync = ref.watch(allSemestersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Manage Semesters',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
            TextButton.icon(
              onPressed: () => _showCreateSemesterDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create New'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        allSemestersAsync.when(
          data: (semesters) {
            if (semesters.isEmpty) {
              return const Text('No semesters found');
            }
            final activeId = activeSemesterAsync.whenOrNull(
              data: (active) => active?.id,
            );
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: semesters.length,
              itemBuilder: (context, index) {
                final semester = semesters[index];
                final isActive = activeId == semester.id;

                return RadioListTile<String>(
                  title: Text(semester.name),
                  subtitle: Text(isActive ? 'Active Semester' : 'Tap to switch'),
                  value: semester.id,
                  groupValue: activeId,
                  onChanged: activeSemesterAsync.hasError
                      ? null
                      : (value) async {
                    if (value != null && !isActive) {
                      await ref.read(localStorageProvider).setActiveSemester(value);
                      AppLog.instance.info('semester', 'switched', data: {
                        'semesterId': value,
                        'name': semester.name,
                      });
                      ref.invalidate(activeSemesterProvider);
                      ref.invalidate(coursesProvider);
                      ref.invalidate(overridesProvider);
                      ref.invalidate(holidaysProvider);
                      invalidateTodaySchedule(ref);
                      await refreshWidgetSchedule(ref);
                    }
                  },
                  secondary: !isActive
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteSemester(context, ref, semester),
                        )
                      : const Icon(Icons.check_circle, color: Colors.green),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Error loading semesters: $error'),
        ),
      ],
    );
  }

  Future<void> _showCreateSemesterDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Semester'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Semester Name',
            hintText: 'e.g., Fall 2024',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final newSemester = Semester(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result,
      );
      
      await ref.read(localStorageProvider).saveSemester(newSemester);
      ref.invalidate(allSemestersProvider);
      
      // Auto-switch to newly created semester if no active semester
      final active = await ref.read(activeSemesterProvider.future);
      if (active == null) {
        await ref.read(localStorageProvider).setActiveSemester(newSemester.id);
        ref.invalidate(activeSemesterProvider);
      }
    }
  }

  Future<void> _deleteSemester(BuildContext context, WidgetRef ref, Semester semester) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Semester'),
        content: Text('Are you sure you want to delete ${semester.name}? All associated courses and data will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(localStorageProvider).deleteSemester(semester.id);
      ref.invalidate(allSemestersProvider);
      ref.invalidate(activeSemesterProvider);
      ref.invalidate(coursesProvider);
      ref.invalidate(overridesProvider);
      ref.invalidate(holidaysProvider);
      invalidateTodaySchedule(ref);
      await refreshWidgetSchedule(ref);
    }
  }
}
