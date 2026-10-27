import 'stored_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'storage.dart';
import 'theme.dart';
import 'schedule.dart';
import 'mood_art.dart';

Future<bool> confirmDelete(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('确认删除？'),
            content: const Text('删除后无法在 App 内撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('删除'),
              ),
            ],
          ),
    ) ??
    false;

Future<DateTime?> selectDate(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

class EditLayout extends StatefulWidget {
  const EditLayout({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.onDelete,
    this.palette = ocean,
  });
  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;
  final VoidCallback? onDelete;
  final SectionPalette palette;
  @override
  State<EditLayout> createState() => _EditLayoutState();
}

class _EditLayoutState extends State<EditLayout> {
  bool saving = false;

  Future<void> submit() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.onSave();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: richangTheme(seedColor: entryPalette(context, widget.palette).accent),
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: saving ? null : submit,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
          if (widget.onDelete != null)
            IconButton(
              tooltip: '删除',
              onPressed: saving ? null : widget.onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            ...widget.children.expand(
              (child) => [child, const SizedBox(height: 14)],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({
    super.key,
    this.existing,
    required this.courses,
    this.initialCourseId,
    this.initialStudyKind,
  });
  final RowData? existing;
  final List<RowData> courses;
  final int? initialCourseId;
  final String? initialStudyKind;
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final TextEditingController title;
  late final TextEditingController detail;
  String? due;
  int? courseId;
  late String studyKind;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(
      text: widget.existing == null ? '' : val(widget.existing!, 'title'),
    );
    detail = TextEditingController(
      text: widget.existing == null ? '' : val(widget.existing!, 'detail'),
    );
    studyKind =
        widget.existing == null
            ? (widget.initialStudyKind ?? '平常作业')
            : val(widget.existing!, 'study_kind');
    if (studyKind.isEmpty) studyKind = '平常作业';
    due = widget.existing?['due_date'] as String?;
    courseId =
        (widget.existing?['course_id'] as int?) ?? widget.initialCourseId;
    if (courseId != null && !widget.courses.any((c) => rowId(c) == courseId))
      courseId = null;
  }

  @override
  void dispose() {
    title.dispose();
    detail.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty || saving) return;
    setState(() => saving = true);
    try {
      await Store.instance.upsert('tasks', {
        'title': title.text.trim(),
        'detail': detail.text.trim(),
        'due_date': due,
        'course_id': courseId,
        'study_kind': studyKind,
        'done': widget.existing?['done'] ?? 0,
        'created_at':
            widget.existing?['created_at'] ?? DateTime.now().toIso8601String(),
      }, id: widget.existing == null ? null : rowId(widget.existing!));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => EditLayout(
    title: widget.existing == null ? '新建待办' : '编辑待办',
    onSave: save,
    onDelete:
        widget.existing == null
            ? null
            : () async {
              if (await confirmDelete(context)) {
                await Store.instance.delete('tasks', rowId(widget.existing!));
                if (context.mounted) Navigator.pop(context, true);
              }
            },
    children: [
      TextField(
        controller: title,
        autofocus: true,
        decoration: const InputDecoration(labelText: '要完成什么？ *'),
      ),
      TextField(
        controller: detail,
        maxLines: 3,
        decoration: const InputDecoration(labelText: '备注（可不填）'),
      ),
      ListTile(
        tileColor: entryPalette(context, ocean).light,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: const Icon(Icons.event_outlined),
        title: Text(due == null ? '设置截止日期' : '截止：$due'),
        trailing:
            due == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                  tooltip: '清除日期',
                  onPressed: () => setState(() => due = null),
                  icon: const Icon(Icons.close),
                ),
        onTap: () async {
          final chosen = await selectDate(
            context,
            tryDay(due ?? '') ?? DateTime.now(),
          );
          if (chosen != null) setState(() => due = dayKey(chosen));
        },
      ),
      DropdownButtonFormField<int?>(
        initialValue: courseId,
        decoration: const InputDecoration(labelText: '关联课程'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('不关联课程')),
          ...widget.courses.map(
            (x) => DropdownMenuItem<int?>(
              value: rowId(x),
              child: Text(val(x, 'name')),
            ),
          ),
        ],
        onChanged: (v) => setState(() => courseId = v),
      ),
      if (courseId != null)
        DropdownButtonFormField<String>(
          initialValue: studyKind,
          decoration: const InputDecoration(labelText: '学习分类'),
          items:
              [
                '平常作业',
                '复习',
                '考试',
                '大作业',
                '上机',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => studyKind = v ?? studyKind),
        ),
      const Text(
        '勾选完成后仍保留在课程及历史列表中。',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
    ],
  );
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    this.existing,
    this.initialKind = '随笔',
    this.initialFolderId,
    this.folders = const [],
    this.initialLinks = const [],
    this.linkTargets = const [],
  });
  final int? initialFolderId;
  final List<RowData> folders, initialLinks, linkTargets;
  final RowData? existing;
  final String initialKind;
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController title, body;
  late String kind, entryDate;
  String? photo;
  int? folderId;
  late List<RowData> links;
  bool saving = false;
  static const kinds = ['随笔', '日记', '摘录', 'repo', '观剧感想', '阅读感想', '重要信息'];
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    title = TextEditingController(text: e == null ? '' : val(e, 'title'));
    body = TextEditingController(text: e == null ? '' : val(e, 'body'));
    kind = e == null ? widget.initialKind : val(e, 'kind');
    entryDate = e == null ? dayKey(DateTime.now()) : val(e, 'entry_date');
    photo = e?['image_path'] as String?;
    folderId = e == null ? widget.initialFolderId : e['folder_id'] as int?;
    if (!widget.folders.any((f) => f['id'] == folderId)) folderId = null;
    links =
        widget.initialLinks.map((l) => Map<String, Object?>.from(l)).toList();
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> chooseLinks() async {
    final selected =
        links.map((l) => '${l['target_table']}:${l['target_id']}').toSet();
    String query = '';
    final changed = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (c, update) => AlertDialog(
                  title: const Text('关联已有内容'),
                  content: SizedBox(
                    width: 360,
                    height: 380,
                    child: Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            hintText: '搜索记录、课程、作品、日程或目标',
                          ),
                          onChanged: (s) => update(() => query = s),
                        ),
                        Expanded(
                          child: ListView(
                            children:
                                widget.linkTargets
                                    .where(
                                      (t) =>
                                          !(t['target_table'] == 'entries' &&
                                              t['target_id'] ==
                                                  widget.existing?['id']) &&
                                          val(t, 'label').contains(query),
                                    )
                                    .map((t) {
                                      final key =
                                          '${t['target_table']}:${t['target_id']}';
                                      return CheckboxListTile(
                                        title: Text(val(t, 'label')),
                                        value: selected.contains(key),
                                        onChanged:
                                            (v) => update(
                                              () =>
                                                  v == true
                                                      ? selected.add(key)
                                                      : selected.remove(key),
                                            ),
                                      );
                                    })
                                    .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('确定'),
                    ),
                  ],
                ),
          ),
    );
    if (changed == true && mounted)
      setState(
        () =>
            links =
                widget.linkTargets
                    .where(
                      (t) => selected.contains(
                        '${t['target_table']}:${t['target_id']}',
                      ),
                    )
                    .map(
                      (t) => <String, Object?>{
                        'target_table': t['target_table'],
                        'target_id': t['target_id'],
                      },
                    )
                    .toList(),
      );
  }

  Future<void> chooseImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (picked == null) return;
      final saved = await Store.instance.copyPhoto(picked.path);
      if (mounted) setState(() => photo = saved);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入图片失败：$e')));
    }
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty && body.text.trim().isEmpty || saving) return;
    setState(() => saving = true);
    try {
      final now = DateTime.now().toIso8601String();
      await Store.instance.saveEntry(
        {
          'title': title.text.trim(),
          'body': body.text,
          'kind': kind,
          'entry_date': entryDate,
          'image_path': photo,
          'folder_id': folderId,
          'created_at': widget.existing?['created_at'] ?? now,
          'updated_at': now,
        },
        links,
        id: widget.existing == null ? null : rowId(widget.existing!),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => EditLayout(
    title: widget.existing == null ? '写一点什么' : '编辑记录',
    palette: entryPalette(context, honey),
    onSave: save,
    onDelete:
        widget.existing == null
            ? null
            : () async {
              if (await confirmDelete(context)) {
                await Store.instance.delete('entries', rowId(widget.existing!));
                if (context.mounted) Navigator.pop(context, true);
              }
            },
    children: [
      DropdownButtonFormField<int?>(
        initialValue: folderId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: '所属文件夹'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('未分类')),
          ...widget.folders.map(
            (f) => DropdownMenuItem(
              value: rowId(f),
              child: Text(folderLabel(f, widget.folders)),
            ),
          ),
        ],
        onChanged: (v) => setState(() => folderId = v),
      ),
      OutlinedButton.icon(
        onPressed: chooseLinks,
        icon: const Icon(Icons.hub_outlined),
        label: Text('关联内容（${links.length}）'),
      ),

      DropdownButtonFormField<String>(
        initialValue: kind,
        decoration: const InputDecoration(labelText: '记录类型'),
        items:
            kinds
                .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                .toList(),
        onChanged: (v) => setState(() => kind = v ?? kind),
      ),
      TextField(
        controller: title,
        decoration: const InputDecoration(labelText: '标题（可选）'),
      ),
      TextField(
        controller: body,
        maxLines: 10,
        minLines: 6,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          labelText: '写下想留住的这一刻……',
          alignLabelWithHint: true,
        ),
      ),
      ListTile(
        tileColor: entryPalette(context, honey).light,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text('记录日期：$entryDate'),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: () async {
          final chosen = await selectDate(
            context,
            tryDay(entryDate) ?? DateTime.now(),
          );
          if (chosen != null) setState(() => entryDate = dayKey(chosen));
        },
      ),
      if (photo != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: storedImage(
                photo!,
                height: 145,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Text('原图片不可用'),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => photo = null),
              icon: const Icon(Icons.close),
              label: const Text('移除图片关联'),
            ),
          ],
        ),
      OutlinedButton.icon(
        onPressed: chooseImage,
        icon: const Icon(Icons.photo_library_outlined),
        label: Text(photo == null ? '从相册添加图片' : '更换图片'),
      ),
      if (kind == '重要信息')
        SoftCard(
          color: entryPalette(context, honey).light,
          child: Text(
            '请勿在普通重要信息中保存密码、验证码、恢复码等秘密。此版本数据库未加密。',
            style: TextStyle(fontSize: 12),
          ),
        ),
      const Text(
        '当前版本支持每条记录附一张图片；多图片、富文本和自动草稿将在后续版本添加。',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}

