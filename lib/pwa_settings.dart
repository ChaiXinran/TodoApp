import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'storage.dart';
import 'theme.dart';
import 'web_platform.dart';

class PwaSettings extends StatefulWidget {
  const PwaSettings({super.key});
  @override
  State<PwaSettings> createState() => _PwaSettingsState();
}

class _PwaSettingsState extends State<PwaSettings> {
  bool busy = false;
  String? message;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => message = '操作未完成：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    final source = await Store.instance.exportBackup();
    downloadText(jsonEncode(source), '日常备份-${dayKey(DateTime.now())}.json');
    if (mounted) setState(() => message = '备份已生成，包含记录、课表和图片。请保存到“文件”中。');
  }

  Future<void> restore() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: '日常备份',
          extensions: ['json'],
          mimeTypes: ['application/json'],
        ),
      ],
    );
    if (file == null) return;
    if (await file.length() > 80 * 1024 * 1024)
      throw const FormatException('备份文件过大（最多80 MB）');
    final data = jsonDecode(await file.readAsString());
    if (data is! Map<String, dynamic> ||
        data['app'] != 'richang-pwa' ||
        data['schema'] != 5)
      throw const FormatException('不是兼容的日常 PWA 备份');
    if (!mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('用备份替换本机数据？'),
            content: const Text('恢复会替换此网址下当前设备的全部记录和图片。建议先导出当前数据。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('替换并恢复'),
              ),
            ],
          ),
    );
    if (yes != true) return;
    await Store.instance.restoreBackup(data);
    if (mounted) setState(() => message = '恢复完成。返回后会重新读取数据。');
  }

  Future<void> semester() async {
    final rows = await Store.instance.all('semesters');
    if (rows.isEmpty) return;
    if (!mounted) return;
    final row = rows.first;
    final date = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(val(row, 'first_monday')) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      helpText: '选择第1周的周一',
    );
    if (date == null) return;
    await Store.instance.setSemesterMonday(val(row, 'id'), date);
    if (mounted)
      setState(() => message = '${val(row, 'name')} 第1周周一已设为 ${dayKey(date)}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('使用与备份')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        const SceneHeader(
          title: '把日常带在身边',
          subtitle: 'iPhone · Safari · 添加到主屏幕',
          palette: rose,
          icon: Icons.install_mobile,
        ),
        const SizedBox(height: 22),
        const Text(
          '安装到 iPhone',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        const Text(
          '使用 Safari 打开固定网址，点“分享” → “添加到主屏幕” → “添加”。之后从桌面图标进入。首次联网加载完成后可以离线使用。',
          style: TextStyle(height: 1.7),
        ),
        const SizedBox(height: 20),
        const Text(
          '数据只保存在这台设备的浏览器中，不自动与安卓或其他设备同步。清除网站数据会移除本机记录；更换网址也会使用另一份数据。请定期导出备份。',
          style: TextStyle(height: 1.7),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed:
              busy
                  ? null
                  : () => run(() async {
                    final granted = await requestPersistentStorage();
                    if (mounted)
                      setState(
                        () =>
                            message =
                                granted
                                    ? '浏览器已允许持久保存；仍建议定期备份。'
                                    : '浏览器暂未授予持久存储；添加到主屏幕后可再试，日常保存不受此按钮限制。',
                      );
                  }),
          icon: const Icon(Icons.shield_outlined),
          label: const Text('请求保留本机数据'),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: busy ? null : () => run(export),
          icon: const Icon(Icons.download_outlined),
          label: const Text('导出全部数据与图片'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : () => run(restore),
          icon: const Icon(Icons.restore),
          label: const Text('从备份恢复'),
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: busy ? null : () => run(semester),
          icon: const Icon(Icons.school_outlined),
          label: const Text('设置第1周周一'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Semantics(
              liveRegion: true,
              child: Text(message!, style: const TextStyle(height: 1.6)),
            ),
          ),
      ],
    ),
  );
}
