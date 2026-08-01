import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';

class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.palette),
            const SizedBox(width: 16),
            Expanded(
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.wb_sunny),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.nights_stay),
                    label: Text('Dark'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.smartphone),
                    label: Text('System'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
