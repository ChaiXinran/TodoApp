import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richang/corners.dart';

void main() {
  test('legacy reviews remain in repo and diaries remain in essays', () {
    for (final kind in ['repo', '观剧感想', '阅读感想']) {
      expect(recordGroup({'kind': kind}), 'repo');
    }
    expect(recordGroup({'kind': '日记'}), '随笔');
    expect(recordGroup({'kind': '重要信息'}), '重要信息');
  });
  testWidgets(
    'home shows date, image and tasks without the removed quote card',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCanvas(
              tasks: const [
                {'id': 1, 'title': '未完成事项', 'done': 0},
                {'id': 2, 'title': '已完成事项', 'done': 1},
              ],
              onToggle: (_, _) async {},
              onTask: (_) {},
              onChoosePhoto: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('换一句'), findsNothing);
      expect(find.text('私人随笔正文'), findsNothing);
      expect(find.text('今日安排'), findsNothing);
      expect(find.text('已完成事项'), findsNothing);
      await tester.scrollUntilVisible(find.text('未完成事项'), 250);
      expect(find.text('未完成事项'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
