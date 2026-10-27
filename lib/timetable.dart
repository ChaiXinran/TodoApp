import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'schedule.dart';
import 'theme.dart';

/// One weekday per column, one lesson period per row. Unknown bell times are
/// deliberately not inferred from lesson numbers.
class TimetableGrid extends StatefulWidget {
  const TimetableGrid({
    super.key,
    required this.sessions,
    this.showDates = true,
    required this.monday,
    required this.selectedDay,
    required this.onDay,
    required this.onCourse,
  });
  final bool showDates;
  final List<ScheduleRow> sessions;
  final DateTime monday, selectedDay;
  final ValueChanged<DateTime> onDay;
  final ValueChanged<ScheduleRow> onCourse;
  @override
  State<TimetableGrid> createState() => _TimetableGridState();
}

class _TimetableGridState extends State<TimetableGrid> {
  bool expanded = false;
  final horizontal = ScrollController();
  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${widget.showDates ? '本周' : '所选教学周'} ${widget.sessions.length} 次课',
              style: TextStyle(color: ocean.deep, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => expanded = !expanded),
            icon: Icon(expanded ? Icons.fit_screen : Icons.zoom_in, size: 18),
            label: Text(expanded ? '完整一周' : '放大课表'),
          ),
        ],
      ),
      LayoutBuilder(
        builder: (context, box) {
          const gutter = 28.0, heading = 46.0;
          final column = expanded ? 98.0 : (box.maxWidth - gutter) / 7;
          final row = expanded ? 58.0 : 48.0;
          final width = gutter + column * 7;
          final height = heading + row * 14;
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              controller: horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: Colors.white)),
                    for (var day = 0; day < 7; day++) ...[
                      Positioned(
                        left: gutter + column * day,
                        top: 0,
                        width: column,
                        height: heading,
                        child: InkWell(
                          onTap:
                              !widget.showDates
                                  ? null
                                  : () => widget.onDay(
                                    widget.monday.add(Duration(days: day)),
                                  ),
                          child: Container(
                            color:
                                dateOnly(widget.selectedDay) ==
                                        dateOnly(
                                          widget.monday.add(
                                            Duration(days: day),
                                          ),
                                        )
                                    ? ocean.soft
                                    : ocean.light,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '周${'一二三四五六日'[day]}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: ocean.deep,
                                  ),
                                ),
                                if (widget.showDates)
                                  Text(
                                    '${widget.monday.add(Duration(days: day)).month}/${widget.monday.add(Duration(days: day)).day}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ocean.accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (var period = 1; period <= 14; period++)
                        Positioned(
                          left: gutter + column * day,
                          top: heading + row * (period - 1),
                          width: column,
                          height: row,
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  period.isEven
                                      ? const Color(0xFFFAFCFE)
                                      : Colors.white,
                              border: Border(
                                right: const BorderSide(
                                  color: Color(0xFFF0F3F5),
                                ),
                                top: BorderSide(
                                  color:
                                      [6, 11].contains(period)
                                          ? ocean.soft
                                          : const Color(0xFFF0F3F5),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                    Positioned(
                      left: 0,
                      top: 0,
                      width: gutter,
                      height: heading,
                      child: Center(
                        child: Text(
                          '节次',
                          style: TextStyle(fontSize: 9, color: ocean.accent),
                        ),
                      ),
                    ),
                    for (var period = 1; period <= 14; period++)
                      Positioned(
                        left: 0,
                        top: heading + row * (period - 1),
                        width: gutter,
                        height: row,
                        child: Center(
                          child: Text(
                            '$period',
                            style: TextStyle(fontSize: 11, color: ocean.accent),
                          ),
                        ),
                      ),
                    for (final lesson in widget.sessions)
                      _lesson(lesson, column, row, heading, gutter),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          expanded ? '左右滑动查看整周 · 点击课程查看教师、地点和教学周' : '点击课程查看详情 · 按节次展示，钟点时间待设置',
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ),
    ],
  );

  Widget _lesson(
    ScheduleRow lesson,
    double column,
    double row,
    double heading,
    double gutter,
  ) {
    final first = lesson['start_period'] as int,
        last = lesson['end_period'] as int;
    final height = row * (last - first + 1) - 4;
    const fills = [
      Color(0xFFE3EFF8),
      Color(0xFFD3E5F1),
      Color(0xFFEAF3FA),
      Color(0xFFDBEAF6),
    ];
    final color = fills[(lesson['course_id'] as int) % fills.length];
    final title = lesson['name'] as String;
    return Positioned(
      left: gutter + column * ((lesson['weekday'] as int) - 1) + 2,
      top: heading + row * (first - 1) + 2,
      width: column - 4,
      height: height,
      child: Semantics(
        button: true,
        label: '$title，${sessionLabel(lesson)}，${lesson['room']}',
        child: Tooltip(
          message:
              '$title\n${lesson['teacher']} · ${lesson['room']}\n${lesson['weeks_text']}',
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => widget.onCourse(lesson),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: math.max(
                          1,
                          ((height - 23) / (expanded ? 14 : 12)).floor(),
                        ),
                        style: TextStyle(
                          fontSize: expanded ? 12 : 10,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: ocean.deep,
                        ),
                      ),
                    ),
                    Text(
                      '${lesson['room']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: expanded ? 11 : 9,
                        color: ocean.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
