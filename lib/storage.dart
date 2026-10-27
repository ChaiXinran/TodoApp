import 'package:image_picker/image_picker.dart';
import 'stored_image.dart';
import 'platform_database.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'goal_metrics.dart';

// Rows are kept deliberately small and explicit. No passwords are stored here.
typedef RowData = Map<String, Object?>;

class Store {
  Store._();
  static final Store instance = Store._();
  Future<Database>? _opening;

  Future<Database> get db =>
      _opening ??= _open().catchError((Object error) {
        _opening = null;
        throw error;
      });

  /// Close the connection without deleting data (also used by lifecycle tests).
  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }

  Future<Database> _open() async {
    configureDatabase();
    const path = 'richang-pwa.sqlite';
    final opened = await openDatabase(
      path,
      version: 5,
      onConfigure:
          (database) async => database.execute('PRAGMA foreign_keys = ON'),
      onCreate: (database, _) async {
        await database.execute('''CREATE TABLE courses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, semester TEXT NOT NULL DEFAULT '',
          teacher TEXT NOT NULL DEFAULT '', room TEXT NOT NULL DEFAULT '',
          weekday INTEGER, start_time TEXT NOT NULL DEFAULT '', end_time TEXT NOT NULL DEFAULT '',
          credits REAL NOT NULL DEFAULT 0)''');
        await database.execute('''CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL, detail TEXT NOT NULL DEFAULT '', due_date TEXT,
          course_id INTEGER REFERENCES courses(id) ON DELETE SET NULL,
          done INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)''');
        await database.execute(
          '''CREATE TABLE entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '',
          kind TEXT NOT NULL, entry_date TEXT NOT NULL,
          image_path TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
        );
        await database.execute(
          '''CREATE TABLE moods (
          day TEXT PRIMARY KEY, emoji TEXT NOT NULL, memo TEXT NOT NULL DEFAULT '')''',
        );
        await database.execute('''CREATE TABLE events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL, day TEXT NOT NULL, time TEXT NOT NULL DEFAULT '',
          kind TEXT NOT NULL DEFAULT '日程', location TEXT NOT NULL DEFAULT '',
          memo TEXT NOT NULL DEFAULT '')''');
        await database.execute(
          '''CREATE TABLE works (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, author TEXT NOT NULL DEFAULT '',
          type TEXT NOT NULL DEFAULT '小说', status TEXT NOT NULL DEFAULT '想读',
          progress INTEGER NOT NULL DEFAULT 0, memo TEXT NOT NULL DEFAULT '')''',
        );
        // Future versions can add requirements, volunteer proof and linked works with migrations.
        await database.execute('CREATE INDEX idx_tasks_due ON tasks(due_date)');
        await database.execute(
          'CREATE INDEX idx_entries_day ON entries(entry_date)',
        );
        await database.execute('CREATE INDEX idx_events_day ON events(day)');
        await _createTimetableSchema(database);
        await _createGoalSchema(database);
        await _createCornerSchema(database);
        await _createOrganizationSchema(database);
      },
      onUpgrade: (database, oldVersion, _) async {
        if (oldVersion < 2) await _createTimetableSchema(database);
        if (oldVersion < 3) await _createGoalSchema(database);
        if (oldVersion < 4) await _createCornerSchema(database);
        if (oldVersion < 5) await _createOrganizationSchema(database);
      },
    );
    await importBundledTimetable(opened);
    return opened;
  }

  static Future<void> _createOrganizationSchema(Database db) async {
    await db.execute(
      "ALTER TABLE tasks ADD COLUMN study_kind TEXT NOT NULL DEFAULT '平常作业'",
    );
    await db.execute(
      'CREATE TABLE record_folders (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, parent_id INTEGER REFERENCES record_folders(id) ON DELETE SET NULL)',
    );
    await db.execute(
      'ALTER TABLE entries ADD COLUMN folder_id INTEGER REFERENCES record_folders(id) ON DELETE SET NULL',
    );
    await db.execute(
      'CREATE TABLE record_links (id INTEGER PRIMARY KEY AUTOINCREMENT, entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE, target_table TEXT NOT NULL, target_id INTEGER NOT NULL, UNIQUE(entry_id,target_table,target_id))',
    );
    await db.execute(
      'CREATE TABLE goal_items (id INTEGER PRIMARY KEY AUTOINCREMENT, goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE, title TEXT NOT NULL, target_value REAL NOT NULL CHECK(target_value>0), current_value REAL NOT NULL CHECK(current_value>=0), unit TEXT NOT NULL, detail TEXT NOT NULL DEFAULT \'\')',
    );
    await db.execute(
      'CREATE TABLE goal_item_updates (id INTEGER PRIMARY KEY AUTOINCREMENT, item_id INTEGER NOT NULL REFERENCES goal_items(id) ON DELETE CASCADE, previous_value REAL NOT NULL, current_value REAL NOT NULL, target_value REAL NOT NULL, unit TEXT NOT NULL, note TEXT NOT NULL, created_at TEXT NOT NULL)',
    );
    for (final kind in ['随笔', '日记', '摘录', 'repo', '重要信息']) {
      final id = await db.insert('record_folders', {'name': kind});
      await db.update(
        'entries',
        {'folder_id': id},
        where: kind == 'repo' ? "kind IN ('repo','观剧感想','阅读感想')" : 'kind = ?',
        whereArgs: kind == 'repo' ? null : [kind],
      );
    }
  }

  Future<int> saveFolder(String name, {int? id, int? parentId}) async {
    if (name.trim().isEmpty) throw const FormatException('请输入文件夹名称');
    final database = await db;
    return database.transaction((tx) async {
      int? ancestor = parentId;
      final seen = <int>{};
      while (ancestor != null) {
        if (ancestor == id || !seen.add(ancestor))
          throw const FormatException('不能放入自身或子文件夹');
        final row = await tx.query(
          'record_folders',
          where: 'id = ?',
          whereArgs: [ancestor],
        );
        if (row.isEmpty) throw const FormatException('上级文件夹已不存在');
        ancestor = row.single['parent_id'] as int?;
      }
      if ((await tx.query(
        'record_folders',
        where:
            parentId == null
                ? 'name = ? AND parent_id IS NULL AND id != ?'
                : 'name = ? AND parent_id = ? AND id != ?',
        whereArgs:
            parentId == null
                ? [name.trim(), id ?? -1]
                : [name.trim(), parentId, id ?? -1],
      )).isNotEmpty)
        throw const FormatException('该目录下已有同名文件夹');
      final fields = <String, Object?>{
        'name': name.trim(),
        'parent_id': parentId,
      };
      if (id == null) return tx.insert('record_folders', fields);
      await tx.update(
        'record_folders',
        fields,
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    });
  }

  Future<void> saveEntry(RowData fields, List<RowData> links, {int? id}) async {
    await (await db).transaction((tx) async {
      final key = id ?? await tx.insert('entries', fields);
      if (id != null)
        await tx.update('entries', fields, where: 'id = ?', whereArgs: [id]);
      await tx.delete('record_links', where: 'entry_id = ?', whereArgs: [key]);
      for (final link in links) {
        final table = val(link, 'target_table');
        final target = link['target_id'];
        if (![
              'entries',
              'courses',
              'works',
              'events',
              'goals',
            ].contains(table) ||
            target == null ||
            (table == 'entries' && target == key))
          continue;
        if ((await tx.query(
          table,
          where: 'id = ?',
          whereArgs: [target],
        )).isEmpty)
          continue;
        await tx.insert('record_links', {
          'entry_id': key,
          'target_table': table,
          'target_id': target,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> saveGoalItem(RowData fields, {int? id, String note = ''}) async {
    final target = goalNumber(val(fields, 'target_value'), positive: true);
    final current = goalNumber(val(fields, 'current_value'), positive: false);
    if (val(fields, 'title').trim().isEmpty ||
        val(fields, 'unit').trim().isEmpty)
      throw const FormatException('请填写内容名称和单位');
    await (await db).transaction((tx) async {
      final old =
          id == null
              ? null
              : (await tx.query(
                'goal_items',
                where: 'id = ?',
                whereArgs: [id],
              )).firstOrNull;
      if (id != null && old == null) throw StateError('内容已不存在');
      final data = {
        ...fields,
        'target_value': target,
        'current_value': current,
      };
      final key = id ?? await tx.insert('goal_items', data);
      if (id != null)
        await tx.update('goal_items', data, where: 'id = ?', whereArgs: [id]);
      if (old == null ||
          old['current_value'] != current ||
          old['target_value'] != target ||
          old['unit'] != fields['unit'])
        await tx.insert('goal_item_updates', {
          'item_id': key,
          'previous_value': old?['current_value'] ?? 0,
          'current_value': current,
          'target_value': target,
          'unit': fields['unit'],
          'note': note,
          'created_at': DateTime.now().toIso8601String(),
        });
    });
  }

  static Future<void> _createCornerSchema(Database db) async {
    await db.execute(
      "ALTER TABLE works ADD COLUMN shelf TEXT NOT NULL DEFAULT '文学'",
    );
    await db.execute("UPDATE works SET shelf = '娱乐' WHERE type = '漫画'");
    await db.execute(
      "CREATE TABLE cloud_posts (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL DEFAULT '', body TEXT NOT NULL DEFAULT '', category TEXT NOT NULL DEFAULT '日常感想', image_path TEXT, caption TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL)",
    );
    await db.execute(
      'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  Future<void> setHomePhoto(int? id) async {
    final database = await db;
    await database.insert('preferences', {
      'key': 'home_photo',
      'value': id?.toString() ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Book covers use the existing preferences table: no schema change or rebuild.
  Future<Map<int, String>> bookCovers() async {
    final rows = await (await db).query(
      'preferences',
      where: 'key LIKE ?',
      whereArgs: ['work_cover_%'],
    );
    return {
      for (final row in rows)
        if (int.tryParse(val(row, 'key').replaceFirst('work_cover_', ''))
            case final int id)
          if (val(row, 'value').isNotEmpty) id: val(row, 'value'),
    };
  }

  Future<void> saveWork(RowData fields, {int? id, String? cover}) async {
    await (await db).transaction((tx) async {
      final workId = id ?? await tx.insert('works', fields);
      if (id != null)
        await tx.update('works', fields, where: 'id = ?', whereArgs: [id]);
      await tx.insert('preferences', {
        'key': 'work_cover_$workId',
        'value': cover ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<RowData?> homePhoto() async {
    final database = await db;
    final pref = await database.query(
      'preferences',
      where: 'key = ?',
      whereArgs: ['home_photo'],
    );
    final id = pref.isEmpty ? null : int.tryParse(val(pref.first, 'value'));
    if (id == null) return null;
    final rows = await database.query(
      'cloud_posts',
      where: 'id = ?',
      whereArgs: [id],
    );
    final photo = rows.firstOrNull;
    return photo == null || val(photo, 'image_path').isEmpty ? null : photo;
  }

  Future<RowData?> recordBannerQuote() async {
    final database = await db;
    final pref = await database.query(
      'preferences',
      where: 'key = ?',
      whereArgs: ['record_banner_entry'],
    );
    final id = pref.isEmpty ? null : int.tryParse(val(pref.single, 'value'));
    if (id == null) return null;
    final rows = await database.query(
      'entries',
      where: "id = ? AND kind = '摘录'",
      whereArgs: [id],
    );
    return rows.firstOrNull;
  }

  Future<void> useRecordBannerQuote(int? id) async {
    final database = await db;
    if (id != null &&
        (await database.query(
          'entries',
          where: "id = ? AND kind = '摘录'",
          whereArgs: [id],
        )).isEmpty)
      throw StateError('这条句子已经不存在');
    await database.insert('preferences', {
      'key': 'record_banner_entry',
      'value': id?.toString() ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Reuse an unchanged quote; editing the banner creates a new saved excerpt.
  Future<int> saveRecordBannerQuote(String sentence, String subtitle) async {
    if (sentence.trim().isEmpty) throw const FormatException('请写下一句话');
    return (await db).transaction((tx) async {
      final same = await tx.query(
        'entries',
        where: 'kind = ? AND body = ? AND title = ?',
        whereArgs: ['摘录', sentence.trim(), subtitle.trim()],
        limit: 1,
      );
      int id;
      if (same.isNotEmpty) {
        id = rowId(same.single);
      } else {
        final folders = await tx.query(
          'record_folders',
          where: 'name = ? AND parent_id IS NULL',
          whereArgs: ['摘录'],
          limit: 1,
        );
        final now = DateTime.now();
        id = await tx.insert('entries', {
          'title': subtitle.trim(),
          'body': sentence.trim(),
          'kind': '摘录',
          'folder_id': folders.firstOrNull?['id'],
          'entry_date': dayKey(now),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
      await tx.insert('preferences', {
        'key': 'record_banner_entry',
        'value': '$id',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return id;
    });
  }

  static Future<void> _createTimetableSchema(Database db) async {
    await db.execute('ALTER TABLE courses ADD COLUMN semester_id TEXT');
    await db.execute('ALTER TABLE courses ADD COLUMN import_key TEXT');
    await db.execute(
      "ALTER TABLE courses ADD COLUMN schedule_note TEXT NOT NULL DEFAULT ''",
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_courses_import ON courses(import_key)',
    );
    await db.execute('''CREATE TABLE semesters (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, first_monday TEXT,
      max_week INTEGER NOT NULL DEFAULT 20)''');
    await db.execute(
      '''CREATE TABLE course_meetings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
      semester_id TEXT NOT NULL REFERENCES semesters(id),
      weekday INTEGER NOT NULL, start_period INTEGER NOT NULL, end_period INTEGER NOT NULL,
      weeks TEXT NOT NULL, weeks_text TEXT NOT NULL,
      teacher TEXT NOT NULL, room TEXT NOT NULL, source_key TEXT UNIQUE NOT NULL)''',
    );
    await db.execute(
      'CREATE INDEX idx_meetings_course ON course_meetings(course_id)',
    );
    await db.execute(
      'CREATE TABLE imports (source_key TEXT PRIMARY KEY, imported_at TEXT NOT NULL)',
    );
  }

  static Future<void> _createGoalSchema(Database db) async {
    await db.execute(
      '''CREATE TABLE goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
      semester TEXT NOT NULL, category TEXT NOT NULL DEFAULT '', detail TEXT NOT NULL DEFAULT '',
      target_value REAL NOT NULL CHECK(target_value > 0),
      current_value REAL NOT NULL DEFAULT 0 CHECK(current_value >= 0),
      unit TEXT NOT NULL, due_date TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    );
    await db.execute('''CREATE TABLE goal_updates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      goal_id INTEGER NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
      previous_value REAL NOT NULL, current_value REAL NOT NULL,
      target_value REAL NOT NULL, unit TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL)''');
    await db.execute('CREATE INDEX idx_goals_semester ON goals(semester)');
    await db.execute(
      'CREATE INDEX idx_goal_updates_goal ON goal_updates(goal_id, id)',
    );
  }

  Future<int> saveGoal(RowData fields, {int? id}) async {
    final target = goalNumber('${fields['target_value']}', positive: true);
    final current = goalNumber('${fields['current_value']}', positive: false);
    if (val(fields, 'title').trim().isEmpty ||
        val(fields, 'semester').trim().isEmpty ||
        val(fields, 'unit').trim().isEmpty)
      throw const FormatException('请填写目标名称、学期和单位');
    final database = await db;
    return database.transaction((tx) async {
      final old =
          id == null
              ? null
              : (await tx.query(
                'goals',
                where: 'id = ?',
                whereArgs: [id],
              )).firstOrNull;
      if (id != null && old == null) throw StateError('目标已不存在');
      final now = DateTime.now().toIso8601String();
      final data = <String, Object?>{
        for (final key in ['title', 'semester', 'category', 'detail', 'unit'])
          key: val(fields, key).trim(),
        'target_value': target,
        'current_value': current,
        'due_date': fields['due_date'],
        'created_at': old?['created_at'] ?? now,
        'updated_at': now,
      };
      final goalId = id ?? await tx.insert('goals', data);
      if (id != null)
        await tx.update('goals', data, where: 'id = ?', whereArgs: [id]);
      if (old == null ||
          old['current_value'] != current ||
          old['target_value'] != target ||
          old['unit'] != data['unit']) {
        await tx.insert('goal_updates', {
          'goal_id': goalId,
          'previous_value': old?['current_value'] ?? 0,
          'current_value': current,
          'target_value': target,
          'unit': data['unit'],
          'note': old == null ? '创建目标' : '编辑目标与进度',
          'created_at': now,
        });
      }
      return goalId;
    });
  }

  Future<void> updateGoalProgress(int id, double current, String note) async {
    goalNumber('$current', positive: false);
    final database = await db;
    await database.transaction((tx) async {
      final rows = await tx.query('goals', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('目标已不存在');
      final old = rows.single, now = DateTime.now().toIso8601String();
      await tx.update(
        'goals',
        {'current_value': current, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      await tx.insert('goal_updates', {
        'goal_id': id,
        'previous_value': old['current_value'],
        'current_value': current,
        'target_value': old['target_value'],
        'unit': old['unit'],
        'note': note.trim(),
        'created_at': now,
      });
    });
  }

  /// A source is applied once in one transaction. App upgrades never overwrite
  /// subsequent edits or duplicate the imported courses/meetings.
  Future<void> importBundledTimetable(Database database) async {
    final source =
        jsonDecode(
              await rootBundle.loadString('assets/data/semester_2026_pwa.json'),
            )
            as Map<String, dynamic>;
    final key = source['import_key'] as String;
    await database.transaction((tx) async {
      if ((await tx.query(
        'imports',
        where: 'source_key = ?',
        whereArgs: [key],
      )).isNotEmpty)
        return;
      final term = Map<String, Object?>.from(source['semester'] as Map);
      await tx.insert(
        'semesters',
        term,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final ids = <String, int>{};
      for (final raw in source['courses'] as List) {
        final c = raw as Map;
        ids[c['key'] as String] = await tx.insert('courses', {
          'name': c['name'],
          'teacher': (c['teachers'] as List).join('、'),
          'semester': term['name'],
          'semester_id': term['id'],
          'import_key': '$key:${c['key']}',
          'schedule_note': c['schedule_note'],
        });
      }
      for (final raw in source['meetings'] as List) {
        final m = raw as Map;
        await tx.insert('course_meetings', {
          'course_id': ids[m['course_key']],
          'semester_id': term['id'],
          'weekday': m['weekday'],
          'start_period': m['start_period'],
          'end_period': m['end_period'],
          'weeks': jsonEncode(m['weeks']),
          'weeks_text': m['weeks_text'],
          'teacher': m['teacher'],
          'room': m['room'],
          'source_key': '$key:${m['key']}',
        });
      }
      await tx.insert('imports', {
        'source_key': key,
        'imported_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<RowData>> all(
    String table, {
    String? orderBy,
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final database = await db;
    if (!{
      'courses',
      'tasks',
      'entries',
      'moods',
      'events',
      'works',
      'cloud_posts',
      'course_meetings',
      'semesters',
      'goals',
      'goal_updates',
      'record_folders',
      'record_links',
      'goal_items',
      'goal_item_updates',
    }.contains(table)) {
      throw ArgumentError('Unknown table: $table');
    }
    return database.query(
      table,
      orderBy: orderBy,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<void> upsert(
    String table,
    RowData fields, {
    int? id,
    String? day,
  }) async {
    final database = await db;
    if (!{
      'courses',
      'tasks',
      'entries',
      'moods',
      'events',
      'works',
      'cloud_posts',
    }.contains(table))
      throw ArgumentError(table);
    if (day != null && table == 'moods') {
      await database.insert('moods', {
        'day': day,
        ...fields,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else if (id == null) {
      await database.insert(table, fields);
    } else {
      await database.update(table, fields, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> delete(String table, int id) async {
    if (!{
      'courses',
      'tasks',
      'entries',
      'events',
      'works',
      'cloud_posts',
      'goals',
      'record_folders',
      'goal_items',
    }.contains(table))
      throw ArgumentError(table);
    final database = await db;
    await database.transaction((tx) async {
      await tx.delete(table, where: 'id = ?', whereArgs: [id]);
      await tx.delete(
        'record_links',
        where: 'target_table = ? AND target_id = ?',
        whereArgs: [table, id],
      );
      if (table == 'works')
        await tx.delete(
          'preferences',
          where: 'key = ?',
          whereArgs: ['work_cover_$id'],
        );
    });
  }

  static const backupTables = [
    'semesters',
    'courses',
    'tasks',
    'entries',
    'moods',
    'events',
    'works',
    'cloud_posts',
    'preferences',
    'course_meetings',
    'imports',
    'goals',
    'goal_updates',
    'record_folders',
    'record_links',
    'goal_items',
    'goal_item_updates',
  ];

  Future<Map<String, dynamic>> exportBackup() async {
    final database = await db;
    return database.transaction(
      (tx) async => {
        'app': 'richang-pwa',
        'schema': 5,
        'exported_at': DateTime.now().toIso8601String(),
        'tables': {
          for (final table in backupTables) table: await tx.query(table),
        },
      },
    );
  }

  Future<void> restoreBackup(Map<String, dynamic> source) async {
    if (source['app'] != 'richang-pwa' ||
        source['schema'] != 5 ||
        source['tables'] is! Map)
      throw const FormatException('不是兼容的日常 PWA 备份');
    final tables = source['tables'] as Map;
    if (tables.length != backupTables.length ||
        !backupTables.every((t) => tables[t] is List))
      throw const FormatException('备份表不完整');
    final database = await db;
    // Defer relationships until all rows are restored, including nested folders.
    await database.transaction((tx) async {
      await tx.execute('PRAGMA defer_foreign_keys = ON');
      for (final t in backupTables.reversed) {
        await tx.delete(t);
      }
      for (final t in backupTables) {
        for (final row in tables[t] as List) {
          if (row is! Map) throw const FormatException('备份记录格式错误');
          await tx.insert(t, Map<String, Object?>.from(row));
        }
      }
      if ((await tx.rawQuery('PRAGMA foreign_key_check')).isNotEmpty)
        throw const FormatException('备份关联不完整，已取消恢复');
    });
  }

  Future<void> setSemesterMonday(String id, DateTime day) async {
    if (day.weekday != DateTime.monday) throw const FormatException('请选择周一');
    await (await db).update(
      'semesters',
      {'first_monday': dayKey(day)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> copyPhoto(String sourcePath) async {
    final source = XFile(sourcePath);
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) throw const FormatException('图片为空');
    if (bytes.length > 12 * 1024 * 1024)
      throw const FormatException('请选择 12 MB 以内的图片');
    final mime =
        source.mimeType ??
        (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50
            ? 'image/png'
            : 'image/jpeg');
    return imageDataUri(bytes, mime);
  }
}

String val(RowData row, String key) => (row[key] ?? '').toString();
int rowId(RowData row) => row['id'] as int;
String two(int n) => n.toString().padLeft(2, '0');
String dayKey(DateTime dt) => '${dt.year}-${two(dt.month)}-${two(dt.day)}';
String displayDay(DateTime dt) => '${dt.month}月${dt.day}日';
DateTime? tryDay(String day) => DateTime.tryParse(day);

String folderLabel(RowData folder, List<RowData> folders) {
  final names = <String>[];
  final seen = <int>{};
  RowData? current = folder;
  while (current != null && seen.add(rowId(current))) {
    names.insert(0, val(current, 'name'));
    final parent = current['parent_id'];
    current = folders.where((f) => f['id'] == parent).firstOrNull;
  }
  return names.join(' / ');
}
