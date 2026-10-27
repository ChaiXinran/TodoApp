// Browser-only verification entry; never included in production builds.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'package:richang/main.dart' show RichangApp;
import 'package:richang/storage.dart';
import 'package:richang/stored_image.dart';
import 'package:richang/schedule.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final s = Store.instance;
    await s.db;
    final existing = await s.all(
      'tasks',
      where: 'title = ?',
      whereArgs: ['PWA验收：复习风险理论'],
    );
    if (existing.isNotEmpty) {
      final report = {
        'status': 'reopened',
        'tasks': (await s.all('tasks')).length,
        'photo': (await s.all(
          'cloud_posts',
        )).any((r) => val(r, 'image_path').startsWith('data:')),
      };
      web.document.documentElement!.setAttribute(
        'data-richang-test',
        jsonEncode(report),
      );
      runApp(const RichangApp());
      return;
    }
    final courses = await s.all('courses'),
        meetings = await s.all('course_meetings'),
        terms = await s.all('semesters');
    check(courses.length == 11 && meetings.length == 13, 'screenshot counts');
    check(
      teachingWeek(DateTime(2026, 10, 27), terms.single['first_monday']) == 10,
      'week anchor',
    );
    final course = courses.firstWhere((c) => c['name'] == '风险理论');
    final now = DateTime.now().toIso8601String();
    await s.upsert('tasks', {
      'title': 'PWA验收：复习风险理论',
      'detail': '浏览器保存后重开验证',
      'course_id': rowId(course),
      'study_kind': '复习',
      'done': 0,
      'created_at': now,
      'due_date': '2026-10-30',
    });
    final task = (await s.all('tasks')).single;
    await s.upsert('tasks', {'done': 1}, id: rowId(task));
    check((await s.all('tasks')).single['done'] == 1, 'task toggle');
    await s.upsert('tasks', {'done': 0}, id: rowId(task));
    final folder = await s.saveFolder('PWA验收随笔');
    final data = await rootBundle.load('assets/branding/richang_cover.png');
    final uri = imageDataUri(data.buffer.asUint8List(), 'image/png');
    await s.saveEntry(
      {
        'title': 'PWA验收：记下小确幸',
        'body': '图片、关联与文字在本机保存。',
        'kind': '随笔',
        'entry_date': '2026-10-27',
        'folder_id': folder,
        'image_path': uri,
        'created_at': now,
        'updated_at': now,
      },
      [
        {'target_table': 'courses', 'target_id': rowId(course)},
      ],
    );
    await s.upsert('moods', {
      'emoji': '😄',
      'memo': 'PWA验收心情',
    }, day: dayKey(DateTime.now()));
    await s.upsert('cloud_posts', {
      'title': 'PWA验收照片',
      'body': '刷新后图片仍在',
      'category': '日常感想',
      'image_path': uri,
      'caption': '本机保存',
      'updated_at': now,
    });
    final goal = await s.saveGoal({
      'title': 'PWA验收：学期阅读',
      'semester': '2026 秋',
      'unit': '本',
      'target_value': 10,
      'current_value': 2,
    });
    await s.updateGoalProgress(goal, 3, '更新累计进度');
    await s.saveGoalItem({
      'goal_id': goal,
      'title': '阅读量',
      'unit': '本',
      'target_value': 10,
      'current_value': 3,
    });
    await s.saveGoalItem({
      'goal_id': goal,
      'title': '志愿时长',
      'unit': '小时',
      'target_value': 20,
      'current_value': 5,
    });
    final quote = await s.saveRecordBannerQuote('今天也有值得收藏的小事。', 'PWA验收摘录');
    await s.saveWork({
      'name': 'PWA验收文学书架',
      'shelf': '文学',
      'type': '小说',
      'progress': 20,
    }, cover: uri);
    final backup = await s.exportBackup();
    final serialized = jsonEncode(backup);
    await s.delete('tasks', rowId(task));
    await s.restoreBackup(jsonDecode(serialized));
    check((await s.all('tasks')).length == 1, 'backup restore task');
    check(
      val((await s.all('entries')).first, 'image_path') == uri,
      'backup restore image',
    );
    final bad = jsonDecode(serialized) as Map<String, dynamic>;
    (bad['tables']['tasks'] as List).add({
      'id': 999999,
      'title': 'invalid',
      'created_at': now,
      'course_id': -999,
    });
    var rejected = false;
    try {
      await s.restoreBackup(bad);
    } catch (_) {
      rejected = true;
    }
    check(rejected, 'bad backup rejection');
    check((await s.all('tasks')).length == 1, 'invalid restore rollback');
    await s.close();
    check((await s.all('courses')).length == 11, 'course persistence');
    check((await s.all('moods')).single['emoji'] == '😄', 'mood persistence');
    check(rowId((await s.recordBannerQuote())!) == quote, 'quote persistence');
    check((await s.all('goal_items')).length == 2, 'goal items persistence');
    check(
      (await s.bookCovers()).values.single == uri,
      'book cover persistence',
    );
    check((await s.all('record_links')).length == 1, 'association persistence');
    final version =
        (await (await s.db).rawQuery(
          'PRAGMA user_version',
        )).single.values.single;
    check(version == 5, 'schema');
    web.document.documentElement!.setAttribute(
      'data-richang-test',
      jsonEncode({
        'status': 'passed',
        'courses': 11,
        'meetings': 13,
        'week': 10,
        'task_crud': true,
        'notes_and_images': true,
        'moods': true,
        'goals_and_items': true,
        'folders_and_links': true,
        'backup_restore_and_rollback': true,
        'reopen_persistence': true,
        'schema': version,
      }),
    );
    runApp(const RichangApp());
  } catch (e, st) {
    web.document.documentElement!.setAttribute(
      'data-richang-test',
      jsonEncode({'status': 'failed', 'error': '$e', 'stack': '$st'}),
    );
    runApp(MaterialApp(home: Scaffold(body: SelectableText('$e'))));
  }
}
