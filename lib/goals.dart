import 'package:flutter/material.dart';
import 'editors.dart';
import 'goal_metrics.dart';
import 'storage.dart';
import 'theme.dart';
import 'goal_items.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal, required this.onTap});
  final RowData goal;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final current = goal['current_value'] as num,
        target = goal['target_value'] as num;
    final done = current >= target;
    return SoftCard(
      color: entryPalette(context, ocean).light,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_outline : Icons.flag_outlined,
                color: entryPalette(context, ocean).accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  val(goal, 'title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                done ? '已达成' : '进行中',
                style: TextStyle(
                  fontSize: 11,
                  color: entryPalette(context, ocean).accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            [
              val(goal, 'semester'),
              val(goal, 'category'),
              if (val(goal, 'due_date').isNotEmpty)
                '截止 ${val(goal, 'due_date')}',
            ].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: goalFraction(current, target),
            minHeight: 6,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: entryPalette(context, ocean).soft,
            valueColor: AlwaysStoppedAnimation(
              entryPalette(context, ocean).accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${goalNumberText(current)} / ${goalNumberText(target)} ${val(goal, 'unit')}  ·  ${(current / target * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: entryPalette(context, ocean).deep,
            ),
          ),
        ],
      ),
    );
  }
}

class GoalsSection extends StatefulWidget {
  const GoalsSection({
    super.key,
    required this.goals,
    required this.onAdd,
    required this.onOpen,
  });
  final List<RowData> goals;
  final VoidCallback onAdd;
  final ValueChanged<RowData> onOpen;
  @override
  State<GoalsSection> createState() => _GoalsSectionState();
}

class _GoalsSectionState extends State<GoalsSection> {
  String semester = '全部';
  @override
  Widget build(BuildContext context) {
    final options = {'全部', ...widget.goals.map((g) => val(g, 'semester'))};
    final selected = options.contains(semester) ? semester : '全部';
    final goals =
        widget.goals
            .where((g) => selected == '全部' || val(g, 'semester') == selected)
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          '学期与目标',
          trailing: '添加目标',
          onTrailing: widget.onAdd,
          palette: entryPalette(context, ocean),
        ),
        if (options.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  options
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: selected == s,
                            onSelected: (_) => setState(() => semester = s),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        if (goals.isEmpty)
          SoftCard(
            color: entryPalette(context, ocean).light,
            onTap: widget.onAdd,
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline),
                SizedBox(width: 10),
                Expanded(child: Text('添加学期要求或长期目标，记录每一次进展。')),
              ],
            ),
          ),
        ...goals.map(
          (g) => Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: GoalCard(goal: g, onTap: () => widget.onOpen(g)),
          ),
        ),
      ],
    );
  }
}

class GoalEditor extends StatefulWidget {
  const GoalEditor({
    super.key,
    this.existing,
    this.initialSemester = '2026 秋',
    this.initialCategory = '学业',
  });
  final RowData? existing;
  final String initialSemester;
  final String initialCategory;
  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  late final TextEditingController title,
      semester,
      category,
      detail,
      target,
      current,
      unit;
  String? due;
  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    title = TextEditingController(text: g == null ? '' : val(g, 'title'));
    semester = TextEditingController(
      text: g == null ? widget.initialSemester : val(g, 'semester'),
    );
    category = TextEditingController(
      text: g == null ? widget.initialCategory : val(g, 'category'),
    );
    detail = TextEditingController(text: g == null ? '' : val(g, 'detail'));
    target = TextEditingController(
      text: g == null ? '1' : val(g, 'target_value'),
    );
    current = TextEditingController(
      text: g == null ? '0' : val(g, 'current_value'),
    );
    unit = TextEditingController(text: g == null ? '项' : val(g, 'unit'));
    due = g?['due_date'] as String?;
  }

  @override
  void dispose() {
    for (final c in [
      title,
      semester,
      category,
      detail,
      target,
      current,
      unit,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    try {
      await Store.instance.saveGoal({
        'title': title.text,
        'semester': semester.text,
        'category': category.text,
        'detail': detail.text,
        'unit': unit.text,
        'due_date': due,
        'target_value': goalNumber(target.text, positive: true),
        'current_value': goalNumber(current.text, positive: false),
      }, id: widget.existing == null ? null : rowId(widget.existing!));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is FormatException ? e.message : '保存失败：$e')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => EditLayout(
    title: widget.existing == null ? '添加学期目标' : '编辑目标',
    onSave: save,
    onDelete:
        widget.existing == null
            ? null
            : () async {
              if (!await confirmDelete(context)) return;
              try {
                await Store.instance.delete('goals', rowId(widget.existing!));
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
              }
            },
    children: [
      TextField(
        controller: title,
        decoration: const InputDecoration(labelText: '目标或要求 *'),
      ),
      TextField(
        controller: semester,
        decoration: const InputDecoration(
          labelText: '所属学期 *',
          helperText: '跨学期的要求可以填写“长期”',
        ),
      ),
      TextField(
        controller: category,
        decoration: const InputDecoration(labelText: '分类（如学分、志愿、综测、推免）'),
      ),
      TextField(
        controller: detail,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: '具体要求 / 规则 / 说明',
          alignLabelWithHint: true,
        ),
      ),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '目标值 *'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: unit,
              decoration: const InputDecoration(
                labelText: '单位 *',
                hintText: '项、小时、学分、分、页',
              ),
            ),
          ),
        ],
      ),
      TextField(
        controller: current,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: '当前累计进度 *',
          helperText: '不便量化的要求，可设目标 1 项，完成时更新为 1。',
        ),
      ),
      ListTile(
        tileColor: entryPalette(context, ocean).light,
        title: Text(due == null ? '设置目标截止日期（可选）' : '截止日期：$due'),
        leading: const Icon(Icons.event_outlined),
        trailing:
            due == null
                ? null
                : IconButton(
                  tooltip: '清除截止日期',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => due = null),
                ),
        onTap: () async {
          final day = await selectDate(
            context,
            tryDay(due ?? '') ?? DateTime.now(),
          );
          if (mounted && day != null) setState(() => due = dayKey(day));
        },
      ),
    ],
  );
}

