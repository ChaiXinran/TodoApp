import 'package:flutter/material.dart';
import 'storage.dart';
import 'theme.dart';
import 'journal_pages.dart';
import 'daily_banners.dart';
import 'editors.dart' show confirmDelete;

Set<int> folderDescendants(List<RowData> folders, int id) {
  final result = <int>{id};
  void visit(int parent) {
    for (final f in folders.where((f) => f['parent_id'] == parent)) {
      if (result.add(rowId(f))) visit(rowId(f));
    }
  }

  visit(id);
  return result;
}

class RecordLibrary extends StatefulWidget {
  const RecordLibrary({
    super.key,
    required this.edit,
    required this.openRelated,
    required this.onMood,
    required this.onChanged,
    this.revision = 0,
  });
  final Future<void> Function(RowData?, String, int?) edit;
  final Future<void> Function(String, RowData) openRelated;
  final int revision;
  final Future<void> Function() onMood, onChanged;
  @override
  State<RecordLibrary> createState() => _RecordLibraryState();
}

class _RecordLibraryState extends State<RecordLibrary> {
  List<RowData> folders = [], notes = [], links = [];
  Map<String, List<RowData>> targets = {};
  final collapsed = <int>{};
  int? selected, focus;
  String mode = '目录树', search = '';
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(RecordLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) load();
  }

  Future<void> load() async {
    try {
      final data = await Future.wait([
        Store.instance.all('record_folders', orderBy: 'id'),
        Store.instance.all(
          'entries',
          orderBy: 'entry_date DESC, updated_at DESC, id DESC',
        ),
        Store.instance.all('record_links'),
        ...[
          'courses',
          'works',
          'events',
          'goals',
        ].map((t) => Store.instance.all(t)),
      ]);
      if (mounted)
        setState(() {
          folders = data[0];
          notes = data[1];
          links = data[2];
          targets = {
            'entries': notes,
            'record_folders': folders,
            'courses': data[3],
            'works': data[4],
            'events': data[5],
            'goals': data[6],
          };
          if (selected != null && !folders.any((f) => rowId(f) == selected))
            selected = null;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> edit([RowData? row]) async {
    final folderKind = val(
      folders.where((f) => f['id'] == selected).firstOrNull ?? {},
      'name',
    );
    await widget.edit(
      row,
      row == null
          ? (['随笔', '日记', '摘录', 'repo', '重要信息'].contains(folderKind)
              ? folderKind
              : '随笔')
          : val(row, 'kind'),
      selected,
    );
    await load();
  }

  Future<void> folder([RowData? row]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder:
          (_) => palettePage(
            context,
            _FolderDialog(folders: folders, existing: row, parent: selected),
          ),
    );
    if (changed == true) await load();
  }

  List<RowData> get visible {
    final ids = selected == null ? null : folderDescendants(folders, selected!);
    return notes
        .where(
          (n) =>
              (ids == null || ids.contains(n['folder_id'])) &&
              (search.isEmpty ||
                  '${val(n, 'title')} ${val(n, 'body')} ${val(n, 'kind')}'
                      .toLowerCase()
                      .contains(search.toLowerCase())),
        )
        .toList();
  }

  String title(RowData n) =>
      val(n, 'title').isEmpty
          ? (val(n, 'body').isEmpty ? '无题记录' : val(n, 'body'))
          : val(n, 'title');
  Widget node(RowData f, int depth) {
    final id = rowId(f),
        children = folders.where((x) => x['parent_id'] == id).toList();
    final count =
        notes
            .where(
              (n) => folderDescendants(folders, id).contains(n['folder_id']),
            )
            .length;
    return Column(
      children: [
        Material(
          color: selected == id ? honey.light : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.only(
              left: (depth * 14).clamp(0, 56).toDouble(),
            ),
            child: ListTile(
              dense: true,
              minLeadingWidth: 20,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: IconButton(
                tooltip:
                    collapsed.contains(id)
                        ? '展开${val(f, 'name')}'
                        : '折叠${val(f, 'name')}',
                icon: Icon(
                  children.isEmpty
                      ? Icons.folder_outlined
                      : collapsed.contains(id)
                      ? Icons.chevron_right
                      : Icons.expand_more,
                  size: 18,
                ),
                onPressed:
                    children.isEmpty
                        ? null
                        : () => setState(
                          () =>
                              collapsed.contains(id)
                                  ? collapsed.remove(id)
                                  : collapsed.add(id),
                        ),
              ),
              title: Text(
                val(f, 'name'),
                style: TextStyle(
                  fontWeight:
                      selected == id ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '管理${val(f, 'name')}',
                    onSelected: (v) async {
                      if (v == 'edit') {
                        await folder(f);
                      } else if (v == 'child') {
                        setState(() => selected = id);
                        await folder();
                      } else if (await confirmDelete(context)) {
                        await Store.instance.delete('record_folders', id);
                        await load();
                      }
                    },
                    itemBuilder:
                        (_) => const [
                          PopupMenuItem(value: 'child', child: Text('新建子文件夹')),
                          PopupMenuItem(value: 'edit', child: Text('重命名 / 移动')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('删除文件夹（保留记录）'),
                          ),
                        ],
                  ),
                ],
              ),
              onTap: () => setState(() => selected = id),
            ),
          ),
        ),
        if (!collapsed.contains(id)) ...children.map((c) => node(c, depth + 1)),
      ],
    );
  }

  Widget recordCard(RowData n, {bool timeline = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: JournalPanel(
      palette: honey,
      onTap: () => edit(n),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${val(n, 'kind')} · ${val(n, 'entry_date')}',
            style: TextStyle(fontSize: 11, color: honey.accent),
          ),
          const SizedBox(height: 8),
          Text(
            title(n),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          if (val(n, 'body').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                val(n, 'body'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ),
          if (links.any((l) => l['entry_id'] == n['id']))
            TextButton.icon(
              onPressed:
                  () => setState(() {
                    focus = rowId(n);
                    mode = '关联图';
                  }),
              icon: const Icon(Icons.link, size: 15),
              label: Text(
                '${links.where((l) => l['entry_id'] == n['id']).length} 个关联',
              ),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final filteredFolders =
        search.isEmpty
            ? folders
            : folders
                .where(
                  (f) => val(
                    f,
                    'name',
                  ).toLowerCase().contains(search.toLowerCase()),
                )
                .toList();
    final selectedRow = folders.where((f) => rowId(f) == selected).firstOrNull;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          RecordTopBanner(
            revision: widget.revision,
            onMood: widget.onMood,
            onChanged: widget.onChanged,
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            segments:
                [
                  '目录树',
                  '时间轴',
                  '关联图',
                ].map((s) => ButtonSegment(value: s, label: Text(s))).toList(),
            selected: {mode},
            onSelectionChanged: (v) => setState(() => mode = v.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜索记录、文件夹、喜欢的句子…',
            ),
            onChanged: (v) => setState(() => search = v.trim()),
          ),
          if (error != null) Text('读取失败：$error'),
          if (mode == '目录树') ...[
            journalSection(
              '我的分类',
              trailing: TextButton.icon(
                onPressed: () => folder(),
                icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                label: const Text('新建文件夹'),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: honey.soft),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(7),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.folder_copy_outlined, size: 19),
                    title: const Text('全部记录'),
                    trailing: Text('${notes.length}'),
                    selected: selected == null,
                    onTap: () => setState(() => selected = null),
                  ),
                  if (search.isEmpty)
                    ...folders
                        .where((f) => f['parent_id'] == null)
                        .map((f) => node(f, 0))
                  else
                    ...filteredFolders.map(
                      (f) => ListTile(
                        title: Text(val(f, 'name')),
                        onTap:
                            () => setState(() {
                              selected = rowId(f);
                              search = '';
                              searchController.clear();
                            }),
                      ),
                    ),
                ],
              ),
            ),
            journalSection(
              selectedRow == null ? '全部记录' : val(selectedRow, 'name'),
              trailing: TextButton(
                onPressed: () => edit(),
                child: const Text('写一篇'),
              ),
            ),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('这里还没有记录，写下第一篇吧。'),
              ),
            ...visible.map((n) => recordCard(n)),
          ] else if (mode == '时间轴') ...[
            journalSection(
              '一路走来的记录',
              trailing: TextButton(
                onPressed: () => edit(),
                child: const Text('新记录'),
              ),
            ),
            if (visible.isEmpty) const Text('还没有记录。'),
            ...visible.map(
              (n) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 15, right: 12),
                    child: Icon(Icons.circle, size: 8, color: honey.accent),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          val(n, 'entry_date'),
                          style: TextStyle(fontSize: 11, color: honey.accent),
                        ),
                        const SizedBox(height: 8),
                        recordCard(n),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            journalSection('记录之间的悄悄话'),
            const Text(
              '选一篇记录，查看它与其他内容的联系。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (notes.isEmpty)
              TextButton(onPressed: () => edit(), child: const Text('先写一篇记录'))
            else
              DropdownButtonFormField<int>(
                initialValue:
                    notes.any((n) => n['id'] == focus)
                        ? focus
                        : rowId(notes.first),
                isExpanded: true,
                decoration: const InputDecoration(labelText: '中心记录'),
                items:
                    notes
                        .map(
                          (n) => DropdownMenuItem(
                            value: rowId(n),
                            child: Text(
                              title(n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => focus = v),
              ),
            if (notes.isNotEmpty)
              graph(
                notes.where((n) => n['id'] == focus).firstOrNull ?? notes.first,
              ),
          ],
        ],
      ),
    );
  }

  Widget graph(RowData center) {
    final related = <({String table, RowData row})>[];
    for (final l in links.where((l) => l['entry_id'] == center['id'])) {
      final table = val(l, 'target_table');
      final row =
          targets[table]?.where((n) => n['id'] == l['target_id']).firstOrNull;
      if (row != null) related.add((table: table, row: row));
    }
    for (final l in links.where(
      (l) => l['target_table'] == 'entries' && l['target_id'] == center['id'],
    )) {
      final row = notes.where((n) => n['id'] == l['entry_id']).firstOrNull;
      if (row != null &&
          !related.any((r) => r.table == 'entries' && r.row['id'] == row['id']))
        related.add((table: 'entries', row: row));
    }
    Future<void> open(({String table, RowData row}) r) async {
      if (r.table == 'entries') {
        await edit(r.row);
      } else {
        await widget.openRelated(r.table, r.row);
      }
      await load();
    }

    String label(({String table, RowData row}) r) =>
        '${{'entries': '记录', 'courses': '课程', 'works': '作品', 'events': '日程', 'goals': '目标'}[r.table]} · ${val(r.row, 'title').isEmpty ? val(r.row, 'name') : val(r.row, 'title')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (related.isEmpty)
          JournalPanel(
            palette: honey,
            child: Column(
              children: [
                const Icon(Icons.hub_outlined),
                const SizedBox(height: 10),
                Text(title(center), style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                const Text('还没有跨内容关联，打开记录后添加。'),
              ],
            ),
          ),
        if (related.isNotEmpty)
          RelationCanvas(
            center: title(center),
            nodes: related.take(4).map(label).toList(),
            onCenter: () => edit(center),
            onNode: (i) => open(related[i]),
          ),
        const SizedBox(height: 12),
        Text(
          '所属目录：${center['folder_id'] == null ? '未分类' : folderLabel(folders.where((f) => f['id'] == center['folder_id']).firstOrNull ?? {'id': -1, 'name': '未分类'}, folders)}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        ...related.map(
          (r) => ListTile(
            leading: const Icon(Icons.link, size: 17),
            title: Text(label(r), maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => open(r),
          ),
        ),
        recordCard(center),
      ],
    );
  }
}

