import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richang/daily_banners.dart';
import 'package:richang/theme.dart';

void main() {
  testWidgets('pink home card preserves wording and shows correct weekday', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: HomeDateCard(date: DateTime(2026, 10, 27)),
            ),
          ),
        ),
      ),
    );
    expect(find.text('2026年10月27日 · 星期二'), findsOneWidget);
    expect(find.text('今天也要好好生活 ☁️'), findsOneWidget);
    expect(find.text('把重要的事与喜欢的瞬间都留下来。'), findsOneWidget);
    expect(tester.widget<SceneHeader>(find.byType(SceneHeader)).palette, rose);
    expect(tester.takeException(), isNull);
  });
  testWidgets('saved quote picker filters body and source', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteHistoryPicker(
            quotes: [
              {'id': 1, 'title': '森林', 'body': '慢慢生长'},
              {'id': 2, 'title': '海边', 'body': '看一片蓝天'},
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '海边');
    await tester.pump();
    expect(find.text('看一片蓝天'), findsOneWidget);
    expect(find.text('慢慢生长'), findsNothing);
  });
}
