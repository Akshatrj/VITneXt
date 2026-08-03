import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:vit_nextclass/core/models/holiday.dart';
import 'package:vit_nextclass/core/providers/app_providers.dart';
import 'package:vit_nextclass/core/services/academic_calendar_import_service.dart';
import 'package:vit_nextclass/features/home/providers/home_provider.dart';
import 'package:vit_nextclass/features/manage/providers/manage_provider.dart';

Color holidayTypeColor(HolidayType type) {
  switch (type) {
    case HolidayType.university:
      return Colors.redAccent;
    case HolidayType.exam:
      return Colors.purple;
    case HolidayType.festival:
      return Colors.orange;
    case HolidayType.personal:
      return Colors.blue;
    case HolidayType.emergency:
      return Colors.deepOrange;
    case HolidayType.vacation:
      return Colors.teal;
    case HolidayType.sick:
      return Colors.pinkAccent;
    case HolidayType.orientation:
      return Colors.indigo;
    case HolidayType.convocation:
      return Colors.amber.shade700;
    case HolidayType.breakPeriod:
      return Colors.cyan;
    case HolidayType.other:
      return Colors.grey;
  }
}

class HolidayManagerScreen extends ConsumerStatefulWidget {
  const HolidayManagerScreen({super.key});

  @override
  ConsumerState<HolidayManagerScreen> createState() => _HolidayManagerScreenState();
}

