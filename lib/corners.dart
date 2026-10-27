import 'stored_image.dart';
import 'daily_banners.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'storage.dart';
import 'theme.dart';
import 'editors.dart';
import 'goals.dart';

String recordGroup(RowData row) => switch (val(row, 'kind')) {
  '摘录' => '摘录',
  '重要信息' => '重要信息',
  'repo' || '观剧感想' || '阅读感想' => 'repo',
  _ => '随笔',
};

/// Each detail page owns its query so returning from an editor refreshes it.
class CollectionPage extends StatefulWidget {
  const CollectionPage({
    super.key,
    required this.title,
    required this.table,
    required this.edit,
    this.where,
    this.args,
    this.palette = honey,
    this.taskMode = false,
    this.goalsMode = false,
  });
  final String title, table;
  final String? where;
  final List<Object?>? args;
  final SectionPalette palette;
  final Future<void> Function(RowData?) edit;
  final bool taskMode, goalsMode;
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  List<RowData>? rows;
  Map<int, String> covers = {};
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await Store.instance.all(
        widget.table,
        where: widget.where,
        whereArgs: widget.args,
        orderBy:
            widget.taskMode ? 'done ASC, due_date ASC, id DESC' : 'id DESC',
      );
      final bookCovers =
          widget.table == 'works'
              ? await Store.instance.bookCovers()
              : <int, String>{};
      if (mounted)
        setState(() {
          covers = bookCovers;
          rows = data;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> edit(RowData? row) async {
    await widget.edit(row);
    await load();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: richangTheme(seedColor: widget.palette.accent),
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => edit(null),
        tooltip: '添加${widget.title}',
        child: const Icon(Icons.add),
      ),
      body:
          error != null
              ? Center(child: Text('读取失败：$error'))
              : rows == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                  children: [
                    if (widget.goalsMode)
                      GoalsSection(
                        goals: rows!,
                        onAdd: () => edit(null),
                        onOpen: (r) => edit(r),
                      )
                    else if (rows!.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('这里还空着，点 + 留下一点内容吧。'),
                      )
                    else
                      ...rows!.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: widget.palette.light,
                            borderRadius: BorderRadius.circular(20),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              leading:
                                  widget.taskMode
                                      ? Checkbox(
                                        value: r['done'] == 1,
                                        onChanged: (v) async {
                                          final data =
                                              Map<String, Object?>.from(r)
                                                ..remove('id');
                                          data['done'] = v == true ? 1 : 0;
                                          await Store.instance.upsert(
                                            'tasks',
                                            data,
                                            id: rowId(r),
                                          );
                                          await load();
                                        },
                                      )
                                      : widget.table == 'works' &&
                                          covers[rowId(r)] != null
                                      ? storedImage(
                                        covers[rowId(r)]!,
                                        width: 40,
                                        height: 55,
                                        cacheWidth: 160,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, _, _) => const Icon(
                                              Icons.menu_book_outlined,
                                            ),
                                      )
                                      : Icon(
                                        widget.table == 'works'
                                            ? Icons.menu_book_outlined
                                            : widget.table == 'courses'
                                            ? Icons.school_outlined
                                            : Icons.notes_outlined,
                                        color: widget.palette.accent,
                                      ),
                              title: Text(
                                val(r, 'title').isNotEmpty
                                    ? val(r, 'title')
                                    : val(r, 'name').isNotEmpty
                                    ? val(r, 'name')
                                    : val(r, 'body'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                widget.table == 'works'
                                    ? '${val(r, 'status')} · ${val(r, 'progress')}%\n${val(r, 'memo')}'
                                    : widget.table == 'courses'
                                    ? '${val(r, 'semester')} · ${val(r, 'teacher')}'
                                    : widget.taskMode
                                    ? val(r, 'due_date')
                                    : '${val(r, 'entry_date')}${val(r, 'day')}\n${val(r, 'body')}${val(r, 'memo')}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => edit(r),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    ),
  );
}

class HomeCanvas extends StatefulWidget {
  const HomeCanvas({
    super.key,
    required this.tasks,
    required this.onToggle,
    required this.onTask,
    required this.onChoosePhoto,
    this.photo,
  });
  final List<RowData> tasks;
  final RowData? photo;
  final Future<void> Function(RowData, bool) onToggle;
  final ValueChanged<RowData?> onTask;
  final VoidCallback onChoosePhoto;
  @override
  State<HomeCanvas> createState() => _HomeCanvasState();
}

class _HomeCanvasState extends State<HomeCanvas> {
  @override
  Widget build(BuildContext context) {
    final pending = widget.tasks.where((r) => r['done'] != 1).toList();
    final path = widget.photo == null ? '' : val(widget.photo!, 'image_path');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 110),
      children: [
        const HomeDateCard(),
        const SizedBox(height: 16),
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child:
                  path.isEmpty
                      ? Image.asset(
                        'assets/branding/ycf.jpg',
                        fit: BoxFit.contain,
                      )
                      : storedImage(
                        path,
                        cacheWidth: 1200,
                        fit: BoxFit.contain,
                        errorBuilder:
                            (_, _, _) => Image.asset('assets/branding/ycf.jpg'),
                      ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: FilledButton.tonalIcon(
                onPressed: widget.onChoosePhoto,
                icon: const Icon(Icons.photo_library_outlined, size: 17),
                label: const Text('选图'),
              ),
            ),
          ],
        ),
        if (widget.photo != null && val(widget.photo!, 'caption').isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              val(widget.photo!, 'caption'),
              textAlign: TextAlign.center,
              style: TextStyle(color: rose.deep),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Row(
            children: [
              Text(
                '待办',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: rose.deep,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '添加待办',
                onPressed: () => widget.onTask(null),
                icon: Icon(Icons.add, color: rose.accent),
              ),
            ],
          ),
        ),
        if (pending.isEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text('待办都完成啦，留一点时间给自己。', style: TextStyle(color: rose.deep)),
          ),
        ...pending.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: rose.light,
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                leading: Checkbox(
                  activeColor: rose.accent,
                  value: false,
                  onChanged: (v) => widget.onToggle(r, v == true),
                ),
                title: Text(val(r, 'title')),
                subtitle:
                    val(r, 'due_date').isEmpty
                        ? null
                        : Text(val(r, 'due_date')),
                onTap: () => widget.onTask(r),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class CloudSpace extends StatefulWidget {
  const CloudSpace({super.key, this.selecting = false});
  final bool selecting;
  @override
  State<CloudSpace> createState() => _CloudSpaceState();
}

class _CloudSpaceState extends State<CloudSpace> {
  List<RowData> posts = [];
  String category = '全部';
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await Store.instance.all(
        'cloud_posts',
        orderBy: 'updated_at DESC, id DESC',
      );
      if (mounted)
        setState(() {
          posts = data;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> edit([RowData? row]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => palettePage(context, CloudEditor(existing: row)),
      ),
    );
    await load();
  }

  Future<void> choose(int? id) async {
    await Store.instance.setHomePhoto(id);
    if (!mounted) return;
    if (widget.selecting) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已设为首页图片')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = {'全部', ...posts.map((r) => val(r, 'category'))};
    if (!cats.contains(category)) category = '全部';
    final visible =
        posts
            .where(
              (r) =>
                  (category == '全部' || val(r, 'category') == category) &&
                  (!widget.selecting || val(r, 'image_path').isNotEmpty),
            )
            .toList();
    return Theme(
      data: richangTheme(seedColor: entryPalette(context, rose).accent),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.selecting ? '选择首页图片' : '云次方')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => edit(),
          tooltip: '添加云次方图文',
          child: const Icon(Icons.add),
        ),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            children: [
              if (widget.selecting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => choose(null),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('使用默认云次方原图'),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      cats
                          .map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: c == category,
                                onSelected: (_) => setState(() => category = c),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
              if (error != null) Text('读取失败：$error'),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('把最近的感想和喜欢的图片留在这里。\n点 + 添加，分类名称可以自己写。'),
                ),
              ...visible.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Material(
                    color: entryPalette(context, rose).light,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => edit(p),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (val(p, 'image_path').isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: storedImage(
                                  val(p, 'image_path'),
                                  cacheWidth: 1200,
                                  fit: BoxFit.contain,
                                  errorBuilder:
                                      (_, _, _) => const Text('原图片暂时无法读取'),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              val(p, 'category'),
                              style: TextStyle(
                                color: entryPalette(context, rose).accent,
                              ),
                            ),
                            if (val(p, 'title').isNotEmpty)
                              Text(
                                val(p, 'title'),
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (val(p, 'caption').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(val(p, 'caption')),
                              ),
                            if (val(p, 'body').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(val(p, 'body')),
                              ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => edit(p),
                                  child: const Text('编辑图文'),
                                ),
                                const Spacer(),
                                if (val(p, 'image_path').isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () => choose(rowId(p)),
                                    icon: const Icon(
                                      Icons.home_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('设为首页'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CloudEditor extends StatefulWidget {
  const CloudEditor({super.key, this.existing});
  final RowData? existing;
  @override
  State<CloudEditor> createState() => _CloudEditorState();
}

class _CloudEditorState extends State<CloudEditor> {
  late final TextEditingController title, body, category, caption;
  String? photo;
  @override
  void initState() {
    super.initState();
    final r = widget.existing ?? <String, Object?>{};
    title = TextEditingController(text: val(r, 'title'));
    body = TextEditingController(text: val(r, 'body'));
    category = TextEditingController(
      text: val(r, 'category').isEmpty ? '日常感想' : val(r, 'category'),
    );
    caption = TextEditingController(text: val(r, 'caption'));
    photo = r['image_path'] as String?;
  }

  @override
  void dispose() {
    for (final c in [title, body, category, caption]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final path = await Store.instance.copyPhoto(image.path);
      if (mounted) setState(() => photo = path);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty &&
        body.text.trim().isEmpty &&
        photo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('写一点感想或添加图片再保存吧')));
      return;
    }
    await Store.instance.upsert('cloud_posts', {
      'title': title.text.trim(),
      'body': body.text,
      'category': category.text.trim().isEmpty ? '日常感想' : category.text.trim(),
      'caption': caption.text,
      'image_path': photo,
      'updated_at': DateTime.now().toIso8601String(),
    }, id: widget.existing == null ? null : rowId(widget.existing!));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => EditLayout(
    title: widget.existing == null ? '添加云次方图文' : '编辑云次方图文',
    palette: entryPalette(context, rose),
    onSave: save,
    onDelete:
        widget.existing == null
            ? null
            : () async {
              if (await confirmDelete(context)) {
                await Store.instance.delete(
                  'cloud_posts',
                  rowId(widget.existing!),
                );
                if (context.mounted) Navigator.pop(context, true);
              }
            },
    children: [
      TextField(
        controller: category,
        decoration: const InputDecoration(labelText: '分类（可自定义）'),
      ),
      TextField(
        controller: title,
        decoration: const InputDecoration(labelText: '标题（可选）'),
      ),
      TextField(
        controller: body,
        minLines: 5,
        maxLines: 12,
        decoration: const InputDecoration(labelText: '最近的感想'),
      ),
      OutlinedButton.icon(
        onPressed: pick,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(photo == null ? '从相册添加图片' : '更换图片'),
      ),
      if (photo != null) ...[
        storedImage(
          photo!,
          cacheWidth: 1200,
          height: 260,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Text('图片无法读取'),
        ),
        TextButton(
          onPressed: () => setState(() => photo = null),
          child: const Text('移除图片'),
        ),
      ],
      TextField(
        controller: caption,
        maxLines: 3,
        decoration: const InputDecoration(labelText: '图片配文'),
      ),
      const Text(
        '图片会复制到本机应用内保存。保存后可在图文卡片中设为首页图片。',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}
