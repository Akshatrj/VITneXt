import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';

const _presetReasons = [
  'Cancelled by teacher',
  'Faculty on leave',
  'Room unavailable',
  'College event / holiday',
  'Other',
];

/// Opens a bottom sheet to cancel or restore a class for a specific date.
void showClassActionSheet(
  BuildContext context,
  WidgetRef ref,
  ResolvedClass cls,
  DateTime date,
) {
  if (cls.linkedCourseId == null) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => CancelClassSheet(cls: cls, date: date),
  );
}

class CancelClassSheet extends ConsumerStatefulWidget {
  final ResolvedClass cls;
  final DateTime date;

  const CancelClassSheet({
    super.key,
    required this.cls,
    required this.date,
  });

  @override
  ConsumerState<CancelClassSheet> createState() => _CancelClassSheetState();
}

class _CancelClassSheetState extends ConsumerState<CancelClassSheet> {
  String _selectedReason = _presetReasons.first;
  final TextEditingController _customReasonController = TextEditingController();
  bool _isLoading = false;

  bool get _isCancelled => widget.cls.status == ClassStatus.cancelled;
  bool get _canCancel =>
      !_isCancelled &&
      widget.cls.status != ClassStatus.completed &&
      widget.cls.status != ClassStatus.extra;

  @override
  void initState() {
    super.initState();
    _initReasonFromClass();
  }

  void _initReasonFromClass() {
    final reason = widget.cls.overrideReason;
    if (reason != null && reason.isNotEmpty) {
      if (_presetReasons.contains(reason)) {
        _selectedReason = reason;
      } else {
        _selectedReason = 'Other';
        _customReasonController.text = reason;
      }
    }
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  String get _reasonText {
    if (_selectedReason == 'Other') {
      return _customReasonController.text.trim();
    }
    return _selectedReason;
  }

  Future<ScheduleOverride?> _findExistingCancellation() async {
    final storage = ref.read(localStorageProvider);
    final overrides = await storage.getOverridesForDate(widget.date);
    for (final override in overrides) {
      if (override.type == OverrideType.cancelled &&
          override.linkedCourseId == widget.cls.linkedCourseId) {
        return override;
      }
    }
    return null;
  }

  Future<void> _cancelClass() async {
    if (widget.cls.linkedCourseId == null) return;

    final reason = _reasonText;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for cancellation.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = ref.read(localStorageProvider);
      final existing = await _findExistingCancellation();

      final override = ScheduleOverride(
        id: existing?.id ?? const Uuid().v4(),
        date: widget.date,
        type: OverrideType.cancelled,
        linkedCourseId: widget.cls.linkedCourseId,
        reason: reason,
      );

      await storage.saveOverride(override);
      ref.invalidate(overridesProvider);
      invalidateScheduleForDate(ref, widget.date);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.cls.courseCode} marked as cancelled')),
        );
      }

      try {
        await refreshWidgetSchedule(ref);
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel class: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreClass() async {
    setState(() => _isLoading = true);

    try {
      final existing = await _findExistingCancellation();
      if (existing == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final storage = ref.read(localStorageProvider);
      await storage.deleteOverride(existing.id);
      ref.invalidate(overridesProvider);
      invalidateScheduleForDate(ref, widget.date);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.cls.courseCode} restored to schedule')),
        );
      }

      try {
        await refreshWidgetSchedule(ref);
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore class: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('EEEE, MMMM d').format(widget.date);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isCancelled ? 'Class Cancelled' : 'Cancel Class',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              CloseButton(onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.cls.courseCode,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(widget.cls.courseName),
                  const SizedBox(height: 8),
                  Text(
                    '$dateLabel · ${widget.cls.startTimeFormatted} – ${widget.cls.endTimeFormatted}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    widget.cls.classroom,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_isCancelled && widget.cls.overrideReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Reason: ${widget.cls.overrideReason}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_isCancelled) ...[
            Text(
              'This class is marked cancelled for $dateLabel. Update the reason or restore if the class is back on.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Reason', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetReasons.map((reason) {
                final selected = _selectedReason == reason;
                return ChoiceChip(
                  label: Text(reason),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedReason = reason),
                );
              }).toList(),
            ),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customReasonController,
                decoration: const InputDecoration(
                  labelText: 'Custom reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isLoading ? null : _cancelClass,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit),
              label: const Text('Update Reason'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _restoreClass,
              icon: const Icon(Icons.restore),
              label: const Text('Restore Class'),
            ),
          ] else if (_canCancel) ...[
            Text(
              'Mark this class as cancelled (e.g. teacher cancelled). It will only affect $dateLabel.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Reason', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetReasons.map((reason) {
                final selected = _selectedReason == reason;
                return ChoiceChip(
                  label: Text(reason),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedReason = reason),
                );
              }).toList(),
            ),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customReasonController,
                decoration: const InputDecoration(
                  labelText: 'Custom reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isLoading ? null : _cancelClass,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.event_busy),
              label: const Text('Mark as Cancelled'),
            ),
          ] else ...[
            Text(
              'This class has already finished and cannot be cancelled.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
