import 'dart:async';
import 'package:flutter/material.dart';
import 'storage.dart';
import 'theme.dart';
import 'mood_art.dart';
import 'editors.dart' show EditLayout;
import 'journal_pages.dart' show JournalPanel;

const defaultBannerSentence = '把喜欢的，都收好';
const defaultBannerSubtitle = '写给今天，也留给以后的自己。';
String bannerSentence(RowData? quote) =>
    quote == null
        ? defaultBannerSentence
        : val(quote, 'body').isEmpty
        ? val(quote, 'title')
        : val(quote, 'body');
String bannerSubtitle(RowData? quote) =>
    quote == null
        ? defaultBannerSubtitle
        : val(quote, 'body').isEmpty
        ? ''
        : val(quote, 'title');
String homeDateLabel(DateTime day) =>
    '${day.year}年${day.month}月${day.day}日 · 星期${'一二三四五六日'[day.weekday - 1]}';
Duration _untilTomorrow() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1).difference(now) +
      const Duration(seconds: 1);
}

class HomeDateCard extends StatefulWidget {
  const HomeDateCard({super.key, this.date});
  final DateTime? date;
  @override
  State<HomeDateCard> createState() => _HomeDateCardState();
}

class _HomeDateCardState extends State<HomeDateCard>
    with WidgetsBindingObserver {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    schedule();
  }

  void schedule() {
    timer?.cancel();
    if (widget.date == null)
      timer = Timer(_untilTomorrow(), () {
        if (mounted) setState(() {});
        schedule();
      });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
      schedule();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SceneHeader(
    title: '今天也要好好生活 ☁️',
    subtitle: '把重要的事与喜欢的瞬间都留下来。',
    palette: rose,
    icon: Icons.wb_sunny_outlined,
    eyebrow: homeDateLabel(widget.date ?? DateTime.now()),
  );
}

class RecordTopBanner extends StatefulWidget {
  const RecordTopBanner({
    super.key,
    required this.revision,
    required this.onMood,
    required this.onChanged,
  });
  final int revision;
  final Future<void> Function() onMood, onChanged;
  @override
  State<RecordTopBanner> createState() => _RecordTopBannerState();
}

