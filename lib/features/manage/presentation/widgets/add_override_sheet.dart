import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:vit_nextclass/core/models/schedule_override.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/constants/buildings.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/conflict_detector.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';

class AddOverrideSheet extends ConsumerStatefulWidget {
  const AddOverrideSheet({super.key});

  @override
  ConsumerState<AddOverrideSheet> createState() => _AddOverrideSheetState();
}

class _AddOverrideSheetState extends ConsumerState<AddOverrideSheet> {
  final _formKey = GlobalKey<FormState>();

  OverrideType _selectedType = OverrideType.cancelled;
  String? _selectedCourseId;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _reasonController = TextEditingController();

  // For Extra/Modified
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedBuilding;
  String? _selectedFloor;
  final TextEditingController _roomController = TextEditingController();

  // Exclusively for Extra
  final TextEditingController _extraCodeController = TextEditingController();
  final TextEditingController _extraNameController = TextEditingController();
  final TextEditingController _extraFacultyController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    _roomController.dispose();
    _extraCodeController.dispose();
    _extraNameController.dispose();
    _extraFacultyController.dispose();
    super.dispose();
  }

  void _saveOverride() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == OverrideType.cancelled || _selectedType == OverrideType.modified) {
      if (_selectedCourseId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a course')));
        return;
      }
    }

    if (_selectedType == OverrideType.extra || _selectedType == OverrideType.modified) {
      if (_selectedType == OverrideType.extra) {
        if (_startTime == null || _endTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select start and end times')));
          return;
        }
      }
      
      // Conflict check for extra class
      if (_selectedType == OverrideType.extra && _startTime != null && _endTime != null) {
        final resolver = ref.read(scheduleResolverProvider);
        final schedule = await resolver.resolveSchedule(_selectedDate);
        
        final conflicts = await ConflictDetector.checkOverrideConflicts(
          startHour: _startTime!.hour,
          startMinute: _startTime!.minute,
          endHour: _endTime!.hour,
          endMinute: _endTime!.minute,
          date: _selectedDate,
          existingSchedule: schedule,
        );

        if (conflicts.isNotEmpty) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Schedule Conflict'),
              content: Text('This time conflicts with:\n\n${conflicts.join('\n')}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      }
    }

    final newOverride = ScheduleOverride(
      id: const Uuid().v4(),
      date: _selectedDate,
      type: _selectedType,
      linkedCourseId: _selectedType != OverrideType.extra ? _selectedCourseId : null,
      overrideStartHour: _startTime?.hour,
      overrideStartMinute: _startTime?.minute,
      overrideEndHour: _endTime?.hour,
      overrideEndMinute: _endTime?.minute,
      overrideBuilding: _selectedBuilding,
      overrideFloor: _selectedFloor,
      overrideRoom: _roomController.text.isNotEmpty ? _roomController.text : null,
      reason: _reasonController.text.trim(),
      extraCourseCode: _selectedType == OverrideType.extra ? _extraCodeController.text.trim() : null,
      extraCourseName: _selectedType == OverrideType.extra ? _extraNameController.text.trim() : null,
      extraFaculty: _selectedType == OverrideType.extra ? _extraFacultyController.text.trim() : null,
    );

    final storage = ref.read(localStorageProvider);
    await storage.saveOverride(newOverride);
    ref.invalidate(overridesProvider);
    invalidateTodaySchedule(ref);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final courses = coursesAsync.valueOrNull ?? [];
    final bool isOnline = _selectedBuilding == Buildings.cr;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              children: [
                Text(
                  'Schedule Override',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                
                SegmentedButton<OverrideType>(
                  segments: const [
                    ButtonSegment(value: OverrideType.cancelled, label: Text('Cancel')),
                    ButtonSegment(value: OverrideType.extra, label: Text('Extra')),
                    ButtonSegment(value: OverrideType.modified, label: Text('Modify')),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (set) {
                    setState(() {
                      _selectedType = set.first;
                    });
                  },
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

                if (_selectedType == OverrideType.cancelled || _selectedType == OverrideType.modified) ...[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Course',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedCourseId,
                    isExpanded: true,
                    items: courses.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text('${c.code} - ${c.name}'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCourseId = val),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                if (_selectedType == OverrideType.extra) ...[
                  TextFormField(
                    controller: _extraCodeController,
                    decoration: const InputDecoration(labelText: 'Course Code', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _extraNameController,
                    decoration: const InputDecoration(labelText: 'Course Name', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _extraFacultyController,
                    decoration: const InputDecoration(labelText: 'Faculty Name', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                if (_selectedType == OverrideType.extra || _selectedType == OverrideType.modified) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(true),
                          icon: const Icon(Icons.access_time),
                          label: Text(_startTime?.format(context) ?? 'Start Time'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(false),
                          icon: const Icon(Icons.access_time),
                          label: Text(_endTime?.format(context) ?? 'End Time'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Building (Optional)', border: OutlineInputBorder()),
                    value: _selectedBuilding,
                    items: Buildings.all.map((b) => DropdownMenuItem(value: b, child: Text(Buildings.getFullName(b)))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBuilding = val;
                        if (val == Buildings.cr) {
                          _selectedFloor = null;
                          _roomController.clear();
                        }
                      });
                    },
                  ),
                  if (!isOnline) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Floor', border: OutlineInputBorder()),
                            value: _selectedFloor,
                            items: Buildings.floors.map((f) => DropdownMenuItem(value: f, child: Text(Buildings.floorDisplayNames[f] ?? f))).toList(),
                            onChanged: (val) => setState(() => _selectedFloor = val),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _roomController,
                            decoration: const InputDecoration(labelText: 'Room Number', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: 'Reason (Optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                
                const SizedBox(height: 32),
                
                FilledButton(
                  onPressed: _saveOverride,
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                  child: const Text('Save Override'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
