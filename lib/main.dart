import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'storage.dart';
import 'pwa_settings.dart';
import 'theme.dart';
import 'editors.dart';
import 'views.dart';
import 'schedule.dart';
import 'branding.dart';
import 'goals.dart';
import 'corners.dart';
import 'journal_pages.dart';
import 'record_library.dart';
import 'study.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RichangApp());
}

class RichangApp extends StatelessWidget {
  const RichangApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '日常',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: richangTheme(),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  int revision = 0;
  bool busy = true;
  String? error;
  List<RowData> tasks = [],
      notes = [],
      courses = [],
      events = [],
      moods = [],
      works = [];
  List<RowData> meetings = [], semesters = [];
  List<RowData> goals = [];
  RowData? homePhoto;
  Map<int, String> covers = {};
  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final results = await Future.wait([
        Store.instance.all('tasks', orderBy: 'done ASC, due_date ASC, id DESC'),
        Store.instance.all(
          'entries',
          orderBy: 'entry_date DESC, updated_at DESC',
        ),
        Store.instance.all(
          'courses',
          orderBy: 'semester DESC, weekday ASC, start_time ASC',
        ),
        Store.instance.all('events', orderBy: 'day DESC, time ASC'),
        Store.instance.all('moods', orderBy: 'day DESC'),
        Store.instance.all('works', orderBy: 'id DESC'),
        Store.instance.all(
          'course_meetings',
          orderBy: 'weekday, start_period, id',
        ),
        Store.instance.all('semesters', orderBy: 'id DESC'),
        Store.instance.all('goals', orderBy: 'updated_at DESC, id DESC'),
      ]);
      final photo = await Store.instance.homePhoto();
      final bookCovers = await Store.instance.bookCovers();
      if (!mounted) return;
      setState(() {
        homePhoto = photo;
        covers = bookCovers;
        tasks = results[0];
        notes = results[1];
        courses = results[2];
        events = results[3];
        moods = results[4];
        works = results[5];
        meetings = results[6];
        semesters = results[7];
        goals = results[8];
        busy = false;
        revision++;
        error = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          busy = false;
          error = e.toString();
        });
    }
  }

  SectionPalette get pageColor => [rose, ocean, ocean, honey, forest][index];
  Future<void> openEditor(Widget page, {SectionPalette? palette}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => palettePage(context, page, palette ?? pageColor),
      ),
    );
    if (mounted) await reload();
  }

  Future<void> task([RowData? row, int? courseId, String? studyKind]) =>
      openEditor(
        row == null
            ? TaskEditor(
              courses: courses,
              initialCourseId: courseId,
              initialStudyKind: studyKind,
            )
            : TaskDetail(initial: row, courses: courses),
      );
  Future<void> note([RowData? row, String kind = '随笔', int? folderId]) async {
    final folders = await Store.instance.all('record_folders', orderBy: 'id');
    final links =
        row == null
            ? <RowData>[]
            : await Store.instance.all(
              'record_links',
              where: 'entry_id = ?',
              whereArgs: [row['id']],
            );
    if (!mounted) return;
    final defaultFolder =
        row == null
            ? folders
                .where((f) => val(f, 'name') == kind && f['parent_id'] == null)
                .firstOrNull
            : null;
    final targets = <RowData>[];
    for (final pair in [
      ('entries', notes),
      ('courses', courses),
      ('works', works),
      ('events', events),
      ('goals', goals),
    ]) {
      for (final r in pair.$2)
        targets.add({
          'target_table': pair.$1,
          'target_id': r['id'],
          'label':
              '${{'entries': '记录', 'courses': '课程', 'works': '作品', 'events': '日程', 'goals': '目标'}[pair.$1]} · ${val(r, 'title').isEmpty
                  ? val(r, 'name').isEmpty
                      ? val(r, 'body')
                      : val(r, 'name')
                  : val(r, 'title')}',
        });
    }
    await openEditor(
      NoteEditor(
        existing: row,
        initialKind: kind,
        initialFolderId: folderId ?? (defaultFolder?['id'] as int?),
        folders: folders,
        initialLinks: links,
        linkTargets: targets,
      ),
    );
  }

  Future<void> course([RowData? row]) => openEditor(
    CourseEditor(
      existing: row,
      meetings:
          row == null
              ? const []
              : meetings.where((m) => m['course_id'] == rowId(row)).toList(),
    ),
  );
  Future<void> event([RowData? row, DateTime? day]) =>
      openEditor(EventEditor(existing: row, initialDay: day));
  Future<void> work([RowData? row]) => openEditor(WorkEditor(existing: row));
  Future<void> goal([RowData? row, String category = '学业']) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => palettePage(
              context,
              row == null
                  ? GoalEditor(
                    initialCategory: category,
                    initialSemester:
                        semesters.isEmpty
                            ? '2026 秋'
                            : val(semesters.first, 'name'),
                  )
                  : GoalDetail(initial: row),
              pageColor,
            ),
      ),
    );
    if (mounted) await reload();
  }

  void courseDetail(RowData row) {
    final slots = meetings.where((m) => m['course_id'] == rowId(row)).toList();
    final associated =
        tasks.where((x) => x['course_id'] == rowId(row)).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: paper,
      builder:
          (sheet) => palettePage(
            context,
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        val(row, 'name'),
                        style: Theme.of(sheet).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${val(row, 'semester')}  ·  ${row['semester_id'] != null && (row['credits'] as num) == 0 ? '学分未填写' : '${val(row, 'credits')} 学分'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...slots.map(
                        (m) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.calendar_view_week_outlined,
                          ),
                          title: Text(
                            '周${'一二三四五六日'[(m['weekday'] as int) - 1]} · ${sessionLabel(m)} · ${val(m, 'room')}',
                          ),
                          subtitle: Text(
                            '${val(m, 'weeks_text')} · ${val(m, 'teacher')}',
                          ),
                        ),
                      ),
                      if (val(row, 'schedule_note').isNotEmpty)
                        Text(val(row, 'schedule_note')),
                      Text(
                        '关联作业（${associated.length}）',
                        style: Theme.of(sheet).textTheme.titleMedium,
                      ),
                      if (associated.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            '还没有关联作业',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ...associated
                          .take(8)
                          .map(
                            (t) => ListTile(
                              leading: Icon(
                                t['done'] == 1
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                              ),
                              title: Text(val(t, 'title')),
                              subtitle: Text(val(t, 'due_date')),
                              onTap: () {
                                Navigator.pop(sheet);
                                task(t);
                              },
                            ),
                          ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('编辑课程'),
                              onPressed: () {
                                Navigator.pop(sheet);
                                course(row);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('新建作业'),
                              onPressed: () {
                                Navigator.pop(sheet);
                                task(null, rowId(row));
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            pageColor,
          ),
    );
  }

  Future<void> mood() async {
    final d = dayKey(DateTime.now());
    final found = moods.where((m) => val(m, 'day') == d).toList();
    await editMood(
      context,
      day: d,
      currentEmoji: found.isEmpty ? null : val(found.first, 'emoji'),
      currentMemo: found.isEmpty ? null : val(found.first, 'memo'),
      palette: pageColor,
    );
    await reload();
  }

  Future<void> toggleTask(RowData row, bool done) async {
    final fields = Map<String, Object?>.from(row)..remove('id');
    fields['done'] = done ? 1 : 0;
    await Store.instance.upsert('tasks', fields, id: rowId(row));
    await reload();
  }

  void quickAdd() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: paper,
    builder:
        (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '想记录什么？',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _quickButton(
                      sheetContext,
                      '学期目标',
                      Icons.flag_outlined,
                      () => goal(),
                    ),
                    _quickButton(
                      sheetContext,
                      '待办',
                      Icons.check_circle_outline,
                      () => task(),
                    ),
                    _quickButton(
                      sheetContext,
                      '日程 / 观剧',
                      Icons.event_outlined,
                      () => event(),
                    ),
                    _quickButton(
                      sheetContext,
                      '随笔',
                      Icons.edit_note,
                      () => note(),
                    ),
                    _quickButton(
                      sheetContext,
                      '句子摘录',
                      Icons.format_quote,
                      () => note(null, '摘录'),
                    ),
                    _quickButton(
                      sheetContext,
                      '重要信息',
                      Icons.bookmark_outline,
                      () => note(null, '重要信息'),
                    ),
                    _quickButton(
                      sheetContext,
                      '课程',
                      Icons.school_outlined,
                      () => course(),
                    ),
                    _quickButton(
                      sheetContext,
                      '阅读',
                      Icons.menu_book_outlined,
                      () => work(),
                    ),
                    _quickButton(
                      sheetContext,
                      '云次方',
                      Icons.cloud_outlined,
                      () => cloud(),
                    ),
                    _quickButton(
                      sheetContext,
                      '今日心情',
                      Icons.favorite_outline,
                      () => mood(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
  );
  Widget _quickButton(
    BuildContext sheetContext,
    String label,
    IconData icon,
    VoidCallback action,
  ) {
    final palette = [rose, ocean, ocean, honey, forest][index];
    return ActionChip(
      backgroundColor: palette.light,
      avatar: Icon(icon, size: 19, color: palette.accent),
      label: Text(label),
      onPressed: () {
        Navigator.pop(sheetContext);
        action();
      },
    );
  }

  Future<void> searchAll() async {
    final cloudPosts = await Store.instance.all('cloud_posts');
    if (!mounted) return;
    final options = <SearchTarget>[
      ...cloudPosts.map(
        (p) => SearchTarget(
          '云次方',
          val(p, 'title').isEmpty ? val(p, 'category') : val(p, 'title'),
          p,
          extra: '${val(p, 'body')} ${val(p, 'caption')} ${val(p, 'category')}',
        ),
      ),
      ...goals.map(
        (g) => SearchTarget(
          '目标',
          val(g, 'title'),
          g,
          extra:
              '${val(g, 'semester')} ${val(g, 'category')} ${val(g, 'detail')}',
        ),
      ),
      ...tasks.map((e) => SearchTarget('待办', val(e, 'title'), e)),
      ...notes.map(
        (e) => SearchTarget(
          '记录',
          val(e, 'title').isEmpty ? val(e, 'body') : val(e, 'title'),
          e,
          extra: val(e, 'body'),
        ),
      ),
      ...events.map((e) => SearchTarget('日程', val(e, 'title'), e)),
      ...works.map((e) => SearchTarget('作品', val(e, 'name'), e)),
      ...courses.map((e) => SearchTarget('课程', val(e, 'name'), e)),
    ];
    final picked = await showSearch<SearchTarget?>(
      context: context,
      delegate: RichangSearch(options),
    );
    if (!mounted || picked == null) return;
    switch (picked.kind) {
      case '云次方':
        await openEditor(CloudEditor(existing: picked.row));
        break;
      case '目标':
        goal(picked.row);
        break;
      case '待办':
        task(picked.row);
        break;
      case '记录':
        note(picked.row);
        break;
      case '日程':
        event(picked.row);
        break;
      case '作品':
        work(picked.row);
        break;
      case '课程':
        course(picked.row);
        break;
    }
  }

  Future<void> cloud({bool selecting = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => palettePage(
              context,
              CloudSpace(selecting: selecting),
              pageColor,
            ),
      ),
    );
    await reload();
  }

  Future<void> collection(
    String title,
    String table, {
    String? where,
    List<Object?>? args,
    SectionPalette palette = honey,
    bool taskMode = false,
    bool goalsMode = false,
    String kind = '随笔',
    String shelf = '文学',
    String goalCategory = '学业',
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => palettePage(
              context,
              CollectionPage(
                title: title,
                table: table,
                where: where,
                args: args,
                palette: palette,
                taskMode: taskMode,
                goalsMode: goalsMode,
                edit: (row) async {
                  switch (table) {
                    case 'tasks':
                      await openEditor(
                        row == null
                            ? TaskEditor(courses: courses)
                            : TaskDetail(initial: row, courses: courses),
                        palette: palette,
                      );
                    case 'courses':
                      await openEditor(
                        CourseEditor(
                          existing: row,
                          meetings:
                              meetings
                                  .where((m) => m['course_id'] == row?['id'])
                                  .toList(),
                        ),
                        palette: palette,
                      );
                    case 'goals':
                      await goal(row, goalCategory);
                    case 'works':
                      await openEditor(
                        WorkEditor(existing: row, initialShelf: shelf),
                        palette: palette,
                      );
                    case 'events':
                      await openEditor(
                        EventEditor(existing: row, initialKind: '观剧'),
                        palette: palette,
                      );
                    default:
                      await note(row, kind);
                  }
                },
              ),
              palette,
            ),
      ),
    );
    await reload();
  }

  void records(String kind) {
    final kinds = switch (kind) {
      '随笔' => ['随笔', '日记'],
      'repo' => ['repo', '观剧感想', '阅读感想'],
      _ => [kind],
    };
    collection(
      kind,
      'entries',
      where: 'kind IN (${List.filled(kinds.length, '?').join(',')})',
      args: kinds,
      palette: pageColor,
      kind: kind,
    );
  }

  String get currentTerm =>
      semesters.isEmpty ? '学期目标' : val(semesters.first, 'name');

  Future<void> chooseMood(String emoji) async {
    final day = dayKey(DateTime.now());
    final previous = moods.where((m) => val(m, 'day') == day).firstOrNull;
    await Store.instance.upsert('moods', {
      'emoji': emoji,
      'memo': previous == null ? '' : val(previous, 'memo'),
    }, day: day);
    await reload();
  }

  void volunteer() => collection(
    '志愿记录',
    'goals',
    where: 'category LIKE ?',
    args: ['%志愿%'],
    palette: ocean,
    goalsMode: true,
    goalCategory: '志愿',
  );

  void books() => Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => Theme(
            data: richangTheme(seedColor: forest.accent),
            child: Scaffold(
              appBar: AppBar(title: const Text('阅读书架')),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const JournalHeading(
                    title: '阅读书架',
                    subtitle: '在文字里，找到自己的小世界。',
                    icon: Icons.menu_book_outlined,
                    palette: forest,
                  ),
                  for (final shelf in ['文学', '娱乐'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: JournalLink(
                        title: '$shelf书架',
                        subtitle: shelf == '文学' ? '文学与想读的文字' : '小说、漫画与轻松时刻',
                        icon: Icons.auto_stories_outlined,
                        palette: forest,
                        onTap:
                            () => collection(
                              '$shelf书架',
                              'works',
                              where: 'shelf = ?',
                              args: [shelf],
                              palette: forest,
                              shelf: shelf,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
    ),
  );

  void theater() => Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => Theme(
            data: richangTheme(seedColor: forest.accent),
            child: Scaffold(
              appBar: AppBar(title: const Text('观剧档案')),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const JournalHeading(
                    title: '我的观剧手记',
                    subtitle: '收藏喜欢的舞台瞬间。',
                    icon: Icons.theater_comedy_outlined,
                    palette: forest,
                  ),
                  JournalLink(
                    title: '观剧体验',
                    subtitle: '照片、台词与观后感',
                    icon: Icons.edit_note,
                    palette: forest,
                    onTap:
                        () => collection(
                          '观剧体验',
                          'entries',
                          where: "kind IN ('repo', '观剧感想')",
                          kind: '观剧感想',
                          palette: forest,
                        ),
                  ),
                  const SizedBox(height: 16),
                  JournalLink(
                    title: '观剧日程',
                    subtitle: '剧目、场次、时间和地点',
                    icon: Icons.confirmation_number_outlined,
                    palette: forest,
                    onTap:
                        () => collection(
                          '观剧日程',
                          'events',
                          where: "kind = '观剧'",
                          palette: forest,
                        ),
                  ),
                ],
              ),
            ),
          ),
    ),
  );

  void semesterArchive(RowData semester) => Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => Theme(
            data: richangTheme(seedColor: forest.accent),
            child: Scaffold(
              appBar: AppBar(title: Text(val(semester, 'name'))),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const JournalHeading(
                    title: '学期档案',
                    subtitle: '课程与每一步努力，都留在这里。',
                    icon: Icons.school_outlined,
                    palette: forest,
                  ),
                  JournalLink(
                    title: '本学期课程',
                    subtitle: '课表、教师与课程资料',
                    icon: Icons.school_outlined,
                    palette: forest,
                    onTap:
                        () => collection(
                          '本学期课程',
                          'courses',
                          where: 'semester_id = ? OR semester = ?',
                          args: [semester['id'], semester['name']],
                          palette: forest,
                        ),
                  ),
                  const SizedBox(height: 16),
                  JournalLink(
                    title: '本学期目标',
                    subtitle: '累计进度、要求与更新历史',
                    icon: Icons.flag_outlined,
                    palette: forest,
                    onTap:
                        () => collection(
                          '本学期目标',
                          'goals',
                          where:
                              "replace(replace(replace(replace(semester, ' ', ''), '季', ''), '学', ''), '期', '') = ?",
                          args: [compactTerm(val(semester, 'name'))],
                          goalsMode: true,
                          palette: forest,
                        ),
                  ),
                ],
              ),
            ),
          ),
    ),
  );

  Widget affairsHub() => AffairsJournal(
    tasks: tasks,
    courses: courses,
    goals: goals,
    term: currentTerm,
    onToggle: toggleTask,
    onTask: task,
    onAllTasks:
        () => collection('待完成', 'tasks', palette: ocean, taskMode: true),
    onCourses: studyBoard,
    onGoals: () => collection('学期目标', 'goals', palette: ocean, goalsMode: true),
    onVolunteer: volunteer,
    onRefresh: reload,
  );
  void studyBoard() => Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => palettePage(
            context,
            StudyBoard(openTask: task, openCourse: course),
            ocean,
          ),
    ),
  );
  Widget recordsHub() => RecordLibrary(
    onMood: mood,
    onChanged: reload,
    revision: revision,
    edit: (row, kind, folder) => note(row, kind, folder),
    openRelated: (table, row) async {
      switch (table) {
        case 'entries':
          await note(row);
        case 'courses':
          await course(row);
        case 'works':
          await work(row);
        case 'events':
          await event(row);
        case 'goals':
          await goal(row);
      }
    },
  );
  Widget archiveHub() => ArchiveJournal(
    works: works,
    covers: covers,
    events: events,
    notes: notes,
    semesters: semesters,
    onWork: work,
    onBooks: books,
    onTheater: theater,
    onImportant: () => records('重要信息'),
    onSemester: semesterArchive,
    onCloud: () => cloud(),
    onRefresh: reload,
  );

  @override
  Widget build(BuildContext context) {
    if (busy) return const AppCover();
    if (error != null)
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('本地数据库打开失败：$error'),
                const SizedBox(height: 12),
                FilledButton(onPressed: reload, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    final names = ['日常', '日历', '事务', '记录', '档案'];
    final views = [
      HomeCanvas(
        tasks: tasks,
        photo: homePhoto,
        onToggle: toggleTask,
        onTask: task,
        onChoosePhoto: () => cloud(selecting: true),
      ),
      CalendarView(
        meetings: meetings,
        semesters: semesters,
        onEditCourse: courseDetail,
        courses: courses,
        tasks: tasks,
        notes: notes,
        events: events,
        moods: moods,
        onAddEvent: (d) => event(null, d),
        onEditEvent: event,
        onEditTask: task,
        onEditNote: note,
      ),
      affairsHub(),
      recordsHub(),
      archiveHub(),
    ];
    final palette = [rose, ocean, ocean, honey, forest][index];
    return Theme(
      data: richangTheme(seedColor: palette.accent),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(
                [
                  Icons.wb_sunny_outlined,
                  Icons.cloud_outlined,
                  Icons.nights_stay_outlined,
                  Icons.local_florist_outlined,
                  Icons.forest_outlined,
                ][index],
                color: palette.accent,
              ),
              const SizedBox(width: 9),
              Text(
                index < 2 || index == 3 ? names[index] : '日常',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '使用与备份',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => openEditor(const PwaSettings()),
            ),
            IconButton(
              tooltip: '搜索',
              onPressed: searchAll,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              tooltip: '重新读取本地数据',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: IndexedStack(index: index, children: views),
        floatingActionButton: FloatingActionButton.extended(
          tooltip: '记一笔',
          onPressed: quickAdd,
          icon: const Icon(Icons.add),
          label: const Text('记一笔'),
          backgroundColor: pageColor.soft,
          foregroundColor: pageColor.deep,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: '日历',
            ),
            NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: '事务',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note),
              label: '记录',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_open_outlined),
              selectedIcon: Icon(Icons.folder_open),
              label: '档案',
            ),
          ],
        ),
      ),
    );
  }
}

