import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/class_focus_bridge.dart';
import 'package:vit_nextclass/core/services/notification_scheduler.dart';
import 'package:vit_nextclass/core/services/timetable_share_service.dart';
import 'package:vit_nextclass/features/settings/presentation/widgets/theme_selector.dart';
import 'package:vit_nextclass/features/settings/presentation/widgets/semester_switcher.dart';
import 'package:vit_nextclass/features/settings/presentation/widgets/about_section.dart';
import 'package:vit_nextclass/features/settings/providers/settings_provider.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';
import 'package:vit_nextclass/features/onboarding/presentation/onboarding_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          _buildSectionHeader(context, 'Appearance'),
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: ThemeSelector(),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader(context, 'Notifications'),
          _buildNotificationsSection(context, ref),
          const SizedBox(height: 16),

          _buildSectionHeader(context, 'Class Focus'),
          _buildClassFocusSection(context, ref),
          const SizedBox(height: 16),

          _buildSectionHeader(context, 'Home Screen Widget'),
          _buildWidgetSection(context),
          const SizedBox(height: 16),

          _buildSectionHeader(context, 'Semester'),
          const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: SemesterSwitcher(),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader(context, 'Data Management'),
          _buildDataSection(context, ref),
          const SizedBox(height: 16),

          _buildSectionHeader(context, 'Reset'),
          _buildResetSection(context, ref),
          const SizedBox(height: 16),

          _buildSectionHeader(context, 'About'),
          const AboutSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(notificationMinutesProvider);

    return Card(
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.primary),
            title: const Text('Notify before class'),
            trailing: DropdownButton<int>(
              value: minutes,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Off')),
                DropdownMenuItem(value: 5, child: Text('5 min')),
                DropdownMenuItem(value: 10, child: Text('10 min')),
                DropdownMenuItem(value: 15, child: Text('15 min')),
                DropdownMenuItem(value: 30, child: Text('30 min')),
              ],
              onChanged: (int? newValue) async {
                if (newValue != null) {
                  if (newValue > 0) {
                    final status = await Permission.notification.request();
                    if (status.isGranted) {
                      await ref.read(notificationMinutesProvider.notifier).setMinutes(newValue);
                      await rescheduleClassNotifications(ref);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notification permission denied')),
                      );
                      // Fallback to Off if denied
                      ref.read(notificationMinutesProvider.notifier).setMinutes(0);
                      await rescheduleClassNotifications(ref);
                    }
                  } else {
                    await ref.read(notificationMinutesProvider.notifier).setMinutes(0);
                    await rescheduleClassNotifications(ref);
                  }
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Text(
              'Notifications are scheduled locally, no internet needed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassFocusSection(BuildContext context, WidgetRef ref) {
    final liveStatus = ref.watch(liveClassStatusProvider);
    final autoSilent = ref.watch(autoSilentDuringClassProvider);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.circle_notifications_outlined, color: theme.colorScheme.primary),
            title: const Text('Live class status'),
            subtitle: const Text(
              'Shows your ongoing class on the status bar / notification area (like Dynamic Island on supported devices)',
            ),
            trailing: Switch(
              value: liveStatus,
              onChanged: (value) async {
                if (value) {
                  final status = await Permission.notification.request();
                  if (!status.isGranted) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification permission is required for live class status'),
                        ),
                      );
                    }
                    return;
                  }
                }
                await ref.read(liveClassStatusProvider.notifier).setEnabled(value);
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.vibration, color: theme.colorScheme.primary),
            title: const Text('Silent + vibrate during class'),
            subtitle: const Text(
              'Automatically switches to vibrate-only while a class is in progress, then restores your previous sound mode',
            ),
            trailing: Switch(
              value: autoSilent,
              onChanged: (value) async {
                if (value) {
                  final canModify = await ClassFocusBridge.canModifyRingerMode();
                  if (!canModify && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Could not change sound mode. Open sound settings to allow the app.',
                        ),
                        action: SnackBarAction(
                          label: 'Settings',
                          onPressed: () => ClassFocusBridge.openSoundSettings(),
                        ),
                      ),
                    );
                  }
                }
                await ref.read(autoSilentDuringClassProvider.notifier).setEnabled(value);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Runs offline with no network access. Only class times are stored in the native monitor; course names stay in the app. The foreground service runs during class (and briefly before class for live status), not all day — alarms wake it at start/end times to save battery.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetSection(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.widgets_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add the VIT NextClass widget to your home screen',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Long-press your home screen\n'
              '2. Tap Widgets\n'
              '3. Find VIT NextClass → add "Shows your current or next class"\n'
              '4. Tap widget to open app · "Cancel next class" marks it cancelled by teacher',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share Timetable'),
            subtitle: const Text('Share a text summary with friends'),
            onTap: () async {
              try {
                final service = TimetableShareService(ref.read(localStorageProvider));
                await service.shareTimetable();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Share failed: $e')),
                  );
                }
              }
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export Timetable'),
            subtitle: const Text('Save all your data to a JSON file'),
            onTap: () => _exportData(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import Timetable'),
            subtitle: const Text('Load data from a JSON file'),
            onTap: () => _importData(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildResetSection(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.delete_sweep, color: Theme.of(context).colorScheme.error),
            title: Text(
              'Reset Current Semester',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Deletes all courses and overrides'),
            onTap: () => _resetSemester(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.restart_alt, color: Theme.of(context).colorScheme.error),
            title: Text(
              'Reset App',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Re-run onboarding setup'),
            onTap: () => _resetApp(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(localStorageProvider);
    try {
      final data = await storage.exportAll();
      final jsonString = jsonEncode(data);

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/vit_nextclass_backup.json');
      await file.writeAsString(jsonString);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text('This will import data from the backup file in your app directory. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/vit_nextclass_backup.json');

      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No backup file found')),
          );
        }
        return;
      }

      final jsonString = await file.readAsString();
      final storage = ref.read(localStorageProvider);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      await storage.importAll(data);

      ref.invalidate(allSemestersProvider);
      ref.invalidate(activeSemesterProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import successful')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _resetSemester(BuildContext context, WidgetRef ref) async {
    final activeSemester = await ref.read(activeSemesterProvider.future);
    if (activeSemester == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active semester to reset')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Semester'),
        content: Text('Are you sure you want to delete all courses, overrides, and holidays for ${activeSemester.name}? This cannot be undone.'),
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
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final storage = ref.read(localStorageProvider);
      await storage.resetSemester(activeSemester.id);
      ref.invalidate(coursesProvider);
      ref.invalidate(overridesProvider);
      invalidateTodaySchedule(ref);
      await refreshWidgetSchedule(ref);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semester reset successful')),
        );
      }
    }
  }

  Future<void> _resetApp(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text('This will take you back to the onboarding screen. Your data will not be deleted, but you will need to complete the setup again.'),
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
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', false);
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false,
        );
      }
    }
  }
}
