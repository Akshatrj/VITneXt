import 'package:flutter/material.dart';
import 'package:vit_nextclass/core/constants/ffcs_grid.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/core/services/slot_parser.dart';
import 'package:vit_nextclass/core/theme/app_colors.dart';

class TimetableBuilder extends StatefulWidget {
  final List<Course> existingCourses;
  final Set<String> selectedCells;
  final ValueChanged<String>? onComboChanged;
  final bool isInteractive;

  const TimetableBuilder({
    super.key,
    required this.existingCourses,
    this.selectedCells = const {},
    this.onComboChanged,
    this.isInteractive = true,
  });

  @override
  State<TimetableBuilder> createState() => _TimetableBuilderState();
}

class _TimetableBuilderState extends State<TimetableBuilder> {
  late Set<String> _selectedCells;

  @override
  void initState() {
    super.initState();
    _selectedCells = Set<String>.from(widget.selectedCells);
  }

  @override
  void didUpdateWidget(TimetableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCells != oldWidget.selectedCells) {
      _selectedCells = Set<String>.from(widget.selectedCells);
    }
  }

  String get _comboString => SlotParser.join(_selectedCells.toList());

  void _toggleCell(String cellId) {
    if (!widget.isInteractive) return;

    setState(() {
      if (_selectedCells.contains(cellId)) {
        _selectedCells.remove(cellId);
      } else {
        _selectedCells.add(cellId);
      }
    });
    widget.onComboChanged?.call(_comboString);
  }

  void _removeCell(String cellId) {
    setState(() {
      _selectedCells.remove(cellId);
    });
    widget.onComboChanged?.call(_comboString);
  }

  void _clearAll() {
    setState(() {
      _selectedCells.clear();
    });
    widget.onComboChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedCells.isNotEmpty) _buildChipBar(context),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildGrid(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedCells.map((id) {
                return Chip(
                  label: Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: widget.isInteractive ? () => _removeCell(id) : null,
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.green.shade900.withValues(alpha: 0.5)
                      : Colors.green.shade100,
                );
              }).toList(),
            ),
          ),
          if (widget.isInteractive)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return Table(
      border: TableBorder.all(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: 1,
      ),
      defaultColumnWidth: const FixedColumnWidth(100),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          children: [
            const _HeaderCell('Theory'),
            for (int i = 0; i < 3; i++) _HeaderCell(FFCSTheoryGrid.timeColumns[i].label),
            const _HeaderCell(FFCSTheoryGrid.lunchLabel),
            for (int i = 3; i < FFCSTheoryGrid.timeColumns.length; i++)
              _HeaderCell(FFCSTheoryGrid.timeColumns[i].label),
          ],
        ),
        for (final row in FFCSTheoryGrid.dayRows)
          TableRow(
            children: [
              _HeaderCell(row.dayLabel),
              for (int i = 0; i < 3; i++) _buildCell(context, row.cellIds[i]),
              _buildLunchCell(context),
              for (int i = 3; i < row.cellIds.length; i++)
                _buildCell(context, row.cellIds[i]),
            ],
          ),
      ],
    );
  }

  Widget _buildLunchCell(BuildContext context) {
    return Container(
      height: 80,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: const Text('Lunch', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCell(BuildContext context, String cellId) {
    final theme = Theme.of(context);
    final isSelected = _selectedCells.contains(cellId);

    Course? occupyingCourse;
    for (final course in widget.existingCourses) {
      final parsed = SlotParser.parse(course.ffcsSlot);
      if (parsed.contains(cellId)) {
        occupyingCourse = course;
        break;
      }
    }

    Color? cellColor;
    Color? textColor = theme.colorScheme.onSurface;

    if (isSelected) {
      if (occupyingCourse != null) {
        cellColor = AppColors.gridSelectionColor(context, isClash: true);
        textColor = theme.colorScheme.onErrorContainer;
      } else {
        cellColor = AppColors.gridSelectionColor(context, isClash: false);
        textColor = theme.colorScheme.onPrimaryContainer;
      }
    } else if (occupyingCourse != null) {
      if (occupyingCourse.color != null) {
        cellColor = Color(occupyingCourse.color!);
        textColor = Colors.black87;
      } else {
        cellColor = theme.colorScheme.primaryContainer;
        textColor = theme.colorScheme.onPrimaryContainer;
      }
    }

    return InkWell(
      onTap: widget.isInteractive ? () => _toggleCell(cellId) : null,
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(4),
        alignment: Alignment.center,
        color: cellColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              cellId,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: textColor,
              ),
            ),
            if (occupyingCourse != null && !isSelected) ...[
              const SizedBox(height: 2),
              Text(
                occupyingCourse.code,
                style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                occupyingCourse.faculty,
                style: TextStyle(fontSize: 9, color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                occupyingCourse.classroom,
                style: TextStyle(fontSize: 9, color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ] else if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                occupyingCourse != null ? 'CLASH!' : 'Selected',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