class RelationCanvas extends StatelessWidget {
  const RelationCanvas({
    super.key,
    required this.center,
    required this.nodes,
    required this.onCenter,
    required this.onNode,
  });
  final String center;
  final List<String> nodes;
  final VoidCallback onCenter;
  final ValueChanged<int> onNode;
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.textScalerOf(context).scale(76) + 26;
    Widget card(String text, VoidCallback action) => Material(
      color: honey.light,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: honey.deep),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      height: h * 3 + 40,
      child: CustomPaint(
        painter: _RelationsPainter(nodes.length, h),
        child: Column(
          children: [
            SizedBox(
              height: h,
              child: Row(
                children: [
                  for (var i = 0; i < 2; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 0 ? 12 : 0),
                        child:
                            i < nodes.length
                                ? card(nodes[i], () => onNode(i))
                                : const SizedBox(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: h,
              child: FractionallySizedBox(
                widthFactor: .75,
                child: card(center, onCenter),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: h,
              child: Row(
                children: [
                  for (var i = 2; i < 4; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i == 2 ? 12 : 0),
                        child:
                            i < nodes.length
                                ? card(nodes[i], () => onNode(i))
                                : const SizedBox(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationsPainter extends CustomPainter {
  const _RelationsPainter(this.count, this.h);
  final int count;
  final double h;
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = honey.soft
          ..strokeWidth = 2;
    final center = Offset(size.width / 2, h * 1.5 + 20);
    for (var i = 0; i < count; i++) {
      canvas.drawLine(
        center,
        Offset(
          size.width * (i.isEven ? 0.25 : 0.75),
          i < 2 ? h / 2 : h * 2.5 + 40,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RelationsPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.h != h;
}

class _FolderDialog extends StatefulWidget {
  const _FolderDialog({required this.folders, this.existing, this.parent});
  final List<RowData> folders;
  final RowData? existing;
  final int? parent;
  @override
  State<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<_FolderDialog> {
  late final name = TextEditingController(
    text: widget.existing == null ? '' : val(widget.existing!, 'name'),
  );
  late int? parent =
      widget.existing == null
          ? widget.parent
          : widget.existing!['parent_id'] as int?;
  String? error;
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final excluded =
        widget.existing == null
            ? <int>{}
            : folderDescendants(widget.folders, rowId(widget.existing!));
    return AlertDialog(
      title: Text(widget.existing == null ? '新建文件夹' : '管理文件夹'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: '文件夹名称', errorText: error),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: parent,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '上级目录'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('根目录')),
                ...widget.folders
                    .where((f) => !excluded.contains(rowId(f)))
                    .map(
                      (f) => DropdownMenuItem(
                        value: rowId(f),
                        child: Text(val(f, 'name')),
                      ),
                    ),
              ],
              onChanged: (v) => parent = v,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed:
              saving
                  ? null
                  : () async {
                    setState(() => saving = true);
                    try {
                      await Store.instance.saveFolder(
                        name.text,
                        id:
                            widget.existing == null
                                ? null
                                : rowId(widget.existing!),
                        parentId: parent,
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (mounted)
                        setState(() {
                          saving = false;
                          error = e is FormatException ? e.message : '保存失败：$e';
                        });
                    }
                  },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
