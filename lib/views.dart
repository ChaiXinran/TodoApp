import 'package:flutter/material.dart';
import 'storage.dart';
import 'theme.dart';
import 'schedule.dart';
import 'timetable.dart';
import 'mood_art.dart';

typedef EditRecord = void Function(RowData row);

class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    this.meetings = const [],
    this.semesters = const [],
    this.onEditCourse,
    required this.courses,
    required this.tasks,
    required this.notes,
    required this.events,
    required this.moods,
    required this.onAddEvent,
    required this.onEditEvent,
    required this.onEditTask,
    required this.onEditNote,
  });
  final List<RowData> courses, tasks, notes, events, moods;
  final List<RowData> meetings, semesters;
  final EditRecord? onEditCourse;
  final void Function(DateTime) onAddEvent;
  final EditRecord onEditEvent, onEditTask, onEditNote;
  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime focus = DateTime.now();
  String mode = '周';
  int previewWeek = 1;
  @override
  Widget build(BuildContext context) {
    final chosen = dayKey(focus), first = DateTime(focus.year, focus.month, 1);
    final offset = first.weekday - 1,
        monthCount = DateTime(focus.year, focus.month + 1, 0).day;
    final showEntries =
        widget.notes.where((x) => val(x, 'entry_date') == chosen).toList();
    final showTasks =
        widget.tasks.where((x) => val(x, 'due_date') == chosen).toList();
    final showEvents =
        widget.events.where((x) => val(x, 'day') == chosen).toList();
    final showCourses = coursesForDay(
      widget.courses,
      widget.meetings,
      widget.semesters,
      focus,
    );
    final term = widget.semesters.isEmpty ? null : widget.semesters.first;
    final anchored =
        term != null && DateTime.tryParse(val(term, 'first_monday')) != null;
    final week =
        term == null
            ? null
            : anchored
            ? teachingWeek(focus, term['first_monday'])
            : previewWeek;
    final monday = dateOnly(focus).subtract(Duration(days: focus.weekday - 1));
    final weekSessions =
        term == null || week == null
            ? <RowData>[]
            : sessionsForWeek(
              widget.courses,
              widget.meetings,
              term['id'] as String,
              week,
            );
    final showMoods =
        widget.moods.where((x) => val(x, 'day') == chosen).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
      children: [
        SoftCard(
          color: blueMist,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed:
                    () => setState(
                      () =>
                          focus =
                              mode == '月'
                                  ? DateTime(focus.year, focus.month - 1, 1)
                                  : focus.add(
                                    Duration(days: mode == '周' ? -7 : -1),
                                  ),
                    ),
                icon: const Icon(Icons.chevron_left),
              ),
              Column(
                children: [
                  Text(
                    mode == '月'
                        ? '${focus.year}年${focus.month}月'
                        : mode == '周'
                        ? '${displayDay(monday)}–${displayDay(monday.add(const Duration(days: 6)))}'
                        : chosen,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  TextButton(
                    onPressed: () => setState(() => focus = DateTime.now()),
                    child: const Text('回到今天'),
                  ),
                ],
              ),
              IconButton(
                onPressed:
                    () => setState(
                      () =>
                          focus =
                              mode == '月'
                                  ? DateTime(focus.year, focus.month + 1, 1)
                                  : focus.add(
                                    Duration(days: mode == '周' ? 7 : 1),
                                  ),
                    ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '月', label: Text('月视图')),
            ButtonSegment(value: '周', label: Text('周视图')),
            ButtonSegment(value: '日', label: Text('日视图')),
          ],
          selected: {mode},
          onSelectionChanged: (x) => setState(() => mode = x.first),
        ),
        const SizedBox(height: 12),
        if (mode == '月')
          SoftCard(
            child: Column(
              children: [
                Row(
                  children: List.generate(
                    7,
                    (i) => Expanded(
                      child: Center(
                        child: Text(
                          '一二三四五六日'[i],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                ...List.generate(
                  ((offset + monthCount) / 7).ceil(),
                  (week) => Row(
                    children: List.generate(7, (i) {
                      final d = week * 7 + i - offset + 1;
                      if (d < 1 || d > monthCount)
                        return const Expanded(child: SizedBox(height: 51));
                      final dt = DateTime(focus.year, focus.month, d),
                          key = dayKey(dt);
                      final hasAny =
                          widget.tasks.any((x) => val(x, 'due_date') == key) ||
                          widget.notes.any(
                            (x) => val(x, 'entry_date') == key,
                          ) ||
                          widget.events.any((x) => val(x, 'day') == key);
                      final m = widget.moods.where((x) => val(x, 'day') == key);
                      return Expanded(
                        child: InkWell(
                          onTap: () => setState(() => focus = dt),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 51,
                            decoration: BoxDecoration(
                              color: d == focus.day ? blueMist : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$d',
                                  style: TextStyle(
                                    fontWeight:
                                        d == focus.day
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                                if (m.isNotEmpty)
                                  MoodSticker(
                                    emoji: val(m.first, 'emoji'),
                                    size: 20,
                                  )
                                else if (hasAny)
                                  const Icon(
                                    Icons.circle,
                                    size: 6,
                                    color: Color(0xFF477896),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        if (mode == '周') ...[
          if (term != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${term['name']}',
                    style: TextStyle(color: ocean.deep),
                  ),
                ),
                DropdownButton<int>(
                  value:
                      week != null &&
                              week >= 1 &&
                              week <= (term['max_week'] as int)
                          ? week
                          : null,
                  hint: const Text('学期外'),
                  items: List.generate(
                    term['max_week'] as int,
                    (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('第 ${i + 1} 周'),
                    ),
                  ),
                  onChanged: (w) {
                    if (w == null) return;
                    if (!anchored) {
                      setState(() => previewWeek = w);
                      return;
                    }
                    final first = DateTime.parse(
                      term['first_monday'] as String,
                    );
                    setState(
                      () =>
                          focus = first.add(
                            Duration(days: (w - 1) * 7 + focus.weekday - 1),
                          ),
                    );
                  },
                ),
              ],
            ),
          if (!anchored)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '开学日期待设置；当前按教学周预览，不代表本周。周末截图不完整，暂未录入。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          TimetableGrid(
            showDates: anchored,
            sessions: weekSessions,
            monday: monday,
            selectedDay: focus,
            onDay: (day) => setState(() => focus = day),
            onCourse: (row) => widget.onEditCourse?.call(row),
          ),
          if (term != null &&
              widget.courses.any(
                (c) =>
                    c['semester_id'] == term['id'] &&
                    val(c, 'schedule_note').isNotEmpty,
              )) ...[
            const SectionTitle('未排课课程'),
            ...widget.courses
                .where(
                  (c) =>
                      c['semester_id'] == term['id'] &&
                      val(c, 'schedule_note').isNotEmpty,
                )
                .map(
                  (c) => ListTile(
                    title: Text(val(c, 'name')),
                    subtitle: Text(
                      '${val(c, 'teacher')} · ${val(c, 'schedule_note')}',
                    ),
                    onTap: () => widget.onEditCourse?.call(c),
                  ),
                ),
          ],
        ],
        SectionTitle(
          '${displayDay(focus)} · 当天详情',
          trailing: '添加日程',
          onTrailing: () => widget.onAddEvent(focus),
        ),
        if (showCourses.isEmpty &&
            showTasks.isEmpty &&
            showEvents.isEmpty &&
            showEntries.isEmpty &&
            showMoods.isEmpty)
          const EmptyHint('这一天还没有记录。'),
        ...showCourses.map(
          (c) => _dayCard(
            Icons.school_outlined,
            '课程：${val(c, 'name')}',
            '${sessionLabel(c)}  ${val(c, 'room')}',
            ocean.light,
            () => widget.onEditCourse?.call(c),
          ),
        ),
        ...showEvents.map(
          (e) => _dayCard(
            Icons.event_outlined,
            '${val(e, 'kind')}：${val(e, 'title')}',
            '${val(e, 'time')}  ${val(e, 'location')}',
            ocean.light,
            () => widget.onEditEvent(e),
          ),
        ),
        ...showTasks.map(
          (t) => _dayCard(
            Icons.check_circle_outline,
            '${t['done'] == 1 ? '[完成] ' : '作业/待办：'}${val(t, 'title')}',
            '截止日期 $chosen',
            ocean.soft,
            () => widget.onEditTask(t),
          ),
        ),
        ...showEntries.map(
          (n) => _dayCard(
            Icons.edit_note,
            '${val(n, 'kind')}：${val(n, 'title').isEmpty ? '无标题' : val(n, 'title')}',
            val(n, 'body'),
            ocean.light,
            () => widget.onEditNote(n),
          ),
        ),
        ...showMoods.map(
          (m) => _dayCard(
            Icons.favorite_border,
            '心情 ${moodOption(val(m, 'emoji')).label}',
            val(m, 'memo'),
            ocean.light,
            null,
            leading: MoodSticker(emoji: val(m, 'emoji'), size: 46),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '课表按教学周、单双周与节次展示；节假日和临时调课请以学校通知为准。',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _dayCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback? tap, {
    Widget? leading,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SoftCard(
      color: color,
      onTap: tap,
      child: Row(
        children: [
          leading ?? Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