class SearchTarget {
  const SearchTarget(this.kind, this.title, this.row, {this.extra = ''});
  final String kind, title, extra;
  final RowData row;
}

class RichangSearch extends SearchDelegate<SearchTarget?> {
  RichangSearch(this.options);
  final List<SearchTarget> options;
  @override
  String get searchFieldLabel => '搜索目标、随笔、课程、作品与任务';
  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      tooltip: '清除',
      icon: const Icon(Icons.clear),
      onPressed: () {
        query = '';
        showSuggestions(context);
      },
    ),
  ];
  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );
  @override
  Widget buildResults(BuildContext context) => _results();
  @override
  Widget buildSuggestions(BuildContext context) => _results();
  Widget _results() {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty)
      return const Center(child: Text('输入关键词，搜索你的记录、待办与收藏'));
    final matches =
        normalized.isEmpty
            ? options.take(20).toList()
            : options
                .where(
                  (x) =>
                      x.title.toLowerCase().contains(normalized) ||
                      x.extra.toLowerCase().contains(normalized),
                )
                .toList();
    if (matches.isEmpty) return const Center(child: Text('没有找到相关记录'));
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final m = matches[i];
        return ListTile(
          title: Text(
            m.title.isEmpty ? '未命名记录' : m.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(m.kind),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => close(context, m),
        );
      },
    );
  }
}
