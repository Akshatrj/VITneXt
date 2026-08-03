import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/reliability_bridge.dart';
import 'package:vit_nextclass/features/settings/presentation/debug_logs_screen.dart';

final developerModeProvider =
    StateNotifierProvider<DeveloperModeNotifier, bool>((ref) {
  return DeveloperModeNotifier();
});

class DeveloperModeNotifier extends StateNotifier<bool> {
  DeveloperModeNotifier() : super(kDebugMode) {
    _load();
  }

  Future<void> _load() async {
    if (kDebugMode) {
      state = true;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('developer_mode') ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('developer_mode', enabled);
    AppLog.instance.info('settings', 'developer_mode=$enabled');
  }
}

class ReliabilitySettingsCard extends ConsumerStatefulWidget {
  const ReliabilitySettingsCard({super.key});

  @override
  ConsumerState<ReliabilitySettingsCard> createState() =>
      _ReliabilitySettingsCardState();
}

class _ReliabilitySettingsCardState
    extends ConsumerState<ReliabilitySettingsCard> {
  bool? _ignoringBattery;
  bool _loadingBattery = true;

  @override
  void initState() {
    super.initState();
    _refreshBattery();
  }

  Future<void> _refreshBattery() async {
    setState(() => _loadingBattery = true);
    final ignoring = await ReliabilityBridge.isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _ignoringBattery = ignoring;
      _loadingBattery = false;
    });
  }

  Future<void> _showBatteryExplanation() async {
    AppLog.instance.info('battery', 'Showing battery explanation dialog');
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Improve background reliability'),
        content: const Text(
          'Some phones (OnePlus, Xiaomi, Vivo, Oppo, Realme, Samsung) pause apps '
          'to save battery. That can delay class reminders and stop the home-screen '
          'widget from refreshing.\n\n'
          'Excluding VITneXt from battery optimization is optional, but it usually '
          'makes the widget and reminders more reliable. You can change this anytime '
          'in system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'settings'),
            child: const Text('Open settings'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'request'),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (action == 'settings') {
      await ReliabilityBridge.openBatteryOptimizationSettings();
    } else if (action == 'request') {
      await ReliabilityBridge.requestIgnoreBatteryOptimizations();
    }
    await _refreshBattery();
  }

  @override
  Widget build(BuildContext context) {
    final developerMode = ref.watch(developerModeProvider);

    return Card(
      elevation: 0,
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              (_ignoringBattery ?? false)
                  ? Icons.battery_charging_full
                  : Icons.battery_alert,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Battery optimization'),
            subtitle: Text(
              _loadingBattery
                  ? 'Checking…'
                  : (_ignoringBattery == true
                      ? 'VITneXt is excluded from battery optimization'
                      : 'May be limited by the system — tap to review'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showBatteryExplanation,
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.developer_mode),
            title: const Text('Developer mode'),
            subtitle: Text(
              kDebugMode
                  ? 'Always on in debug builds'
                  : 'Show debug logs and diagnostics',
            ),
            value: developerMode,
            onChanged: kDebugMode
                ? null
                : (v) => ref.read(developerModeProvider.notifier).setEnabled(v),
          ),
          if (developerMode) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Debug logs'),
              subtitle: const Text('View, share, and clear diagnostic logs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                AppLog.instance.info('nav', 'Open DebugLogsScreen');
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebugLogsScreen()),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