class _RecordTopBannerState extends State<RecordTopBanner>
    with WidgetsBindingObserver {
  RowData? mood, quote;
  String? error;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    schedule();
  }

  void schedule() {
    timer?.cancel();
    timer = Timer(_untilTomorrow(), () {
      load();
      schedule();
    });
  }

  @override
  void didUpdateWidget(RecordTopBanner old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision) load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      load();
      schedule();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> load() async {
    try {
      final day = dayKey(DateTime.now());
      final moods = await Store.instance.all(
        'moods',
        where: 'day = ?',
        whereArgs: [day],
      );
      final chosen = await Store.instance.recordBannerQuote();
      if (mounted)
        setState(() {
          mood = moods.firstOrNull;
          quote = chosen;
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> editQuote() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                palettePage(context, BannerQuoteEditor(initial: quote), honey),
      ),
    );
    if (changed == true) {
      await widget.onChanged();
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => JournalPanel(
    palette: honey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: '编辑顶部句子',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: editQuote,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MY LITTLE ARCHIVE',
                          style: TextStyle(fontSize: 10, letterSpacing: 1),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          bannerSentence(quote),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (bannerSubtitle(quote).isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            bannerSubtitle(quote),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        Text(
                          '点这里编辑或选一句',
                          style: TextStyle(fontSize: 10, color: honey.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '设置今日心情',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await widget.onMood();
                  await load();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoodSticker(
                        emoji: mood == null ? '🙂' : val(mood!, 'emoji'),
                        size: 90,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mood == null
                            ? '今日心情 · 点击设置'
                            : '今日心情 · ${moodOption(val(mood!, 'emoji')).label}',
                        style: TextStyle(fontSize: 10, color: honey.deep),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (error != null)
          TextButton(onPressed: load, child: const Text('读取失败，点击重试')),
      ],
    ),
  );
}

class BannerQuoteEditor extends StatefulWidget {
  const BannerQuoteEditor({super.key, this.initial});
  final RowData? initial;
  @override
  State<BannerQuoteEditor> createState() => _BannerQuoteEditorState();
}

class _BannerQuoteEditorState extends State<BannerQuoteEditor> {
  late final sentence = TextEditingController(
    text: bannerSentence(widget.initial),
  );
  late final subtitle = TextEditingController(
    text: bannerSubtitle(widget.initial),
  );
  int? pickedId;
  @override
  void initState() {
    super.initState();
    pickedId = widget.initial?['id'] as int?;
  }

  @override
  void dispose() {
    sentence.dispose();
    subtitle.dispose();
    super.dispose();
  }

  Future<void> choose() async {
    final rows = await Store.instance.all(
      'entries',
      where: "kind = '摘录' AND (trim(body) != '' OR trim(title) != '')",
      orderBy: 'updated_at DESC, id DESC',
    );
    if (!mounted) return;
    final result = await showModalBottomSheet<RowData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => palettePage(context, QuoteHistoryPicker(quotes: rows), honey),
    );
    if (result != null && mounted)
      setState(() {
        pickedId = rowId(result);
        sentence.text = bannerSentence(result);
        subtitle.text = bannerSubtitle(result);
      });
  }

  Future<void> save() async {
    if (pickedId != null) {
      final rows = await Store.instance.all(
        'entries',
        where: "id = ? AND kind = '摘录'",
        whereArgs: [pickedId],
      );
      if (rows.isNotEmpty &&
          sentence.text.trim() == bannerSentence(rows.single).trim() &&
          subtitle.text.trim() == bannerSubtitle(rows.single).trim()) {
        await Store.instance.useRecordBannerQuote(pickedId);
        if (mounted) Navigator.pop(context, true);
        return;
      }
    }
    await Store.instance.saveRecordBannerQuote(sentence.text, subtitle.text);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => EditLayout(
    title: '顶部句子',
    palette: honey,
    onSave: save,
    children: [
      const Text(
        '写一句给今天的话。保存后会放进摘录，也可以以后再次选用。',
        style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.6),
      ),
      TextField(
        controller: sentence,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(labelText: '句子 *'),
      ),
      TextField(
        controller: subtitle,
        minLines: 1,
        maxLines: 3,
        decoration: const InputDecoration(labelText: '副句 / 出处（可选）'),
      ),
      OutlinedButton.icon(
        onPressed: choose,
        icon: const Icon(Icons.history),
        label: const Text('从已存句子选择'),
      ),
      TextButton(
        onPressed: () async {
          await Store.instance.useRecordBannerQuote(null);
          if (context.mounted) Navigator.pop(context, true);
        },
        child: const Text('使用默认句子'),
      ),
    ],
  );
}

class QuoteHistoryPicker extends StatefulWidget {
  const QuoteHistoryPicker({super.key, required this.quotes});
  final List<RowData> quotes;
  @override
  State<QuoteHistoryPicker> createState() => _QuoteHistoryPickerState();
}

class _QuoteHistoryPickerState extends State<QuoteHistoryPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final rows =
        widget.quotes
            .where(
              (r) => '${val(r, 'body')} ${val(r, 'title')}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: SizedBox(
          height:
              (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom) *
              .65,
          child: Column(
            children: [
              const Text(
                '选择保存过的句子',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索已存摘录',
                ),
                onChanged: (v) => setState(() => query = v.trim()),
              ),
              const SizedBox(height: 10),
              Expanded(
                child:
                    rows.isEmpty
                        ? const Center(child: Text('还没有匹配的句子，可以先手动写一句。'))
                        : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder:
                              (c, i) => ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                leading: const Icon(Icons.format_quote),
                                title: Text(
                                  bannerSentence(rows[i]),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  bannerSubtitle(rows[i]).isEmpty
                                      ? val(rows[i], 'entry_date')
                                      : bannerSubtitle(rows[i]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => Navigator.pop(context, rows[i]),
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
