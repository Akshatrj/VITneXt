import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/services/notification_service.dart';
import 'package:vit_nextclass/core/services/schedule_resolver.dart';
import 'package:vit_nextclass/core/utils/prefs_utils.dart';

final localStorageProvider = Provider<LocalStorage>((ref) => LocalStorage());

final scheduleResolverProvider = Provider<ScheduleResolver>((ref) {
  return ScheduleResolver(ref.read(localStorageProvider));
});

final activeSemesterProvider = FutureProvider<Semester?>((ref) async {
  final storage = ref.read(localStorageProvider);
  await storage.init();
  return storage.getActiveSemester();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode') ?? 'system';
    state = ThemeMode.values.firstWhere(
      (e) => e.name == modeStr,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class NotificationMinutesNotifier extends StateNotifier<int> {
  NotificationMinutesNotifier() : super(0) {
    _loadMinutes();
  }

  Future<void> _loadMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt('notification_minutes') ?? 0;
  }

  Future<void> setMinutes(int minutes) async {
    state = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_minutes', minutes);
    if (minutes <= 0) {
      await NotificationService.instance.cancelAll();
    }
  }
}

final notificationMinutesProvider = StateNotifierProvider<NotificationMinutesNotifier, int>((ref) {
  return NotificationMinutesNotifier();
});

class AutoSilentDuringClassNotifier extends StateNotifier<bool> {
  AutoSilentDuringClassNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = readPrefBool(prefs, 'auto_silent_during_class');
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_silent_during_class', enabled);
  }
}

final autoSilentDuringClassProvider =
    StateNotifierProvider<AutoSilentDuringClassNotifier, bool>((ref) {
  return AutoSilentDuringClassNotifier();
});

final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 5));
    return prefs.getBool('onboarding_complete') ?? false;
  } catch (_) {
    // Never hang on splash if prefs are slow/unavailable after process death.
    return true;
  }
});

final appNavIndexProvider = StateProvider<int>((ref) => 0);

