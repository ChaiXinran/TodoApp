import 'stored_image.dart';
import 'header_companions.dart';
import 'package:flutter/material.dart';
import 'storage.dart';
import 'theme.dart';
import 'goal_metrics.dart';
import 'mood_art.dart';

const journalGap = 12.0;

String compactTerm(String value) => value.replaceAll(RegExp(r'[\s季学期]'), '');
List<RowData> goalsInTerm(List<RowData> goals, String term) =>
    goals
        .where((g) => compactTerm(val(g, 'semester')) == compactTerm(term))
        .toList();
double? termProgress(List<RowData> goals) =>
    goals.isEmpty
        ? null
        : goals.fold<double>(
              0,
              (sum, g) =>
                  sum +
                  goalFraction(
                    g['current_value'] as num,
                    g['target_value'] as num,
                  ),
            ) /
            goals.length;

class JournalHeading extends StatelessWidget {
  const JournalHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
    this.companions = false,
  });
  final bool companions;
  final String title, subtitle;
  final IconData icon;
  final SectionPalette palette;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (companions)
          const HeaderCompanions()
        else
          CircleAvatar(
            radius: 25,
            backgroundColor: palette.light,
            child: Icon(icon, color: palette.accent),
          ),
      ],
    ),
  );
}

class JournalPanel extends StatelessWidget {
  const JournalPanel({
    super.key,
    required this.palette,
    required this.child,
    this.onTap,
    this.padding = 16,
    this.watermark,
  });
  final SectionPalette palette;
  final Widget child;
  final VoidCallback? onTap;
  final double padding;
  final IconData? watermark;
  @override
  Widget build(BuildContext context) => Material(
    color: palette.light,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Ink(
        decoration:
            watermark == null
                ? null
                : BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.light,
                      Color.lerp(palette.light, palette.soft, .45)!,
                    ],
                  ),
                ),
        child: Stack(
          children: [
            if (watermark != null)
              Positioned(
                right: -24,
                bottom: -26,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Transform.rotate(
                      angle: -.22,
                      child: Icon(
                        watermark,
                        size: 142,
                        color: palette.accent.withValues(alpha: .09),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(padding: EdgeInsets.all(padding), child: child),
          ],
        ),
      ),
    ),
  );
}

/// Two unequal columns at normal sizes; a readable stack for narrow/large text.
class JournalBento extends StatelessWidget {
  const JournalBento({
    super.key,
    required this.large,
    required this.top,
    required this.bottom,
  });
  final Widget large, top, bottom;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 310 ||
          MediaQuery.textScalerOf(context).scale(14) > 18) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            large,
            const SizedBox(height: journalGap),
            top,
            const SizedBox(height: journalGap),
            bottom,
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: large),
            const SizedBox(width: journalGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [top, const SizedBox(height: journalGap), bottom],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class JournalLink extends StatelessWidget {
  const JournalLink({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.palette,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final SectionPalette palette;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => JournalPanel(
    palette: palette,
    watermark: icon,
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: palette.soft.withValues(alpha: .6),
          child: Icon(icon, color: palette.deep, size: 25),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: palette.deep,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, height: 1.4, color: palette.accent),
        ),
      ],
    ),
  );
}

Widget journalSection(String title, {Widget? trailing}) => Padding(
  padding: const EdgeInsets.only(top: 22, bottom: 12),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      if (trailing != null) trailing,
    ],
  ),
);

class AffairsJournal extends StatefulWidget {
  const AffairsJournal({
    super.key,
    required this.tasks,
    required this.courses,
    required this.goals,
    required this.term,
    required this.onToggle,
    required this.onTask,
    required this.onAllTasks,
    required this.onCourses,
    required this.onGoals,
    required this.onVolunteer,
    required this.onRefresh,
  });
  final List<RowData> tasks, courses, goals;
  final String term;
  final Future<void> Function(RowData, bool) onToggle;
  final ValueChanged<RowData?> onTask;
  final VoidCallback onAllTasks, onCourses, onGoals, onVolunteer;
  final Future<void> Function() onRefresh;
  @override
  State<AffairsJournal> createState() => _AffairsJournalState();
}

