import 'package:flutter/material.dart';
import 'storage.dart';
import 'theme.dart';
import 'editors.dart';
import 'journal_pages.dart';

const studyKinds = ['平常作业', '复习', '考试', '大作业', '上机'];

class TaskDetail extends StatefulWidget {
  const TaskDetail({super.key, required this.initial, required this.courses});
  final RowData initial;
  final List<RowData> courses;
  @override
  State<TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends State<TaskDetail> {
  late RowData task = widget.initial;
  bool busy = false;
  Future<void> refresh() async {
    final rows = await Store.instance.all(
      'tasks',
      where: 'id = ?',
      whereArgs: [task['id']],
    );
    if (!mounted) return;
    if (rows.isEmpty) {
      Navigator.pop(context, true);
    } else {
      setState(() => task = rows.single);
    }
  }

  Future<void> toggle() async {
    setState(() => busy = true);
    try {
      final fields = Map<String, Object?>.from(task)..remove('id');
      fields['done'] = task['done'] == 1 ? 0 : 1;
      await Store.instance.upsert('tasks', fields, id: rowId(task));
      await refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败：$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = entryPalette(context, ocean);
    final course =
        widget.courses.where((c) => c['id'] == task['course_id']).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('待办详情'),
        actions: [
          IconButton(
            tooltip: '编辑待办',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => palettePage(
                        context,
                        TaskEditor(existing: task, courses: widget.courses),
                      ),
                ),
              );
              await refresh();
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          JournalPanel(
            palette: p,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['done'] == 1 ? '已经完成' : '慢慢来，一件一件完成',
                  style: TextStyle(color: p.accent, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Text(
                  val(task, 'title'),
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: p.deep,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (course != null) Chip(label: Text(val(course, 'name'))),
                    if (course != null)
                      Chip(label: Text(val(task, 'study_kind'))),
                    if (val(task, 'due_date').isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.event_outlined, size: 16),
                        label: Text('截止 ${val(task, 'due_date')}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '这件事的细节',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SelectableText(
            val(task, 'detail').isEmpty
                ? '还没有备注，可以在编辑里补充。'
                : val(task, 'detail'),
            style: const TextStyle(height: 1.8),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: busy ? null : toggle,
            icon: Icon(task['done'] == 1 ? Icons.undo : Icons.check),
            label: Text(task['done'] == 1 ? '重新打开待办' : '标记为完成'),
          ),
        ],
      ),
    );
  }
}

class StudyBoard extends StatefulWidget {
  const StudyBoard({
    super.key,
    required this.openTask,
    required this.openCourse,
  });
  final Future<void> Function(RowData?, int?, String?) openTask;
  final Future<void> Function(RowData?) openCourse;
  @override
  State<StudyBoard> createState() => _StudyBoardState();
}

class _StudyBoardState extends State<StudyBoard> {
  List<RowData> courses = [], tasks = [];
  String category = '全部', tab = '学习待办';
  int? courseId;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await Future.wait([
        Store.instance.all('courses', orderBy: 'id'),
        Store.instance.all(
          'tasks',
          where: 'course_id IS NOT NULL',
          orderBy: 'done, due_date, id DESC',
        ),
      ]);
      if (mounted)
        setState(() {
          courses = rows[0];
          tasks = rows[1];
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = entryPalette(context, ocean);
    final filtered =
        tasks
            .where(
              (t) =>
                  (category == '全部' || val(t, 'study_kind') == category) &&
                  (courseId == null || t['course_id'] == courseId),
            )
            .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('课程与作业')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (tab == '课程管理') {
            await widget.openCourse(null);
          } else {
            if (courses.isEmpty) {
              await widget.openCourse(null);
            } else {
              await widget.openTask(
                null,
                courseId ?? rowId(courses.first),
                category == '全部' ? '平常作业' : category,
              );
            }
          }
          await load();
        },
        icon: const Icon(Icons.add),
        label: Text(tab == '课程管理' ? '添加课程' : '学习待办'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            SegmentedButton<String>(
              segments:
                  ['学习待办', '课程管理']
                      .map((t) => ButtonSegment(value: t, label: Text(t)))
                      .toList(),
              selected: {tab},
              onSelectionChanged: (v) => setState(() => tab = v.first),
            ),
            const SizedBox(height: 18),
            if (error != null) Text(error!),
            if (tab == '课程管理')
              ...courses.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: JournalPanel(
                    palette: p,
                    onTap: () async {
                      await widget.openCourse(c);
                      await load();
                    },
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(val(c, 'name')),
                      subtitle: Text(
                        '${val(c, 'semester')} · ${val(c, 'teacher')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                ),
              )
            else ...[
              const Text(
                '学习有关',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '只展示已关联课程的待办。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: courseId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '按课程查看'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('全部课程'),
                  ),
                  ...courses.map(
                    (c) => DropdownMenuItem(
                      value: rowId(c),
                      child: Text(val(c, 'name')),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => courseId = v),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      ['全部', ...studyKinds]
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                label: Text(s),
                                selected: category == s,
                                onSelected: (_) => setState(() => category = s),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('这一类还没有学习待办，点右下角添加。'),
                ),
              ...filtered.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: JournalPanel(
                    palette: p,
                    onTap: () async {
                      await widget.openTask(t, null, null);
                      await load();
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          val(
                            courses
                                    .where((c) => c['id'] == t['course_id'])
                                    .firstOrNull ??
                                {},
                            'name',
                          ),
                          style: TextStyle(fontSize: 11, color: p.accent),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          val(t, 'title'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: p.deep,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${val(t, 'study_kind')} · ${t['done'] == 1 ? '已完成' : '待完成'}${val(t, 'due_date').isEmpty ? '' : ' · ${val(t, 'due_date')}'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