class GoalDetail extends StatefulWidget {
  const GoalDetail({super.key, required this.initial});
  final RowData initial;
  @override
  State<GoalDetail> createState() => _GoalDetailState();
}

class _GoalDetailState extends State<GoalDetail> {
  late RowData goal;
  List<RowData> history = [];
  String? error;
  @override
  void initState() {
    super.initState();
    goal = widget.initial;
    load();
  }

  Future<void> load() async {
    try {
      final rows = await Store.instance.all(
        'goals',
        where: 'id = ?',
        whereArgs: [rowId(goal)],
      );
      if (!mounted) return;
      if (rows.isEmpty) {
        Navigator.pop(context, true);
        return;
      }
      final updates = await Store.instance.all(
        'goal_updates',
        where: 'goal_id = ?',
        whereArgs: [rowId(goal)],
        orderBy: 'id DESC',
      );
      if (mounted)
        setState(() {
          goal = rows.single;
          history = updates;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> update() async {
    final saved = await showDialog<bool>(
      context: context,
      builder:
          (_) => Theme(
            data: richangTheme(seedColor: entryPalette(context, ocean).accent),
            child: _ProgressDialog(goal: goal),
          ),
    );
    if (saved == true && mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: richangTheme(seedColor: entryPalette(context, ocean).accent),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('目标详情'),
        actions: [
          IconButton(
            tooltip: '编辑目标',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => palettePage(context, GoalEditor(existing: goal)),
                ),
              );
              if (changed == true && mounted) await load();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
        children: [
          const Text(
            '总体进度单独维护，分项要求在下方分别记录。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          GoalCard(goal: goal, onTap: update),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: update,
            icon: const Icon(Icons.trending_up),
            label: const Text('更新进度'),
          ),
          if (val(goal, 'detail').isNotEmpty) ...[
            SectionTitle('具体要求', palette: entryPalette(context, ocean)),
            SelectableText(val(goal, 'detail')),
          ],
          GoalItems(goalId: rowId(goal)),
          if (error != null) Text('读取失败：$error'),
          SectionTitle('进度记录', palette: entryPalette(context, ocean)),
          if (history.isEmpty) const Text('还没有进度记录。'),
          ...history.map((h) {
            final before = h['previous_value'] as num,
                after = h['current_value'] as num;
            final delta = after - before;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                delta < 0 ? Icons.undo : Icons.history,
                color: entryPalette(context, ocean).accent,
              ),
              title: Text(
                '${goalNumberText(before)} → ${goalNumberText(after)} ${val(h, 'unit')}  (${delta >= 0 ? '+' : ''}${goalNumberText(delta)})',
              ),
              subtitle: Text(
                '${val(h, 'created_at').replaceFirst('T', ' ').split('.').first}\n${val(h, 'note')}',
              ),
              isThreeLine: true,
            );
          }),
        ],
      ),
    ),
  );
}

class _ProgressDialog extends StatefulWidget {
  const _ProgressDialog({required this.goal});
  final RowData goal;
  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  late final TextEditingController value;
  final note = TextEditingController();
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    value = TextEditingController(text: val(widget.goal, 'current_value'));
  }

  @override
  void dispose() {
    value.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await Store.instance.updateGoalProgress(
        rowId(widget.goal),
        goalNumber(value.text, positive: false),
        note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          saving = false;
          error = e is FormatException ? e.message : '更新失败：$e';
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('更新进度'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '填写最新累计完成量，单位：${val(widget.goal, 'unit')}。可调低以纠正记录。',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '最新累计进度', errorText: error),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '本次进展 / 备注（可选）'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: saving ? null : save, child: const Text('保存进度')),
    ],
  );
}
