import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richang/goals.dart';
import 'package:richang/goal_metrics.dart';
import 'package:richang/theme.dart';

void main() {
  test('goal values reject zero targets, negatives and nonfinite values', () {
    for (final input in ['0', '-1', 'NaN', 'Infinity', '', 'not a number']) {
      expect(() => goalNumber(input, positive: true), throwsFormatException);
    }
    for (final input in ['-1', 'NaN', 'Infinity', '']) {
      expect(() => goalNumber(input, positive: false), throwsFormatException);
    }
    expect(goalNumber('0', positive: false), 0);
    expect(goalNumber(' 12.25 ', positive: true), 12.25);
    expect(goalNumberText(100), '100');
    expect(goalNumberText(0), '0');
    expect(goalNumberText(3.5), '3.5');
    expect(double.parse(goalNumberText(1e30)), 1e30);
    expect(goalNumberText(0.00000001), isNot('0'));
  });

  final goal = <String, Object?>{
    'id': 1,
    'title': '志愿服务',
    'semester': '2026 秋',
    'category': '志愿',
    'target_value': 40.0,
    'current_value': 10.0,
    'unit': '小时',
  };

  testWidgets('goal cards show real totals, completion and bounded bars', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: richangTheme(),
        home: Scaffold(body: GoalCard(goal: goal, onTap: () {})),
      ),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .25,
    );
    expect(find.text('10 / 40 小时  ·  25%'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        theme: richangTheme(),
        home: Scaffold(
          body: GoalCard(goal: {...goal, 'current_value': 50.0}, onTap: () {}),
        ),
      ),
    );
    expect(find.text('已达成'), findsOneWidget);
    expect(find.text('50 / 40 小时  ·  125%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('semester filter retains historical goals and add action', (
    tester,
  ) async {
    var addTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: richangTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GoalsSection(
              goals: [
                goal,
                {...goal, 'id': 2, 'title': '上学期阅读', 'semester': '2026 春'},
              ],
              onAdd: () => addTapped = true,
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('上学期阅读'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '2026 秋'));
    await tester.pumpAndSettle();
    expect(find.text('上学期阅读'), findsNothing);
    expect(find.text('志愿服务'), findsOneWidget);
    await tester.tap(find.text('添加目标'));
    expect(addTapped, isTrue);
  });

  testWidgets('invalid target stays editable and does not touch the database', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GoalEditor()));
    await tester.enterText(find.widgetWithText(TextField, '目标或要求 *'), '学期要求');
    await tester.ensureVisible(find.widgetWithText(TextField, '目标值 *'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '目标值 *'), '0');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('目标值须为大于 0 的数字'), findsOneWidget);
    expect(find.text('添加学期目标'), findsOneWidget);
  });
}