class _AffairsJournalState extends State<AffairsJournal> {
  final Set<int> saving = {};
  Future<void> toggle(RowData task, bool done) async {
    final id = rowId(task);
    if (saving.contains(id)) return;
    setState(() => saving.add(id));
    try {
      await widget.onToggle(task, done);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败：$e')));
    } finally {
      if (mounted) setState(() => saving.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final termGoals = goalsInTerm(widget.goals, widget.term);
    final progress = termProgress(termGoals);
    final pending = widget.tasks.where((t) => t['done'] != 1).toList();
    final completed = widget.tasks.length - pending.length;
    final volunteer =
        widget.goals.where((g) => val(g, 'category').contains('志愿')).length;
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          const JournalHeading(
            title: '事务',
            subtitle: '把想做的事，慢慢完成。',
            icon: Icons.task_alt,
            palette: ocean,
            companions: true,
          ),
          JournalPanel(
            palette: ocean,
            watermark: Icons.nightlight_round,
            onTap: widget.onGoals,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本学期 · 学业管理',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.term,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: ocean.deep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      progress == null ? '待设置' : '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: progress == null ? 17 : 26,
                        fontWeight: FontWeight.w700,
                        color: ocean.deep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (progress != null) ...[
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: ocean.soft,
                    color: ocean.accent,
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  progress == null
                      ? '添加学期目标，记录自己的进度'
                      : '${termGoals.length} 项目标的平均完成度 · 点此更新',
                  style: TextStyle(fontSize: 12, color: ocean.accent),
                ),
              ],
            ),
          ),
          journalSection('管理我的事情'),
          JournalBento(
            large: JournalPanel(
              palette: ocean,
              watermark: Icons.school_rounded,
              onTap: widget.onCourses,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: ocean.soft,
                    child: Icon(
                      Icons.school_outlined,
                      color: ocean.deep,
                      size: 30,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '课程与作业',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: ocean.deep,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${widget.courses.length} 门课程 · 课表与 DDL',
                          style: TextStyle(fontSize: 12, color: ocean.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            top: JournalLink(
              title: '学期目标',
              subtitle: '${termGoals.length} 项本学期要求',
              icon: Icons.track_changes,
              palette: oceanPale,
              onTap: widget.onGoals,
            ),
            bottom: JournalLink(
              title: '志愿记录',
              subtitle: '$volunteer 项志愿目标与进展',
              icon: Icons.volunteer_activism_outlined,
              palette: oceanShade,
              onTap: widget.onVolunteer,
            ),
          ),
          journalSection(
            '接下来要做',
            trailing: TextButton(
              onPressed: widget.onAllTasks,
              child: const Text('全部待办'),
            ),
          ),
          if (widget.tasks.isNotEmpty)
            Text(
              '$completed / ${widget.tasks.length} 已完成',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          if (pending.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: ocean.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.tasks.isEmpty
                          ? '还没有待办，给想做的事留个位置。'
                          : '都完成啦，今天也可以慢一点。',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onTask(null),
                    child: const Text('添加'),
                  ),
                ],
              ),
            ),
          ...pending.take(1).map((t) {
            final course =
                widget.courses
                    .where((c) => c['id'] == t['course_id'])
                    .firstOrNull;
            final details = [
              if (course != null) val(course, 'name'),
              if (val(t, 'due_date').isNotEmpty) '截止 ${val(t, 'due_date')}',
            ];
            return Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 14,
                  leading: Checkbox(
                    value: false,
                    onChanged:
                        saving.contains(rowId(t))
                            ? null
                            : (v) => toggle(t, v == true),
                  ),
                  title: Text(val(t, 'title')),
                  subtitle:
                      details.isEmpty
                          ? null
                          : Text(
                            details.join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 19,
                    color: Colors.black38,
                  ),
                  onTap: () => widget.onTask(t),
                ),
                const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class RecordsJournal extends StatefulWidget {
  const RecordsJournal({
    super.key,
    required this.notes,
    required this.moods,
    required this.onNote,
    required this.onMood,
    required this.onMoodDetails,
    required this.onRefresh,
    required this.onTheater,
  });
  final List<RowData> notes, moods;
  final void Function(RowData?, String) onNote;
  final Future<void> Function(String) onMood;
  final VoidCallback onMoodDetails, onTheater;
  final Future<void> Function() onRefresh;
  @override
  State<RecordsJournal> createState() => _RecordsJournalState();
}

class _RecordsJournalState extends State<RecordsJournal> {
  String filter = '全部';
  bool savingMood = false;
  bool includes(RowData n) => switch (filter) {
    '全部' => val(n, 'kind') != '重要信息',
    '随笔' => val(n, 'kind') == '随笔',
    '日记' => val(n, 'kind') == '日记',
    'repo' => ['repo', '观剧感想', '阅读感想'].contains(val(n, 'kind')),
    _ => val(n, 'kind') == filter,
  };
  Future<void> setMood(String emoji) async {
    if (savingMood) return;
    setState(() => savingMood = true);
    try {
      await widget.onMood(emoji);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('心情保存失败：$e')));
    } finally {
      if (mounted) setState(() => savingMood = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today =
        widget.moods
            .where((m) => val(m, 'day') == dayKey(DateTime.now()))
            .firstOrNull;
    final selected = today == null ? '' : val(today, 'emoji');
    final records = widget.notes.where(includes).toList();
    final quote = records.where((n) => val(n, 'kind') == '摘录').firstOrNull;
    final others =
        records
            .where((n) => quote == null || rowId(n) != rowId(quote))
            .take(5)
            .toList();
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          const JournalHeading(
            title: '记录',
            subtitle: '留住想留下的片刻。',
            icon: Icons.edit_note_outlined,
            palette: honey,
          ),
          JournalPanel(
            palette: honey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TODAY’S FEELING",
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected.isEmpty
                            ? '今天的心情是？'
                            : '今天的心情 · ${moodOption(selected).label}',
                        style: TextStyle(fontSize: 18, color: honey.deep),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onMoodDetails,
                      child: Text(today == null ? '写一点' : '心情小记'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                MoodPicker(
                  selected: selected,
                  onChanged: savingMood ? null : setMood,
                  scrollable: true,
                ),
                if (today != null && val(today, 'memo').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      val(today, 'memo'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: honey.deep),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['全部', '随笔', '摘录', 'repo', '日记', '重要信息']
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: filter == s,
                            onSelected: (_) => setState(() => filter = s),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          journalSection(
            '最近的记录',
            trailing: const Text(
              '按日期排列',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '还没有这一类记录，写下第一篇吧。',
                    style: TextStyle(color: Colors.black54),
                  ),
                  TextButton.icon(
                    onPressed:
                        () =>
                            widget.onNote(null, filter == '全部' ? '随笔' : filter),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('开始记录'),
                  ),
                ],
              ),
            ),
          if (quote != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: JournalPanel(
                palette: honey,
                onTap: () => widget.onNote(quote, val(quote, 'kind')),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote, color: honey.accent, size: 23),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '摘录 · ${val(quote, 'entry_date')}',
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: honey.accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      val(quote, 'body').isEmpty
                          ? val(quote, 'title')
                          : val(quote, 'body'),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: honey.deep,
                      ),
                    ),
                    if (val(quote, 'body').isNotEmpty &&
                        val(quote, 'title').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          val(quote, 'title'),
                          style: TextStyle(fontSize: 12, color: honey.accent),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ...others.map(
            (n) => RecordTimelineRow(
              note: n,
              onTap: () => widget.onNote(n, val(n, 'kind')),
            ),
          ),
          if (records.length > (quote == null ? 5 : 6))
            TextButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => _AllRecordsPage(
                            notes: widget.notes.where(includes).toList(),
                            onNote: widget.onNote,
                            onRefresh: widget.onRefresh,
                          ),
                    ),
                  ),
              child: Text('查看全部 ${records.length} 条'),
            ),
          const SizedBox(height: 14),
          JournalPanel(
            palette: rose,
            onTap: widget.onTheater,
            child: Row(
              children: [
                Icon(
                  Icons.theater_comedy_outlined,
                  size: 30,
                  color: rose.accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '我的观剧手记',
                        style: TextStyle(fontSize: 18, color: rose.deep),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '照片、台词和观后感',
                        style: TextStyle(fontSize: 12, color: rose.accent),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.north_east, size: 18, color: rose.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecordTimelineRow extends StatelessWidget {
  const RecordTimelineRow({super.key, required this.note, required this.onTap});
  final RowData note;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final photo = val(note, 'image_path');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43,
              height: 48,
              decoration: BoxDecoration(
                color: honey.light,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.notes_outlined, color: honey.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${val(note, 'kind')} · ${val(note, 'entry_date')}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    val(note, 'title').isEmpty ? '无题的片刻' : val(note, 'title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (val(note, 'body').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        val(note, 'body'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (photo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: storedImage(
                    photo,
                    width: 54,
                    height: 65,
                    cacheWidth: 180,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, _, _) => const SizedBox(
                          width: 54,
                          height: 65,
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AllRecordsPage extends StatelessWidget {
  const _AllRecordsPage({
    required this.notes,
    required this.onNote,
    required this.onRefresh,
  });
  final List<RowData> notes;
  final void Function(RowData?, String) onNote;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('全部记录')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children:
          notes
              .map(
                (n) => RecordTimelineRow(
                  note: n,
                  onTap: () {
                    Navigator.pop(context);
                    onNote(n, val(n, 'kind'));
                  },
                ),
              )
              .toList(),
    ),
  );
}

class ArchiveJournal extends StatelessWidget {
  const ArchiveJournal({
    super.key,
    required this.works,
    required this.covers,
    required this.events,
    required this.notes,
    required this.semesters,
    required this.onWork,
    required this.onBooks,
    required this.onTheater,
    required this.onImportant,
    required this.onSemester,
    required this.onCloud,
    required this.onRefresh,
  });
  final List<RowData> works, events, notes, semesters;
  final Map<int, String> covers;
  final ValueChanged<RowData> onWork;
  final VoidCallback onBooks, onTheater, onImportant, onCloud;
  final ValueChanged<RowData> onSemester;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) {
    final theater = events.where((e) => val(e, 'kind') == '观剧').firstOrNull;
    final important = notes.where((n) => val(n, 'kind') == '重要信息').toList();
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          const JournalHeading(
            title: '档案',
            subtitle: '把喜欢的东西好好收藏。',
            icon: Icons.auto_stories_outlined,
            palette: forest,
            companions: true,
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '我的收藏柜',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed:
                    () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder:
                          (sheet) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final item in [
                                  ('阅读书架', onBooks),
                                  ('观剧档案', onTheater),
                                  ('重要信息', onImportant),
                                  ('云次方', onCloud),
                                ])
                                  ListTile(
                                    title: Text(item.$1),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.pop(sheet);
                                      item.$2();
                                    },
                                  ),
                              ],
                            ),
                          ),
                    ),
                child: const Text('全部分类'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          JournalBento(
            large: JournalPanel(
              palette: forest,
              watermark: Icons.menu_book_rounded,
              onTap: onBooks,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '阅读书架',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: forest.deep,
                          ),
                        ),
                      ),
                      Icon(Icons.north_east, color: forest.accent, size: 18),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: BookSpines(
                      works: works.take(3).toList(),
                      covers: covers,
                      onWork: onWork,
                    ),
                  ),
                  Text(
                    works.isEmpty
                        ? '放上喜欢的第一本书'
                        : '${works.length} 本作品 · 文学 / 娱乐',
                    style: TextStyle(fontSize: 12, color: forest.accent),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    color: forest.accent.withValues(alpha: .4),
                  ),
                ],
              ),
            ),
            top: JournalPanel(
              palette: forest,
              watermark: Icons.confirmation_number_rounded,
              onTap: onTheater,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 22,
                        color: forest.accent,
                      ),
                      const Spacer(),
                      Icon(Icons.north_east, size: 16, color: forest.accent),
                    ],
                  ),
                  const SizedBox(height: 13),
                  Text(
                    '观剧档案',
                    style: TextStyle(fontSize: 18, color: forest.deep),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    theater == null ? '剧目 · 场次 · 观后感' : val(theater, 'title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: forest.accent),
                  ),
                ],
              ),
            ),
            bottom: JournalLink(
              title: '重要信息',
              subtitle:
                  important.isEmpty
                      ? '长期资料 · 常用信息'
                      : '${important.length} 条资料，随时查阅',
              icon: Icons.bookmark_outline,
              palette: forest,
              onTap: onImportant,
            ),
          ),
          journalSection('我的学期档案'),
          if (semesters.isEmpty)
            const Text(
              '课程与目标会按已有学期保存在这里。',
              style: TextStyle(color: Colors.black54),
            ),
          ...semesters.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: JournalPanel(
                palette: forest,
                watermark: Icons.school_rounded,
                padding: 8,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.school_outlined, color: forest.accent),
                  title: Text(val(s, 'name')),
                  subtitle: const Text(
                    '课程 · 学期目标 · 志愿进展',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => onSemester(s),
                ),
              ),
            ),
          ),
          journalSection('云次方'),
          JournalPanel(
            palette: forest,
            watermark: Icons.cloud_rounded,
            onTap: onCloud,
            child: Row(
              children: [
                Icon(Icons.cloud_outlined, color: forest.accent, size: 30),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('感想与照片', style: TextStyle(fontSize: 17)),
                      SizedBox(height: 5),
                      Text(
                        '收藏喜欢的瞬间，也为首页选一张图。',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.north_east, color: forest.accent, size: 18),
              ],
            ),
          ),
          journalSection(
            '常用资料',
            trailing: TextButton(
              onPressed: onImportant,
              child: const Text('查看全部'),
            ),
          ),
          if (important.isEmpty)
            const Text(
              '把常用资料放进重要信息，需要时能很快找到。',
              style: TextStyle(color: Colors.black54, height: 1.6),
            ),
          ...important
              .take(3)
              .map(
                (n) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.push_pin_outlined, size: 19),
                  title: Text(
                    val(n, 'title').isEmpty ? val(n, 'body') : val(n, 'title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(val(n, 'entry_date')),
                  onTap: onImportant,
                ),
              ),
        ],
      ),
    );
  }
}

