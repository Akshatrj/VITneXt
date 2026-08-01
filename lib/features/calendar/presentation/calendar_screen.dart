import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:vit_nextclass/features/calendar/providers/calendar_provider.dart';
import 'package:vit_nextclass/features/calendar/presentation/widgets/day_detail_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedCalendarDateProvider);
    final eventsAsync =
        ref.watch(calendarEventsProvider(DateTime(_focusedDay.year, _focusedDay.month, 1)));
    final eventsMap = eventsAsync.value ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar<CalendarDayInfo>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _format,
            selectedDayPredicate: (day) => isSameDay(selectedDate, day),
            eventLoader: (day) {
              final key = DateTime(day.year, day.month, day.day);
              final info = eventsMap[key];
              return info != null ? [info] : [];
            },
            onDaySelected: (selectedDay, focusedDay) {
              ref.read(selectedCalendarDateProvider.notifier).state = selectedDay;
              setState(() => _focusedDay = focusedDay);
              _showDayDetail(context, selectedDay);
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            onFormatChanged: (format) => setState(() => _format = format),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                final info = events.first as CalendarDayInfo;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (info.isHoliday)
                      _dot(Colors.redAccent),
                    if (info.classCount > 0)
                      _dot(Colors.blueAccent),
                    if (info.cancelledCount > 0)
                      _dot(Colors.grey),
                    if (info.hasOverride)
                      _dot(Colors.orangeAccent),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              children: [
                _legend(Colors.blueAccent, 'Classes'),
                _legend(Colors.grey, 'Cancelled'),
                _legend(Colors.redAccent, 'Holiday'),
                _legend(Colors.orangeAccent, 'Override'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        width: 7,
        height: 7,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  void _showDayDetail(BuildContext context, DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DayDetailSheet(date: date),
    );
  }
}