class _HolidayManagerScreenState extends ConsumerState<HolidayManagerScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _multiSelect = false;
  final Set<String> _selectedIds = {};

  Future<void> _afterChange() async {
    ref.invalidate(holidaysProvider);
    invalidateTodaySchedule(ref);
    await refreshWidgetSchedule(ref);
  }

  Map<DateTime, List<Holiday>> _buildHolidayMap(List<Holiday> holidays) {
    final map = <DateTime, List<Holiday>>{};
    for (final h in holidays) {
      var cursor = DateTime(h.startDate.year, h.startDate.month, h.startDate.day);
      final end = DateTime(h.endDate.year, h.endDate.month, h.endDate.day);
      while (!cursor.isAfter(end)) {
        map.putIfAbsent(cursor, () => []).add(h);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return map;
  }

  Holiday? _holidayForDay(Map<DateTime, List<Holiday>> map, DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    final list = map[key];
    return list?.isNotEmpty == true ? list!.first : null;
  }

  Future<void> _openHolidayEditor({
    Holiday? existing,
    DateTime? day,
    bool forceRange = false,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _HolidayEditorSheet(
        existing: existing,
        initialDay: day ?? _selectedDay,
        forceRange: forceRange,
      ),
    );
    if (saved == true) await _afterChange();
  }

  Future<void> _importAcademicCalendar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final semester = await ref.read(activeSemesterProvider.future);
    final importer = AcademicCalendarImportService(semesterId: semester?.id);

    List<Holiday> parsed;
    try {
      final ext = (file.extension ?? '').toLowerCase();
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (ext == 'csv') {
        final content = bytes != null
            ? utf8.decode(bytes, allowMalformed: true)
            : await File(file.path!).readAsString();
        parsed = importer.parseCsv(content);
      } else if (ext == 'json') {
        final content = bytes != null
            ? utf8.decode(bytes, allowMalformed: true)
            : await File(file.path!).readAsString();
        parsed = importer.parseJson(content);
      } else if (ext == 'xlsx') {
        if (bytes == null) throw Exception('Could not read Excel file');
        parsed = importer.parseExcelBytes(bytes);
      } else {
        throw Exception('Unsupported file type: $ext');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
      return;
    }

    if (parsed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No holidays found in file')),
      );
      return;
    }

    if (!mounted) return;
    final typeCounts = <HolidayType, int>{};
    for (final h in parsed) {
      typeCounts[h.type] = (typeCounts[h.type] ?? 0) + 1;
    }

    final action = await showDialog<_ImportAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Academic Calendar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${parsed.length} holiday(s) ready to import.'),
              const SizedBox(height: 12),
              ...typeCounts.entries.map(
                (e) => Text('• ${e.key.label}: ${e.value}'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Duplicates (same name, type, dates) can be skipped or replaced.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ImportAction.skip),
            child: const Text('Skip duplicates'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ImportAction.replace),
            child: const Text('Replace duplicates'),
          ),
        ],
      ),
    );

    if (action == null) return;

    final storage = ref.read(localStorageProvider);
    await storage.saveHolidays(
      parsed,
      replaceDuplicates: action == _ImportAction.replace,
    );
    await _afterChange();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${parsed.length} holiday(s)')),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete holidays'),
        content: Text('Delete ${_selectedIds.length} selected holiday(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(localStorageProvider).deleteHolidays(_selectedIds);
    setState(() {
      _selectedIds.clear();
      _multiSelect = false;
    });
    await _afterChange();
  }

  @override
  Widget build(BuildContext context) {
    final holidaysAsync = ref.watch(holidaysProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_multiSelect ? '${_selectedIds.length} selected' : 'Holiday Manager'),
        actions: [
          if (_multiSelect) ...[
            IconButton(
              tooltip: 'Delete selected',
              onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: 'Cancel selection',
              onPressed: () => setState(() {
                _multiSelect = false;
                _selectedIds.clear();
              }),
              icon: const Icon(Icons.close),
            ),
          ] else ...[
            IconButton(
              tooltip: 'Select',
              onPressed: () => setState(() => _multiSelect = true),
              icon: const Icon(Icons.checklist),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'bulk') {
                  _openHolidayEditor(forceRange: true);
                } else if (value == 'import') {
                  _importAcademicCalendar();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'bulk',
                  child: Text('Bulk Holiday'),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: Text('Import Academic Calendar'),
                ),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: _multiSelect
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openHolidayEditor(day: _selectedDay),
              icon: const Icon(Icons.add),
              label: const Text('Add Holiday'),
            ),
      body: holidaysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load holidays: $e')),
        data: (holidays) {
          final map = _buildHolidayMap(holidays);
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final upcoming = holidays
              .where((h) => !h.endDate.isBefore(today))
              .toList()
            ..sort((a, b) => a.startDate.compareTo(b.startDate));

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              TableCalendar<Holiday>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return map[key] ?? [];
                },
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                  final holiday = _holidayForDay(map, selected);
                  if (_multiSelect && holiday != null) {
                    setState(() {
                      if (_selectedIds.contains(holiday.id)) {
                        _selectedIds.remove(holiday.id);
                      } else {
                        _selectedIds.add(holiday.id);
                      }
                    });
                  } else {
                    _openHolidayEditor(existing: holiday, day: selected);
                  }
                },
                onPageChanged: (focused) => setState(() => _focusedDay = focused),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isEmpty) return null;
                    final colors = events
                        .map((h) => holidayTypeColor(h.type))
                        .toSet()
                        .take(3)
                        .toList();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: colors
                          .map(
                            (c) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                            ),
                          )
                          .toList(),
                    );
                  },
                  defaultBuilder: (context, day, focused) {
                    final holiday = _holidayForDay(map, day);
                    if (holiday == null) return null;
                    final selected = _selectedIds.contains(holiday.id);
                    return Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: holidayTypeColor(holiday.type).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: selected
                            ? Border.all(color: theme.colorScheme.primary, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('${day.day}'),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Upcoming holidays',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (upcoming.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No upcoming holidays.'),
                )
              else
                ...upcoming.map((h) {
                  final selected = _selectedIds.contains(h.id);
                  final rangeSame = isSameDay(h.startDate, h.endDate);
                  final dateLabel = rangeSame
                      ? DateFormat('EEE, MMM d, yyyy').format(h.startDate)
                      : '${DateFormat('MMM d').format(h.startDate)} – ${DateFormat('MMM d, yyyy').format(h.endDate)}';

                  return ListTile(
                    leading: _multiSelect
                        ? Checkbox(
                            value: selected,
                            onChanged: (_) {
                              setState(() {
                                if (selected) {
                                  _selectedIds.remove(h.id);
                                } else {
                                  _selectedIds.add(h.id);
                                }
                              });
                            },
                          )
                        : CircleAvatar(
                            backgroundColor:
                                holidayTypeColor(h.type).withValues(alpha: 0.2),
                            child: Icon(
                              Icons.celebration,
                              color: holidayTypeColor(h.type),
                              size: 20,
                            ),
                          ),
                    title: Text(h.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$dateLabel · ${h.type.label}'),
                    trailing: h.isRecurring
                        ? const Icon(Icons.repeat, size: 18)
                        : null,
                    onTap: () {
                      if (_multiSelect) {
                        setState(() {
                          if (selected) {
                            _selectedIds.remove(h.id);
                          } else {
                            _selectedIds.add(h.id);
                          }
                        });
                      } else {
                        _openHolidayEditor(existing: h);
                      }
                    },
                    onLongPress: () {
                      setState(() {
                        _multiSelect = true;
                        _selectedIds.add(h.id);
                      });
                    },
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

enum _ImportAction { skip, replace }

class _HolidayEditorSheet extends ConsumerStatefulWidget {
  const _HolidayEditorSheet({
    this.existing,
    required this.initialDay,
    this.forceRange = false,
  });

  final Holiday? existing;
  final DateTime initialDay;
  final bool forceRange;

  @override
  ConsumerState<_HolidayEditorSheet> createState() => _HolidayEditorSheetState();
}

class _HolidayEditorSheetState extends ConsumerState<_HolidayEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _endDate;
  late HolidayType _type;
  late bool _recurring;
  late bool _useRange;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.label ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _startDate = existing?.startDate ?? widget.initialDay;
    _endDate = existing?.endDate ?? widget.initialDay;
    _type = existing?.type ?? HolidayType.university;
    _recurring = existing?.isRecurring ?? false;
    _useRange = widget.forceRange ||
        (existing != null && !isSameDay(existing.startDate, existing.endDate));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked.isBefore(_startDate) ? _startDate : picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final semester = await ref.read(activeSemesterProvider.future);
    final end = _useRange ? _endDate : _startDate;
    final holiday = Holiday(
      id: widget.existing?.id ?? const Uuid().v4(),
      semesterId: widget.existing?.semesterId ?? semester?.id,
      startDate: DateTime(_startDate.year, _startDate.month, _startDate.day),
      endDate: DateTime(end.year, end.month, end.day),
      label: _nameController.text.trim(),
      type: _type,
      notes: _notesController.text.trim(),
      isRecurring: _recurring,
      source: widget.existing?.source ?? 'Manual',
      createdAt: widget.existing?.createdAt,
    );

    await ref.read(localStorageProvider).saveHoliday(holiday);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await ref.read(localStorageProvider).deleteHoliday(existing.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? (widget.forceRange ? 'Bulk Holiday' : 'Add Holiday')
                    : 'Edit Holiday',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Holiday name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<HolidayType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: HolidayType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date range'),
                subtitle: const Text('Mark multiple consecutive days'),
                value: _useRange,
                onChanged: (v) => setState(() => _useRange = v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_useRange ? 'Start date' : 'Date'),
                subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(isStart: true),
              ),
              if (_useRange)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End date'),
                  subtitle: Text(DateFormat('EEEE, MMM d, yyyy').format(_endDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(isStart: false),
                ),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring yearly'),
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: Text(widget.existing == null ? 'Save Holiday' : 'Update Holiday'),
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
