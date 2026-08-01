import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vit_nextclass/core/models/resolved_class.dart';
import 'package:vit_nextclass/features/home/presentation/widgets/class_card.dart';
import 'package:vit_nextclass/widgets/cancel_class_sheet.dart';

class TodayScheduleSlider extends ConsumerStatefulWidget {
  final List<ResolvedClass> schedule;
  final DateTime date;

  const TodayScheduleSlider({
    super.key,
    required this.schedule,
    required this.date,
  });

  @override
  ConsumerState<TodayScheduleSlider> createState() => _TodayScheduleSliderState();
}

class _TodayScheduleSliderState extends ConsumerState<TodayScheduleSlider> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    int initialPage = 0;
    
    // Find current or next class index
    for (int i = 0; i < widget.schedule.length; i++) {
      final status = widget.schedule[i].status;
      if (status == ClassStatus.current || status == ClassStatus.next) {
        initialPage = i;
        break;
      }
    }

    _pageController = PageController(
      viewportFraction: 0.85,
      initialPage: initialPage,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.schedule.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'No classes scheduled.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.schedule.length,
        itemBuilder: (context, index) {
          final cls = widget.schedule[index];
          return ClassCard(
            cls: cls,
            onTap: cls.linkedCourseId != null
                ? () => showClassActionSheet(context, ref, cls, widget.date)
                : null,
          );
        },
      ),
    );
  }
}
