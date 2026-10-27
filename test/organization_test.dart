import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richang/theme.dart';
import 'package:richang/editors.dart';
import 'package:richang/goals.dart';
import 'package:richang/record_library.dart';
import 'package:richang/storage.dart';

void main() {
  test('nested folder traversal and breadcrumb preserve hierarchy', () {
    final f = <RowData>[
      {'id': 1, 'name': '阅读', 'parent_id': null},
      {'id': 2, 'name': '文学', 'parent_id': 1},
      {'id': 3, 'name': '摘录', 'parent_id': 2},
      {'id': 4, 'name': '观剧', 'parent_id': null},
    ];
    expect(folderDescendants(f, 1), {1, 2, 3});
    expect(folderLabel(f[2], f), '阅读 / 文学 / 摘录');
  });
  for (final p in [ocean, forest, honey]) {
    testWidgets('editors follow entry palette ${p.accent}', (tester) async {
      for (final page in [
        const TaskEditor(courses: []),
        const NoteEditor(),
        const CourseEditor(),
        const WorkEditor(),
        const EventEditor(),
        const GoalEditor(),
      ]) {
        await tester.pumpWidget(
          MaterialApp(home: PaletteScope(palette: p, child: page)),
        );
        await tester.pumpAndSettle();
        expect(
          Theme.of(
            tester.element(find.widgetWithText(TextButton, '保存')),
          ).colorScheme.primary,
          p.accent,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('relation graph nodes work on narrow large text', (tester) async {
    tester.view.physicalSize = const Size(640, 1700);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var picked = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: RelationCanvas(
                  center: '一篇关联到多个内容的长记录',
                  nodes: const [
                    '课程 · 数据库系统原理',
                    '作品 · 我的阅读手记',
                    '记录 · 一段喜欢的句子',
                    '目标 · 秋季学习要求',
                  ],
                  onCenter: () {},
                  onNode: (i) => picked = i,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程 · 数据库系统原理'));
    expect(picked, 0);
    expect(tester.takeException(), isNull);
  });
}
