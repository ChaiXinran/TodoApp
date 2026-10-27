import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:richang/schedule.dart';

void main() {
  final source =
      jsonDecode(File('assets/data/semester_2026_pwa.json').readAsStringSync())
          as Map;
  final courses = <ScheduleRow>[];
  final ids = <String, int>{};
  for (final raw in source['courses'] as List) {
    final c = Map<String, Object?>.from(raw as Map);
    ids[c['key'] as String] = courses.length + 1;
    courses.add({
      ...c,
      'id': courses.length + 1,
      'semester_id': '2026-pwa-autumn',
    });
  }
  final meetings =
      (source['meetings'] as List).asMap().entries.map((entry) {
        final m = Map<String, Object?>.from(entry.value as Map);
        return <String, Object?>{
          ...m,
          'id': entry.key + 1,
          'course_id': ids[m['course_key']],
          'semester_id': '2026-pwa-autumn',
          'weeks': jsonEncode(m['weeks']),
        };
      }).toList();
  final terms = [Map<String, Object?>.from(source['semester'] as Map)];

  List<ScheduleRow> week(int number) =>
      sessionsForWeek(courses, meetings, '2026-pwa-autumn', number);

  test('screenshot has 11 courses, 13 rules and confirmed week 10', () {
    expect(courses.length, 11);
    expect(meetings.length, 13);
    expect(teachingWeek(DateTime(2026, 10, 27), '2026-08-24'), 10);
    expect(courses.where((c) => '${c['schedule_note']}'.isNotEmpty).length, 1);
    expect(
      week(10).where((c) => c['weekday'] == 6 || c['weekday'] == 7),
      isEmpty,
    );
  });
  test('Thursday odd and even weeks match screenshot classrooms', () {
    final even = week(10).where((c) => c['weekday'] == 4).toList();
    expect(even.length, 2);
    expect(even.map((c) => c['name']), everyElement('保险风险计量与R'));
    expect(
      even.map((c) => c['room']),
      containsAll(['实验楼205（舜耕）', '实验楼301（舜耕）']),
    );
    final odd = week(9).where((c) => c['weekday'] == 4).single;
    expect(odd['name'], '风险理论');
    expect(odd['room'], '6219（舜耕）');
    final wed = coursesForDay(courses, meetings, terms, DateTime(2026, 10, 28));
    expect(wed.where((c) => c['name'] == '寿险精算I').length, 2);
    expect(wed.singleWhere((c) => c['name'] == '人寿与健康保险')['end_period'], 11);
  });
  test('all 18 weeks have no overlapping periods', () {
    for (var w = 1; w <= 18; w++) {
      final occupied = <String>{};
      for (final slot in week(w)) {
        for (
          var p = slot['start_period'] as int;
          p <= (slot['end_period'] as int);
          p++
        ) {
          expect(
            occupied.add('${slot['weekday']}:$p'),
            isTrue,
            reason: 'week $w conflict',
          );
        }
      }
    }
  });
}

