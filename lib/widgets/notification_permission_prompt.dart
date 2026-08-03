import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/services/notification_service.dart';

/// One-time prompt for notification permission for users who skipped onboarding dialog.
class NotificationPermissionPrompt extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationPermissionPrompt({super.key, required this.child});

  @override
  ConsumerState<NotificationPermissionPrompt> createState() =>
      _NotificationPermissionPromptState();
}

class _NotificationPermissionPromptState
    extends ConsumerState<NotificationPermissionPrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  Future<void> _maybeAsk() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notification_permission_prompted') == true) return;

    final status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) {
      await prefs.setBool('notification_permission_prompted', true);
      return;
    }

    if (!mounted) return;
    final shouldAsk = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable notifications?'),
        content: const Text(
          'Allow notifications so VITneXt can remind you before class.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    await prefs.setBool('notification_permission_prompted', true);
    if (shouldAsk == true) {
      await NotificationService.instance.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
