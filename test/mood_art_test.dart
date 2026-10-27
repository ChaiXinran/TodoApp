import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richang/mood_art.dart';

void main() {
  test('mood keys preserve old values and retain legacy mood meanings', () {
    expect(moodOptions, hasLength(8));
    expect(moodOptions.map((m) => m.emoji).toSet(), hasLength(8));
    expect(moodOption('🥹').label, '感动');
    expect(moodOption('😴').emoji, '😴');
    expect(moodOption('😴').label, '困倦');
    expect(moodOption('😴').asset, isNull);
  });
  testWidgets('all eight supplied stickers decode with genuine transparency', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final mood in moodOptions) {
        final bytes = await rootBundle.load(mood.asset!);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(
          data!.getUint8(3),
          0,
          reason: '${mood.label} corner should be transparent',
        );
        var transparent = 0, opaque = 0;
        for (var i = 3; i < data.lengthInBytes; i += 4 * 31) {
          final alpha = data.getUint8(i);
          if (alpha == 0) transparent++;
          // Watercolor paint has slightly translucent texture.
          if (alpha >= 240) opaque++;
        }
        expect(transparent, greaterThan(100));
        expect(opaque, greaterThan(100));
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
  testWidgets('picker selects every mood with an accessible label', (
    tester,
  ) async {
    String selected = '🙂';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder:
                (_, update) => MoodPicker(
                  selected: selected,
                  onChanged: (e) => update(() => selected = e),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final mood in moodOptions) {
      await tester.tap(find.byTooltip('心情 ${mood.emoji}'));
      await tester.pumpAndSettle();
      expect(selected, mood.emoji);
      expect(find.text(mood.label), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
