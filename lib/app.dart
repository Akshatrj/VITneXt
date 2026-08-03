import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/app_log.dart';
import 'package:vit_nextclass/core/services/crash_reporter.dart';
import 'package:vit_nextclass/core/services/widget_health_monitor.dart';
import 'package:vit_nextclass/core/theme/app_theme.dart';
import 'package:vit_nextclass/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vit_nextclass/widgets/app_scaffold.dart';
import 'package:vit_nextclass/widgets/notification_permission_prompt.dart';
import 'package:vit_nextclass/widgets/widget_action_handler.dart';

class VITNextClassApp extends ConsumerWidget {
  const VITNextClassApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboardingAsync = ref.watch(onboardingCompleteProvider);

    ref.listen(activeSemesterProvider, (prev, next) {
      next.whenData((sem) {
        CrashReporter.instance.setCustomKeys({
          'currentSemester': sem?.name ?? 'none',
          'currentSemesterId': sem?.id ?? 'none',
        });
        AppLog.instance.info('semester', 'activeSemester changed', data: {
          'name': sem?.name,
          'id': sem?.id,
        });
      });
    });

    return MaterialApp(
      title: 'VITneXt',
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_NavLogger()],
      home: AppLifecycleLogger(
        onResumed: () {
          WidgetHealthMonitor.instance.checkAndHeal(ref);
        },
        child: onboardingAsync.when(
          data: (isComplete) {
            AppLog.instance.info('nav', 'route home', data: {
              'onboardingComplete': isComplete,
            });
            if (!isComplete) {
              return const OnboardingScreen();
            }
            return const NotificationPermissionPrompt(
              child: WidgetActionHandler(child: AppScaffold()),
            );
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) {
            AppLog.instance.error('nav', 'onboarding provider error', error: e, stackTrace: st);
            return const NotificationPermissionPrompt(
              child: WidgetActionHandler(child: AppScaffold()),
            );
          },
        ),
      ),
    );
  }
}

class _NavLogger extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLog.instance.info('nav', 'push', data: {
      'route': route.settings.name ?? route.runtimeType.toString(),
      'prev': previousRoute?.settings.name ?? previousRoute?.runtimeType.toString(),
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppLog.instance.info('nav', 'pop', data: {
      'route': route.settings.name ?? route.runtimeType.toString(),
      'prev': previousRoute?.settings.name ?? previousRoute?.runtimeType.toString(),
    });
  }
}
