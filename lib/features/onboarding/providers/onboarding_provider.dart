import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory onboarding wizard state — survives back navigation within the flow.
class OnboardingState {
  final String semesterName;
  final String? semesterId;

  const OnboardingState({
    this.semesterName = '',
    this.semesterId,
  });

  OnboardingState copyWith({
    String? semesterName,
    String? semesterId,
    bool clearSemesterId = false,
  }) {
    return OnboardingState(
      semesterName: semesterName ?? this.semesterName,
      semesterId: clearSemesterId ? null : (semesterId ?? this.semesterId),
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void setSemesterName(String name) {
    state = state.copyWith(semesterName: name);
  }

  void setSemesterId(String id) {
    state = state.copyWith(semesterId: id);
  }

  void reset() {
    state = const OnboardingState();
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