class CourseEditor extends StatefulWidget {
  const CourseEditor({super.key, this.existing, this.meetings = const []});
  final RowData? existing;
  final List<RowData> meetings;
  @override
  State<CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<CourseEditor> {
  late final TextEditingController name,
      teacher,
      room,
      semester,
      start,
      end,
      credits;
  int? weekday;
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    name = TextEditingController(text: e == null ? '' : val(e, 'name'));
    teacher = TextEditingController(text: e == null ? '' : val(e, 'teacher'));
    room = TextEditingController(text: e == null ? '' : val(e, 'room'));
    semester = TextEditingController(
      text: e == null ? '2026 秋' : val(e, 'semester'),
    );
    start = TextEditingController(
      text: e == null ? '08:00' : val(e, 'start_time'),
    );
    end = TextEditingController(text: e == null ? '09:40' : val(e, 'end_time'));
    credits = TextEditingController(text: e == null ? '2' : val(e, 'credits'));
    weekday = e?['weekday'] as int?;
  }

  @override
  void dispose() {
    for (final c in [name, teacher, room, semester, start, end, credits]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    try {
      await Store.instance.upsert('courses', {
        'name': name.text.trim(),
        'teacher': teacher.text.trim(),
        'room': room.text.trim(),
        'semester': semester.text.trim(),
        'start_time': start.text.trim(),
        'end_time': end.text.trim(),
        'credits': double.tryParse(credits.text) ?? 0,
        'weekday': weekday,
      }, id: widget.existing == null ? null : rowId(widget.existing!));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) => EditLayout(
    title: widget.existing == null ? '添加课程' : '编辑课程',
    onSave: save,
    onDelete:
        widget.existing == null
            ? null
            : () async {
              if (await confirmDelete(context)) {
                await Store.instance.delete('courses', rowId(widget.existing!));
                if (context.mounted) Navigator.pop(context, true);
              }
            },
    children: [
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: '课程名称 *'),
      ),
      TextField(
        controller: semester,
        readOnly: widget.existing?['semester_id'] != null,
        decoration: const InputDecoration(labelText: '所属学期'),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: teacher,
              decoration: const InputDecoration(labelText: '教师'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: room,
              decoration: const InputDecoration(labelText: '教室'),
            ),
          ),
        ],
      ),
      DropdownButtonFormField<int?>(
        initialValue: weekday,
        decoration: const InputDecoration(labelText: '每周上课日'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('暂不设置')),
          ...List.generate(
            7,
            (i) => DropdownMenuItem<int?>(
              value: i + 1,
              child: Text('星期${'一二三四五六日'[i]}'),
            ),
          ),
        ],
        onChanged: (v) => setState(() => weekday = v),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: start,
              decoration: const InputDecoration(labelText: '开始 HH:mm'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: end,
              decoration: const InputDecoration(labelText: '结束 HH:mm'),
            ),
          ),
        ],
      ),
      TextField(
        controller: credits,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: '课程学分'),
      ),
      const Text(
        '手动课程按每周固定星期展示；导入课程按下方教学周与节次安排显示。',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
      if (widget.meetings.isNotEmpty) ...[
        const SectionTitle('导入的上课安排'),
        ...widget.meetings.map(
          (m) => ListTile(
            title: Text(
              '周${'一二三四五六日'[(m['weekday'] as int) - 1]} · ${sessionLabel(m)}',
            ),
            subtitle: Text(
              '${val(m, 'weeks_text')}\n${val(m, 'teacher')} · ${val(m, 'room')}',
            ),
          ),
        ),
      ],
      if (val(widget.existing ?? {}, 'schedule_note').isNotEmpty)
        Text(val(widget.existing!, 'schedule_note')),
    ],
  );
}

