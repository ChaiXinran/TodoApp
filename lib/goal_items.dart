import 'package:flutter/material.dart';
import 'storage.dart';
import 'theme.dart';
import 'editors.dart';
import 'goal_metrics.dart';

class GoalItems extends StatefulWidget {
  const GoalItems({super.key, required this.goalId});
  final int goalId;
  @override
  State<GoalItems> createState() => _GoalItemsState();
}

class _GoalItemsState extends State<GoalItems> {
  List<RowData> items = [];
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await Store.instance.all(
        'goal_items',
        where: 'goal_id = ?',
        whereArgs: [widget.goalId],
        orderBy: 'id',
      );
      if (mounted) setState(() => items = data);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> edit([RowData? item]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => palettePage(
              context,
              GoalItemEditor(goalId: widget.goalId, existing: item),
            ),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final p = entryPalette(context, ocean);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          '分项要求',
          palette: p,
          trailing: '添加内容',
          onTrailing: () => edit(),
        ),
        const Text(
          '每项使用自己的目标值、单位和进度；不同单位不相加。',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        if (error != null) Text(error!),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OutlinedButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('添加第一项要求'),
            ),
          ),
        ...items.map(
          (i) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SoftCard(
              color: p.light,
              onTap: () => edit(i),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    val(i, 'title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: goalFraction(
                      i['current_value'] as num,
                      i['target_value'] as num,
                    ),
                    color: p.accent,
                    backgroundColor: p.soft,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${goalNumberText(i['current_value'] as num)} / ${goalNumberText(i['target_value'] as num)} ${val(i, 'unit')}',
                  ),
                  if (val(i, 'detail').isNotEmpty) Text(val(i, 'detail')),
                  const SizedBox(height: 5),
                  const Text(
                    '点此更新进度或查看历史',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GoalItemEditor extends StatefulWidget {
  const GoalItemEditor({super.key, required this.goalId, this.existing});
  final int goalId;
  final RowData? existing;
  @override
  State<GoalItemEditor> createState() => _GoalItemEditorState();
}

class _GoalItemEditorState extends State<GoalItemEditor> {
  late final title = TextEditingController(
    text: val(widget.existing ?? {}, 'title'),
  );
  late final target = TextEditingController(
    text: widget.existing == null ? '1' : val(widget.existing!, 'target_value'),
  );
  late final current = TextEditingController(
    text:
        widget.existing == null ? '0' : val(widget.existing!, 'current_value'),
  );
  late final unit = TextEditingController(
    text: widget.existing == null ? '项' : val(widget.existing!, 'unit'),
  );
  late final detail = TextEditingController(
    text: val(widget.existing ?? {}, 'detail'),
  );
  final note = TextEditingController();
  List<RowData> history = [];
  @override
  void initState() {
    super.initState();
    if (widget.existing != null) load();
  }

  Future<void> load() async {
    final data = await Store.instance.all(
      'goal_item_updates',
      where: 'item_id = ?',
      whereArgs: [widget.existing!['id']],
      orderBy: 'id DESC',
    );
    if (mounted) setState(() => history = data);
  }

  @override
  void dispose() {
    for (final c in [title, target, current, unit, detail, note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditLayout(
    title: widget.existing == null ? '添加要求内容' : '更新分项进度',
    palette: entryPalette(context, ocean),
    onSave: () async {
      await Store.instance.saveGoalItem(
        {
          'goal_id': widget.goalId,
          'title': title.text.trim(),
          'target_value': target.text,
          'current_value': current.text,
          'unit': unit.text.trim(),
          'detail': detail.text,
        },
        id: widget.existing == null ? null : rowId(widget.existing!),
        note: note.text,
      );
      if (context.mounted) Navigator.pop(context, true);
    },
    onDelete:
        widget.existing == null
            ? null
            : () async {
              if (await confirmDelete(context)) {
                await Store.instance.delete(
                  'goal_items',
                  rowId(widget.existing!),
                );
                if (context.mounted) Navigator.pop(context, true);
              }
            },
    children: [
      TextField(
        controller: title,
        decoration: const InputDecoration(labelText: '内容名称 *'),
      ),
      TextField(
        controller: target,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: '分项目标值 *'),
      ),
      TextField(
        controller: current,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: '分项累计进度 *'),
      ),
      TextField(
        controller: unit,
        decoration: const InputDecoration(labelText: '分项单位 *'),
      ),
      TextField(
        controller: detail,
        maxLines: 3,
        decoration: const InputDecoration(labelText: '要求说明'),
      ),
      TextField(
        controller: note,
        maxLines: 2,
        decoration: const InputDecoration(labelText: '本次进展备注'),
      ),
      if (history.isNotEmpty) const SectionTitle('分项更新历史'),
      ...history.map(
        (h) => ListTile(
          title: Text(
            '${val(h, 'previous_value')} → ${val(h, 'current_value')} ${val(h, 'unit')}',
          ),
          subtitle: Text('${val(h, 'created_at')}\n${val(h, 'note')}'),
        ),
      ),
    ],
  );
}
