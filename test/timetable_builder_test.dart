import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vit_nextclass/core/models/course.dart';
import 'package:vit_nextclass/features/manage/presentation/widgets/timetable_builder.dart';

void main() {
  testWidgets('TimetableBuilder multi-tap builds combo string', (tester) async {
    String? combo = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            width: 1200,
            child: TimetableBuilder(
              existingCourses: const [],
              onComboChanged: (value) => combo = value,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('A14').first);
    await tester.pump();
    expect(combo, 'A14');

    await tester.tap(find.text('D11').first);
    await tester.pump();
    expect(combo, contains('A14'));
    expect(combo, contains('D11'));

    await tester.tap(find.text('D12').first);
    await tester.pump();
    expect(combo, 'A14+D11+D12');

    expect(find.text('A14'), findsWidgets);
    expect(find.text('D11'), findsWidgets);
    expect(find.text('D12'), findsWidgets);
  });

  testWidgets('TimetableBuilder shows clash when cell occupied', (tester) async {
    final existing = [
      Course(
        id: 'c1',
        semesterId: 's1',
        code: 'CSE101',
        name: 'Intro',
        faculty: 'Dr. A',
        ffcsSlot: 'A14',
        building: 'AB',
        floor: '1',
        room: '101',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            width: 1200,
            child: TimetableBuilder(existingCourses: existing),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('A14').first);
    await tester.pump();

    expect(find.text('CLASH!'), findsOneWidget);
  });
}