class EventEditor extends StatefulWidget {
  const EventEditor({
    super.key,
    this.existing,
    this.initialDay,
    this.initialKind = '日程',
  });
  final String initialKind;
  final RowData? existing;
  final DateTime? initialDay;
  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final TextEditingController title, time, location, memo;
  late String day, kind;
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    title = TextEditingController(text: e == null ? '' : val(e, 'title'));
    time = TextEditingController(text: e == null ? '19:30' : val(e, 'time'));
    location = TextEditingController(text: e == null ? '' : val(e, 'location'));
    memo = TextEditingController(text: e == null ? '' : val(e, 'memo'));
    day =
        e == null ? dayKey(widget.initialDay ?? DateTime.now()) : val(e, 'day');
    kind = e == null ? widget.initialKind : val(e, 'kind');
  }

  @override
  void dispose() {
    for (final c in [title, time, location, memo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) return;
    try {
      await Store.instance.upsert('events', {
        'title': title.text.trim(),
        'time': time.text.trim(),
        'location': location.text.trim(),
        'memo': memo.text.trim(),
        'day': day,
        'kind': kind,
      }, id: widget.existing == null ? null : rowId(widget.existing!));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) => EditLayout(
    title: widget.existing == null ? '添加日程' : '编辑日程',
    palette: kind == '观剧' ? rose : ocean,
    onSave: save,
    onDelete:
        widget.existing == null
            ? null
            : () async {
              if (await confirmDelete(context)) {
                await Store.instance.delete('events', rowId(widget.existing!));
                if (context.mounted) Navigator.pop(context, true);
              }
            },
    children: [
      TextField(
        controller: title,
        decoration: const InputDecoration(labelText: '日程名称 *'),
      ),
      DropdownButtonFormField<String>(
        initialValue: kind,
        decoration: const InputDecoration(labelText: '类型'),
        items:
            [
              '日程',
              '观剧',
              '志愿',
              '考试',
              '其他',
            ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
        onChanged: (v) => setState(() => kind = v ?? kind),
      ),
      ListTile(
        tileColor:
            kind == '观剧'
                ? entryPalette(context, rose).light
                : entryPalette(context, ocean).light,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: const Icon(Icons.calendar_month),
        title: Text(day),
        onTap: () async {
          final chosen = await selectDate(
            context,
            tryDay(day) ?? DateTime.now(),
          );
          if (chosen != null) setState(() => day = dayKey(chosen));
        },
      ),
      TextField(
        controller: time,
        decoration: const InputDecoration(labelText: '时间（例如 19:30）'),
      ),
      TextField(
        controller: location,
        decoration: const InputDecoration(labelText: '地点 / 剧院'),
      ),
      TextField(
        controller: memo,
        maxLines: 4,
        decoration: const InputDecoration(labelText: '座位、场次、卡司、备注等'),
      ),
      const Text(
        '观剧与志愿活动暂以日程类型记录；更完整的多场次档案和时长认定将在后续版本提供。',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
    ],
  );
}

class WorkEditor extends StatefulWidget {
  const WorkEditor({super.key, this.existing, this.initialShelf = '文学'});
  final String initialShelf;
  final RowData? existing;
  @override
  State<WorkEditor> createState() => _WorkEditorState();
}

class _WorkEditorState extends State<WorkEditor> {
  late final TextEditingController name, author, memo;
  late String type, status, shelf;
  late int progress;
  String? cover;
  bool loadingCover = false;
  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    name = TextEditingController(text: e == null ? '' : val(e, 'name'));
    author = TextEditingController(text: e == null ? '' : val(e, 'author'));
    memo = TextEditingController(text: e == null ? '' : val(e, 'memo'));
    type = e == null ? '小说' : val(e, 'type');
    shelf = e == null ? widget.initialShelf : val(e, 'shelf');
    if (shelf.isEmpty) shelf = '文学';
    status = e == null ? '想读' : val(e, 'status');
    progress = e?['progress'] as int? ?? 0;
    if (e != null) {
      loadingCover = true;
      loadCover(rowId(e));
    }
  }

  Future<void> loadCover(int id) async {
    try {
      final covers = await Store.instance.bookCovers();
      if (mounted) setState(() => cover = covers[id]);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('封面读取失败：$e')));
    } finally {
      if (mounted) setState(() => loadingCover = false);
    }
  }

  Future<void> chooseCover() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final path = await Store.instance.copyPhoto(image.path);
      if (mounted) setState(() => cover = path);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('封面导入失败：$e')));
    }
  }

  @override
  void dispose() {
    name.dispose();
    author.dispose();
    memo.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || loadingCover) return;
    try {
      await Store.instance.saveWork(
        {
          'name': name.text.trim(),
          'author': author.text.trim(),
          'memo': memo.text.trim(),
          'type': type,
          'status': status,
          'progress': progress,
          'shelf': shelf,
        },
        id: widget.existing == null ? null : rowId(widget.existing!),
        cover: cover,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) => EditLayout(
    title: widget.existing == null ? '添加阅读作品' : '编辑阅读作品',
    palette: entryPalette(context, forest),
    onSave: save,
    onDelete:
        widget.existing == null
            ? null
            : () async {
              if (await confirmDelete(context)) {
                await Store.instance.delete('works', rowId(widget.existing!));
                if (context.mounted) Navigator.pop(context, true);
              }
            },
    children: [
      TextField(
        controller: name,
        decoration: const InputDecoration(labelText: '作品名 *'),
      ),
      DropdownButtonFormField<String>(
        initialValue: shelf,
        decoration: const InputDecoration(labelText: '书架分类'),
        items:
            [
              '文学',
              '娱乐',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => shelf = v ?? shelf),
      ),
      TextField(
        controller: author,
        decoration: const InputDecoration(labelText: '作者'),
      ),
      OutlinedButton.icon(
        onPressed: loadingCover ? null : chooseCover,
        icon: const Icon(Icons.photo_outlined),
        label: Text(cover == null ? '添加作品封面' : '更换作品封面'),
      ),
      if (cover != null) ...[
        storedImage(
          cover!,
          height: 180,
          cacheWidth: 480,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text('封面暂时无法读取'),
        ),
        TextButton(
          onPressed: () => setState(() => cover = null),
          child: const Text('移除作品封面'),
        ),
      ],
      DropdownButtonFormField<String>(
        initialValue: type,
        decoration: const InputDecoration(labelText: '类型'),
        items:
            [
              '小说',
              '漫画',
              '文学',
              '其他',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setState(() => type = v ?? type),
      ),
      DropdownButtonFormField<String>(
        initialValue: status,
        decoration: const InputDecoration(labelText: '阅读状态'),
        items:
            [
              '想读',
              '在读',
              '已读',
              '暂停',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (v) => setState(() => status = v ?? status),
      ),
      Row(children: [const Text('阅读进度'), const Spacer(), Text('$progress%')]),
      Slider(
        min: 0,
        max: 100,
        divisions: 20,
        value: progress.toDouble(),
        label: '$progress%',
        onChanged: (n) => setState(() => progress = n.toInt()),
      ),
      TextField(
        controller: memo,
        maxLines: 4,
        decoration: const InputDecoration(labelText: '阅读感想 / 备注'),
      ),
    ],
  );
}

Future<void> editMood(
  BuildContext context, {
  required String day,
  String? currentEmoji,
  String? currentMemo,
  SectionPalette palette = honey,
}) async {
  final memo = TextEditingController(text: currentMemo ?? '');
  var emoji = currentEmoji ?? '🙂';
  await showDialog<void>(
    context: context,
    builder:
        (dialogContext) => palettePage(
          context,
          StatefulBuilder(
            builder:
                (c, update) => AlertDialog(
                  title: Text('记录心情 · $day'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MoodPicker(
                          selected: emoji,
                          onChanged: (value) => update(() => emoji = value),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: memo,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '今天的心情小记（可选）',
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await Store.instance.upsert('moods', {
                          'emoji': emoji,
                          'memo': memo.text.trim(),
                        }, day: day);
                        if (c.mounted) Navigator.pop(c);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
          ),
          palette,
        ),
  );
  memo.dispose();
}
