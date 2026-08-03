import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';

class AddHolidaySheet extends ConsumerStatefulWidget {
  const AddHolidaySheet({super.key, this.existing, this.initialDate});

  final Holiday? existing;
  final DateTime? initialDate;

  @override
  ConsumerState<AddHolidaySheet> createState() => _AddHolidaySheetState();
}

class _AddHolidaySheetState extends ConsumerState<AddHolidaySheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _useRange;
  late HolidayType _type;
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _startDate = existing.startDate;
      _endDate = existing.endDate;
      _useRange = !DateUtils.isSameDay(existing.startDate, existing.endDate);
      _type = existing.type;
      _labelController.text = existing.label;
      _notesController.text = existing.notes;
    } else {
      final day = widget.initialDate ?? DateTime.now();
      _startDate = DateTime(day.year, day.month, day.day);
      _endDate = _startDate;
      _useRange = false;
      _type = HolidayType.university;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date != null) {
      setState(() {
        final normalized = DateTime(date.year, date.month, date.day);
        if (isStart) {
          _startDate = normalized;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = normalized.isBefore(_startDate) ? _startDate : normalized;
        }
      });
    }
  }

  void _invalidateHolidayDates(DateTime start, DateTime end) {
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      invalidateScheduleForDate(ref, cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  Future<void> _saveHoliday() async {
    if (!_formKey.currentState!.validate()) return;

    final storage = ref.read(localStorageProvider);
    await storage.init();
    final semester = await storage.getActiveSemester();
    final end = _useRange ? _endDate : _startDate;
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endNorm = DateTime(end.year, end.month, end.day);

    final existing = widget.existing;
    if (existing == null) {
      // Replace any semester-scoped holidays on the same day(s) so quick-mark
      // entries can be updated from Manage instead of creating duplicates.
      var cursor = start;
      while (!cursor.isAfter(endNorm)) {
        await storage.deleteHolidaysCoveringDate(cursor, semesterId: semester?.id);
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    final holiday = Holiday(
      id: existing?.id ?? const Uuid().v4(),
      semesterId: existing?.semesterId ?? semester?.id,
      startDate: start,
      endDate: endNorm,
      label: _labelController.text.trim(),
      type: _type,
      notes: _notesController.text.trim(),
      source: existing?.source ?? 'Manual',
      createdAt: existing?.createdAt,
    );

    await storage.saveHoliday(holiday);
    ref.invalidate(holidaysProvider);

    if (existing != null) {
      _invalidateHolidayDates(existing.startDate, existing.endDate);
    }
    _invalidateHolidayDates(start, endNorm);
    invalidateTodaySchedule(ref);
    await refreshWidgetSchedule(ref);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteHoliday() async {
    final existing = widget.existing;
    if (existing == null) return;

    final storage = ref.read(localStorageProvider);
    await storage.init();
    await storage.deleteHoliday(existing.id);
    ref.invalidate(holidaysProvider);
    _invalidateHolidayDates(existing.startDate, existing.endDate);
    invalidateTodaySchedule(ref);
    await refreshWidgetSchedule(ref);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit Holiday' : 'Add Holiday',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_useRange ? 'Start date' : 'Date'),
                subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(isStart: true),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date range'),
                value: _useRange,
                onChanged: (v) => setState(() => _useRange = v),
              ),
              if (_useRange)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End date'),
                  subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(_endDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(isStart: false),
                ),
              const Divider(),
              const SizedBox(height: 8),

              DropdownButtonFormField<HolidayType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: HolidayType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Holiday Label (e.g., Republic Day)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a label' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saveHoliday,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: Text(isEdit ? 'Update Holiday' : 'Save Holiday'),
                    ),
                  ),
                ],
              ),
              if (isEdit) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _deleteHoliday,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Delete holiday'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