class BookSpines extends StatelessWidget {
  const BookSpines({
    super.key,
    required this.works,
    required this.covers,
    required this.onWork,
  });
  final List<RowData> works;
  final Map<int, String> covers;
  final ValueChanged<RowData> onWork;
  @override
  Widget build(BuildContext context) {
    if (works.isEmpty)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Icon(
          Icons.menu_book_outlined,
          size: 48,
          color: forest.accent.withValues(alpha: .65),
        ),
      );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < works.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == works.length - 1 ? 0 : 5),
              child: Semantics(
                button: true,
                label: '打开作品 ${val(works[i], 'name')}',
                child: InkWell(
                  onTap: () => onWork(works[i]),
                  child: Container(
                    height:
                        [100.0, 118.0, 90.0][i % 3] *
                        MediaQuery.textScalerOf(context).scale(12) /
                        12,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color:
                          [
                            forest.accent,
                            forest.deep,
                            const Color(0xFF8B9A74),
                          ][i % 3],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child:
                        covers[rowId(works[i])] == null
                            ? _bookTitle(works[i])
                            : storedImage(
                              covers[rowId(works[i])]!,
                              fit: BoxFit.cover,
                              cacheWidth: 240,
                              errorBuilder: (_, _, _) => _bookTitle(works[i]),
                            ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bookTitle(RowData work) => Padding(
    padding: const EdgeInsets.all(7),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          val(work, 'name'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${val(work, 'progress')}%',
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}
