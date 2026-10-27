import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richang/editors.dart';
import 'package:richang/theme.dart';

void main() {
  testWidgets('empty task stays in editor and can be cancelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: richangTheme(), home: const TaskEditor(courses: [])),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('新建待办'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long note remains scrollable on small screens', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: richangTheme(), home: const NoteEditor()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '写下想留住的这一刻……'),
      '很长的记录' * 500,
    );
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
