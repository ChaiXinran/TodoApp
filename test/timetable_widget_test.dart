import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richang/timetable.dart';
import 'package:richang/theme.dart';

void main() {
  testWidgets('compact timetable handles long names, single periods and zoom', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: richangTheme(seedColor: ocean.accent),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TimetableGrid(
              monday: DateTime(2026, 10, 26),
              selectedDay: DateTime(2026, 10, 26),
              onDay: (_) {},
              onCourse: (_) => opened = true,
              sessions: const [
                {
                  'id': 1,
                  'course_id': 1,
                  'name': '计算机工程中最优化的方法',
                  'weekday': 4,
                  'start_period': 8,
                  'end_period': 9,
                  'room': '主219',
                  'teacher': '程健',
                  'weeks_text': '1-14周',
                },
                {
                  'id': 2,
                  'course_id': 2,
                  'name': '体育（5）',
                  'weekday': 5,
                  'start_period': 6,
                  'end_period': 6,
                  'room': '主馆南射箭馆',
                  'teacher': '尹天安',
                  'weeks_text': '1-16周',
                },
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('体育（5）'));
    expect(opened, isTrue);
    await tester.tap(find.text('放大课表'));
    await tester.pumpAndSettle();
    expect(find.text('完整一周'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
