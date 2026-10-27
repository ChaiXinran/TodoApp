import 'package:flutter/material.dart';
import 'theme.dart';

class MoodOption {
  const MoodOption(this.emoji, this.label, this.asset);
  final String emoji, label;
  final String? asset;
}

// Keep the stored emoji keys, so existing moods need no data migration.
const moodOptions = [
  MoodOption('🙂', '温柔', 'assets/moods/gentle.png'),
  MoodOption('😄', '开心', 'assets/moods/happy.png'),
  MoodOption('🥹', '感动', 'assets/moods/touched.png'),
  MoodOption('🤩', '期待', 'assets/moods/excited.png'),
  MoodOption('😔', '难过', 'assets/moods/sad.png'),
  MoodOption('😰', '焦虑', 'assets/moods/anxious.png'),
  MoodOption('😠', '生气', 'assets/moods/angry.png'),
  MoodOption('😫', '烦躁', 'assets/moods/stressed.png'),
];

MoodOption moodOption(String emoji) =>
    moodOptions.where((m) => m.emoji == emoji).firstOrNull ??
    MoodOption(emoji, switch (emoji) {
      '😐' => '平静',
      '😴' => '困倦',
      _ => '原心情',
    }, null);

class MoodSticker extends StatelessWidget {
  const MoodSticker({super.key, required this.emoji, this.size = 64});
  final String emoji;
  final double size;
  @override
  Widget build(BuildContext context) {
    final option = moodOption(emoji);
    final fallback = Center(
      child: Text(emoji, style: TextStyle(fontSize: size * .6)),
    );
    return Semantics(
      label: '心情 ${option.label}',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child:
              option.asset == null
                  ? fallback
                  : Image.asset(
                    option.asset!,
                    width: size,
                    height: size,
                    cacheWidth: (size * 3).ceil(),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => fallback,
                  ),
        ),
      ),
    );
  }
}

class MoodPicker extends StatelessWidget {
  const MoodPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.scrollable = false,
  });
  final String selected;
  final ValueChanged<String>? onChanged;
  final bool scrollable;
  @override
  Widget build(BuildContext context) {
    final palette = entryPalette(context, honey);
    final options = [...moodOptions];
    if (selected.isNotEmpty && !moodOptions.any((m) => m.emoji == selected))
      options.add(moodOption(selected));
    final children =
        options
            .map(
              (m) => Semantics(
                button: true,
                selected: selected == m.emoji,
                child: Tooltip(
                  message: '心情 ${m.emoji}',
                  child: Material(
                    color:
                        selected == m.emoji ? palette.soft : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap:
                          onChanged == null ? null : () => onChanged!(m.emoji),
                      child: Container(
                        width: scrollable ? 78 : 68,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                selected == m.emoji
                                    ? palette.accent
                                    : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeSemantics(
                              child: MoodSticker(
                                emoji: m.emoji,
                                size: scrollable ? 70 : 60,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              m.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    selected == m.emoji
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                color: palette.deep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList();
    return scrollable
        ? SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                children
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: c,
                      ),
                    )
                    .toList(),
          ),
        )
        : Wrap(spacing: 5, runSpacing: 8, children: children);
  }
}
