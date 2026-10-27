import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richang/journal_pages.dart';
import 'package:richang/storage.dart';
import 'package:richang/theme.dart';

final tasks = <RowData>[
  {'id': 1, 'title': '整理一份很长名称的课程项目资料与作业', 'done': 0, 'due_date': '2026-10-30'},
];
final notes = <RowData>[
  {
    'id': 1,
    'kind': '摘录',
    'title': '喜欢的句子',
    'body': '留一点光，给每一个平凡的日子。',
    'entry_date': '2026-10-27',
  },
  {
    'id': 2,
    'kind': '随笔',
    'title': '关于最近的感想',
    'body': '记录一次阅读、一个瞬间。',
    'entry_date': '2026-10-26',
  },
  {'id': 3, 'kind': '重要信息', 'title': '常用学业资料', 'entry_date': '2026-10-25'},
];
final works = <RowData>[
  for (var i = 0; i < 3; i++)
    {'id': i + 1, 'name': '很长的文学作品名称第${i + 1}册', 'progress': 35},
];
final goals = <RowData>[
  {'id': 1, 'semester': '2026 秋', 'current_value': 5, 'target_value': 10},
  {'id': 2, 'semester': '2026 秋季学期', 'current_value': 20, 'target_value': 10},
  {'id': 3, 'semester': '2027 春', 'current_value': 0, 'target_value': 10},
];

void main() {
  test(
    'semester progress uses only real matching goals and bounds overcompletion',
    () {
      final current = goalsInTerm(goals, '2026 秋');
      expect(current, hasLength(2));
      expect(termProgress(current), .75);
      expect(termProgress([]), isNull);
    },
  );
  Widget affairs({Future<void> Function(RowData, bool)? toggle}) =>
      AffairsJournal(
        tasks: tasks,
        courses: const [],
        goals: goals,
        term: '2026 秋',
        onToggle: toggle ?? (_, _) async {},
        onTask: (_) {},
        onAllTasks: () {},
        onCourses: () {},
        onGoals: () {},
        onVolunteer: () {},
        onRefresh: () async {},
      );
  Widget records({Future<void> Function(String)? mood}) => RecordsJournal(
    notes: notes,
    moods: const [],
    onNote: (_, _) {},
    onMood: mood ?? (_) async {},
    onMoodDetails: () {},
    onRefresh: () async {},
    onTheater: () {},
  );
  Widget archive() => ArchiveJournal(
    works: works,
    covers: const {},
    events: const [],
    notes: notes,
    semesters: const [
      {'id': '2026-autumn', 'name': '2026 秋'},
    ],
    onWork: (_) {},
    onBooks: () {},
    onTheater: () {},
    onImportant: () {},
    onSemester: (_) {},
    onCloud: () {},
    onRefresh: () async {},
  );
  for (final size in [(400.0, 1.0), (320.0, 1.6)]) {
    for (final page in ['事务', '记录', '档案']) {
      testWidgets(
        '$page remains readable at width ${size.$1}, text ${size.$2}',
        (tester) async {
          tester.view.physicalSize = Size(size.$1 * 2, 1600);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: richangTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(size.$1, 800),
                  textScaler: TextScaler.linear(size.$2),
                ),
                child: Scaffold(
                  body: switch (page) {
                    '事务' => affairs(),
                    '记录' => records(),
                    _ => archive(),
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 5; i++) {
            await tester.drag(
              find.byType(ListView).first,
              const Offset(0, -420),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
  testWidgets('affairs checklist updates actual selected task', (tester) async {
    int? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: affairs(
            toggle: (row, done) async {
              if (done) changed = rowId(row);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(Checkbox), 250);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(changed, 1);
    await tester.scrollUntilVisible(find.text('75%'), -250);
    expect(find.text('75%'), findsOneWidget);
  });
  testWidgets(
    'records filters actual content and mood action saves selection',
    (tester) async {
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: records(mood: (e) async => chosen = e)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('心情 🥹'));
      await tester.pumpAndSettle();
      expect(chosen, '🥹');
      await tester.tap(find.widgetWithText(ChoiceChip, '摘录'));
      await tester.pumpAndSettle();
      expect(find.text('关于最近的感想'), findsNothing);
      expect(find.text('留一点光，给每一个平凡的日子。'), findsOneWidget);
    },
  );
}
