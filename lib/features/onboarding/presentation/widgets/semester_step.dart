import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/features/onboarding/providers/onboarding_provider.dart';

class SemesterStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback? onBack;

  const SemesterStep({
    super.key,
    required this.onNext,
    this.onBack,
  });

  @override
  ConsumerState<SemesterStep> createState() => _SemesterStepState();
}

class _SemesterStepState extends ConsumerState<SemesterStep>
    with AutomaticKeepAliveClientMixin {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _isValid = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _restoreFromState();
  }

  void _restoreFromState() {
    final onboarding = ref.read(onboardingProvider);
    if (onboarding.semesterName.isNotEmpty) {
      _controller.text = onboarding.semesterName;
      _isValid = true;
      return;
    }

  WidgetsBinding.instance.addPostFrameCallback((_) async {
      final storage = ref.read(localStorageProvider);
      final active = await storage.getActiveSemester();
      if (!mounted || active == null) return;
      ref.read(onboardingProvider.notifier).setSemesterId(active.id);
      ref.read(onboardingProvider.notifier).setSemesterName(active.name);
      _controller.text = active.name;
      setState(() => _isValid = active.name.trim().isNotEmpty);
    });
  }

  void _onTextChanged() {
    final name = _controller.text;
    ref.read(onboardingProvider.notifier).setSemesterName(name);
    final isValid = name.trim().isNotEmpty;
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSemester() async {
    if (!_isValid) return;

    setState(() => _isLoading = true);

    try {
      final name = _controller.text.trim();
      final localStorage = ref.read(localStorageProvider);
      final onboarding = ref.read(onboardingProvider);
      final existingId = onboarding.semesterId;

      Semester semester;
      if (existingId != null) {
        final semesters = await localStorage.getSemesters();
        Semester? existing;
        for (final s in semesters) {
          if (s.id == existingId) {
            existing = s;
            break;
          }
        }
        semester = (existing ?? Semester(id: existingId, name: name, isActive: true))
            .copyWith(name: name, isActive: true);
      } else {
        semester = Semester(
          id: const Uuid().v4(),
          name: name,
          isActive: true,
        );
        ref.read(onboardingProvider.notifier).setSemesterId(semester.id);
      }

      ref.read(onboardingProvider.notifier).setSemesterName(name);
      await localStorage.saveSemester(semester);
      await localStorage.setActiveSemester(semester.id);
      ref.invalidate(activeSemesterProvider);

      widget.onNext();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create semester: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
            ),
          const Spacer(flex: 1),
          Icon(
            Icons.date_range_rounded,
            size: 64,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 32),
          Text(
            'Name your semester',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'e.g. "Fall 2025" or "Semester 5"',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Semester Name',
              hintText: 'Enter name...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              prefixIcon: const Icon(Icons.school_rounded),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _saveSemester(),
            enabled: !_isLoading,
          ),
          const Spacer(flex: 2),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _isValid && !_isLoading ? _saveSemester : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
