import 'dart:convert';

typedef ScheduleRow = Map<String, Object?>;

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int? teachingWeek(DateTime day, Object? firstMonday) {
  final first = DateTime.tryParse('$firstMonday');
  if (first == null) return null;
  // Compare civil days independently of local DST offsets.
  final elapsed =
      DateTime.utc(
        day.year,
        day.month,
        day.day,
      ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
  return elapsed < 0 ? 0 : elapsed ~/ 7 + 1;
}

List<int> meetingWeeks(ScheduleRow row) =>
    (jsonDecode(row['weeks'] as String) as List).cast<int>();

List<ScheduleRow> sessionsForWeek(
  List<ScheduleRow> courses,
  List<ScheduleRow> meetings,
  String semesterId,
  int week,
) {
  final masters = {for (final c in courses) c['id']: c};
  return meetings
      .where(
        (m) =>
            m['semester_id'] == semesterId &&
            meetingWeeks(m).contains(week) &&
            masters.containsKey(m['course_id']),
      )
      .map(
        (m) => <String, Object?>{
          ...masters[m['course_id']]!,
          ...m,
          'id': m['course_id'],
          'meeting_id': m['id'],
        },
      )
      .toList();
}

List<ScheduleRow> coursesForDay(
  List<ScheduleRow> courses,
  List<ScheduleRow> meetings,
  List<ScheduleRow> semesters,
  DateTime day,
) {
  final result =
      courses
          .where((c) => c['semester_id'] == null && c['weekday'] == day.weekday)
          .toList();
  for (final term in semesters) {
    final week = teachingWeek(day, term['first_monday']);
    if (week == null || week < 1 || week > (term['max_week'] as int)) continue;
    result.addAll(
      sessionsForWeek(
        courses,
        meetings,
        term['id'] as String,
        week,
      ).where((m) => m['weekday'] == day.weekday),
    );
  }
  return result;
}

String sessionLabel(ScheduleRow row) {
  if (row['start_period'] != null) {
    final start = row['start_period'], end = row['end_period'];
    return start == end ? '第 $start 节' : '第 $start–$end 节';
  }
  return '${row['start_time'] ?? ''}–${row['end_time'] ?? ''}';
}
