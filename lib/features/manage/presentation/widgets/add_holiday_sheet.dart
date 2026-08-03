import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';

class AddHolidaySheet extends ConsumerStatefulWidget {
  const AddHolidaySheet({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<AddHolidaySheet> createState() => _AddHolidaySheetState();
}

class _AddHolidaySheetState extends ConsumerState<AddHolidaySheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _startDate;
  late DateTime _endDate;
  bool _useRange = false;
  HolidayType _type = HolidayType.university;
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final day = widget.initialDate ?? DateTime.now();
    _startDate = DateTime(day.year, day.month, day.day);
    _endDate = _startDate;
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
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = date.isBefore(_startDate) ? _startDate : date;
        }
      });
    }
  }

  Future<void> _saveHoliday() async {
    if (!_formKey.currentState!.validate()) return;

    final semester = await ref.read(activeSemesterProvider.future);
    final end = _useRange ? _endDate : _startDate;
    final newHoliday = Holiday(
      id: const Uuid().v4(),
      semesterId: semester?.id,
      startDate: _startDate,
      endDate: end,
      label: _labelController.text.trim(),
      type: _type,
      notes: _notesController.text.trim(),
      source: 'Manual',
    );

    final storage = ref.read(localStorageProvider);
    await storage.saveHoliday(newHoliday);
    ref.invalidate(holidaysProvider);
    invalidateTodaySchedule(ref);
    await refreshWidgetSchedule(ref);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Add Holiday',
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
                      child: const Text('Save Holiday'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
