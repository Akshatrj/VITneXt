import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vit_nextclass/core/models/semester.dart';
import 'package:vit_nextclass/core/database/local_storage.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';

class SemesterStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const SemesterStep({
    super.key,
    required this.onNext,
  });

  @override
  ConsumerState<SemesterStep> createState() => _SemesterStepState();
}

class _SemesterStepState extends ConsumerState<SemesterStep> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validate);
  }

  void _validate() {
    final isValid = _controller.text.trim().isNotEmpty;
    if (isValid != _isValid) {
      setState(() {
        _isValid = isValid;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSemester() async {
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _controller.text.trim();
      final semester = Semester(
        id: const Uuid().v4(),
        name: name,
        isActive: true,
      );

      final localStorage = ref.read(localStorageProvider);
      
      // If there's an existing active semester, we might need to deactivate it, 
      // but LocalStorage might handle it or we can just save it. 
      // The prompt asks to create and save it as active.
      // Usually saving a new one as active is fine.
      await localStorage.saveSemester(semester);
      
      // We might need to refresh the provider
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
