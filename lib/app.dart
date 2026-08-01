import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/theme/app_theme.dart';
import 'package:vit_nextclass/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vit_nextclass/widgets/app_scaffold.dart';
import 'package:vit_nextclass/widgets/class_focus_handler.dart';
import 'package:vit_nextclass/widgets/widget_action_handler.dart';

class VITNextClassApp extends ConsumerWidget {
  const VITNextClassApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboardingAsync = ref.watch(onboardingCompleteProvider);

    return MaterialApp(
      title: 'VIT NextClass',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: onboardingAsync.when(
        data: (isComplete) {
          if (!isComplete) {
            return const OnboardingScreen();
          }
          return const ClassFocusHandler(
            child: WidgetActionHandler(child: AppScaffold()),
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const ClassFocusHandler(
          child: WidgetActionHandler(child: AppScaffold()),
        ),
      ),
    );
  }
}
