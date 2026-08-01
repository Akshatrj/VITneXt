import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';

class AddHolidaySheet extends ConsumerStatefulWidget {
  const AddHolidaySheet({super.key});

  @override
  ConsumerState<AddHolidaySheet> createState() => _AddHolidaySheetState();
}

class _AddHolidaySheetState extends ConsumerState<AddHolidaySheet> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  void _saveHoliday() async {
    if (!_formKey.currentState!.validate()) return;

    final newHoliday = Holiday(
      id: const Uuid().v4(),
      date: _selectedDate,
      label: _selectedControllerText(),
    );

    final storage = ref.read(localStorageProvider);
    await storage.saveHoliday(newHoliday);
    ref.invalidate(holidaysProvider);
    invalidateTodaySchedule(ref);

    if (mounted) {
      Navigator.pop(context);
    }
  }
  
  String _selectedControllerText() => _labelController.text.trim();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
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
              title: const Text('Date'),
              subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const Divider(),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Holiday Label (e.g., Republic Day)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Please enter a label' : null,
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
    );
  }
}
