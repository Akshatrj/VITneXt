import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/reliability_bridge.dart';
import 'package:vit_nextclass/core/services/widget_health_monitor.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';

class DebugLogsScreen extends ConsumerStatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  ConsumerState<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends ConsumerState<DebugLogsScreen> {
  String _text = 'Loading…';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
    AppLog.instance.stream.listen((_) {
      if (mounted) _reload(silent: true);
    });
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) setState(() => _busy = true);
    final content = await AppLog.instance.readAll();
    if (!mounted) return;
    setState(() {
      _text = content.trim().isEmpty ? '(no logs yet)' : content;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keys = AppLog.instance.customKeys;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Share logs',
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await AppLog.instance.share();
                    if (mounted) setState(() => _busy = false);
                  },
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: Column(
        children: [
          if (keys.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: keys.entries
                      .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
                      .toList(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await WidgetHealthMonitor.instance.checkAndHeal(ref);
                            await ReliabilityBridge.forceWidgetRefresh();
                            await refreshWidgetSchedule(ref);
                            await _reload();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Widget heal requested')),
                              );
                            }
                          },
                    child: const Text('Heal widget'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            await AppLog.instance.clear();
                            await _reload();
                          },
                    child: const Text('Clear logs'),
                  ),
                ),
              ],
            ),
          ),
          if (!kDebugMode)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Developer option enabled. Logs stay on-device until you share them.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _busy
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      _text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
