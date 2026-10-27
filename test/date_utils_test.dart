import 'package:flutter_test/flutter_test.dart';
import 'package:richang/storage.dart';

void main() {
  test('dates use fixed ISO keys', () {
    expect(dayKey(DateTime(2026, 10, 25)), '2026-10-25');
    expect(dayKey(DateTime(2026, 1, 2)), '2026-01-02');
    expect(displayDay(DateTime(2026, 10, 25)), '10月25日');
    expect(tryDay('2026-10-25')?.weekday, DateTime.sunday);
  });
}
