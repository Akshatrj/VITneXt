import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/constants/buildings.dart';
import 'package:vit_nextclass/core/constants/ffcs_slots.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/conflict_detector.dart';
import 'package:vit_nextclass/core/services/slot_parser.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';
import 'package:vit_nextclass/features/manage/presentation/widgets/timetable_builder.dart';

const _pastelColors = [
  0xFFFFB3BA, 0xFFFFDFBA, 0xFFFFFFBA, 0xFFBAFFC9, 0xFFBAE1FF,
  0xFFE0BBE4, 0xFF957DAD, 0xFFD291BC, 0xFFFEC8D8, 0xFFFFDFD3,
];

class AddCourseSheet extends ConsumerStatefulWidget {
  final Course? course;

  const AddCourseSheet({super.key, this.course});

  @override
  ConsumerState<AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends ConsumerState<AddCourseSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _facultyController;
  late TextEditingController _roomController;

  String? _selectedSlotName;
  String? _selectedBuilding;
  String? _selectedFloor;
  Set<String> _selectedCells = {};

  bool _isSelectingSlot = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.course?.code ?? '');
    _nameController = TextEditingController(text: widget.course?.name ?? '');
    _facultyController = TextEditingController(text: widget.course?.faculty ?? '');
    _roomController = TextEditingController(text: widget.course?.room ?? '');

    _selectedSlotName = widget.course?.ffcsSlot;
    if (_selectedSlotName != null && _selectedSlotName!.isNotEmpty) {
      _selectedCells = SlotParser.parse(_selectedSlotName!).toSet();
    }
    _selectedBuilding = widget.course?.building;
    _selectedFloor = widget.course?.floor;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _facultyController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _invalidateSchedule() {
    ref.invalidate(coursesProvider);
    invalidateTodaySchedule(ref);
  }

  Future<void> _refreshWidget() async {
    await refreshWidgetSchedule(ref);
  }

  void _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSlotName == null || _selectedSlotName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a slot on the timetable.')),
      );
      return;
    }

    final timings = FFCSSlotDatabase.getTimingsForCombo(_selectedSlotName!);
    if (timings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected slots do not resolve to any class times.')),
      );
      return;
    }

    final existingCourses = ref.read(coursesProvider).valueOrNull ?? [];

    final conflicts = ConflictDetector.checkCourseConflicts(
      newSlotCombo: _selectedSlotName!,
      existingCourses: existingCourses,
      excludeCourseId: widget.course?.id,
    );

    if (conflicts.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Slot Clash'),
          content: Text(
            'The selected slot $_selectedSlotName conflicts with:\n\n${conflicts.join('\n')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return;
    }

    final activeSemester = await ref.read(activeSemesterProvider.future);
    final semesterId = widget.course?.semesterId ?? activeSemester?.id;
    if (semesterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active semester found.')),
      );
      return;
    }

    final int assignedColor =
        widget.course?.color ?? _pastelColors[Random().nextInt(_pastelColors.length)];

    final newCourse = Course(
      id: widget.course?.id ?? const Uuid().v4(),
      semesterId: semesterId,
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      faculty: _facultyController.text.trim(),
      ffcsSlot: _selectedSlotName!,
      building: _selectedBuilding ?? Buildings.other,
      floor: _selectedFloor ?? 'G',
      room: _roomController.text.trim(),
      color: assignedColor,
    );

    final storage = ref.read(localStorageProvider);
    try {
      await storage.saveCourse(newCourse);
      _invalidateSchedule();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newCourse.code} saved')),
      );

      // Refresh widget/notifications after closing so failures never block save UI.
      try {
        await _refreshWidget();
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save course: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: _isSelectingSlot
              ? _buildSlotSelection(scrollController)
              : _buildForm(scrollController),
        );
      },
    );
  }

  Widget _buildForm(ScrollController scrollController) {
    final bool isOnline = _selectedBuilding == Buildings.cr;

    return Form(
      key: _formKey,
      child: ListView(
        controller: scrollController,
        children: [
          Row(
            children: [
              Text(
                widget.course == null ? 'Add Course' : 'Edit Course',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              CloseButton(onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Course Code (e.g. CSE1001)',
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Course Name', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _facultyController,
            decoration: const InputDecoration(labelText: 'Faculty Name', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedBuilding,
            decoration: const InputDecoration(labelText: 'Building', border: OutlineInputBorder()),
            items: Buildings.all
                .map((b) => DropdownMenuItem(value: b, child: Text(Buildings.getFullName(b))))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedBuilding = v;
                if (v == Buildings.cr) {
                  _selectedFloor = 'O';
                  _roomController.text = 'Online';
                } else if (_selectedFloor == 'O') {
                  _selectedFloor = 'G';
                  _roomController.clear();
                }
              });
            },
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          if (!isOnline) ...[
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedFloor,
                    decoration: const InputDecoration(labelText: 'Floor', border: OutlineInputBorder()),
                    items: ['G', '1', '2', '3', '4', '5', '6', '7', '8']
                        .map((f) => DropdownMenuItem(value: f, child: Text(f == 'G' ? 'Ground' : f)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedFloor = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      labelText: 'Room Number (e.g. 204)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: ListTile(
              title: Text(
                _selectedSlotName?.isNotEmpty == true
                    ? 'Slot: $_selectedSlotName'
                    : 'No Slot Selected',
              ),
              subtitle: const Text('Tap to select slots on the visual timetable'),
              trailing: const Icon(Icons.calendar_view_week),
              onTap: () => setState(() => _isSelectingSlot = true),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saveCourse,
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: const Text('Save Course'),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotSelection(ScrollController scrollController) {
    final existingCourses = ref.watch(coursesProvider).valueOrNull ?? [];
    final coursesToDisplay =
        existingCourses.where((c) => c.id != widget.course?.id).toList();

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _isSelectingSlot = false),
            ),
            Expanded(
              child: Text(
                'Select slots for ${_codeController.text.isNotEmpty ? _codeController.text : "Course"}',
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap cells to build your slot combo (e.g. A14+D11+D12). Tap again to deselect.',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TimetableBuilder(
            existingCourses: coursesToDisplay,
            selectedCells: _selectedCells,
            onComboChanged: (combo) {
              setState(() {
                _selectedCells = SlotParser.parse(combo).toSet();
                _selectedSlotName = combo.isEmpty ? null : combo;
              });
            },
          ),
        ),
        if (_selectedSlotName != null) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() => _isSelectingSlot = false),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: Text('Confirm Slot $_selectedSlotName'),
          ),
        ],
      ],
    );
  }
}
