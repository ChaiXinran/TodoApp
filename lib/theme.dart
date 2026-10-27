import 'package:flutter/material.dart';

const paper = Color(0xFFFFFCF5);
const ink = Color(0xFF3C4039);

class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, required super.child});
  final SectionPalette palette;
  @override
  bool updateShouldNotify(PaletteScope oldWidget) =>
      palette != oldWidget.palette;
}

SectionPalette entryPalette(BuildContext context, SectionPalette fallback) =>
    context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.palette ??
    fallback;
Widget palettePage(
  BuildContext context,
  Widget child, [
  SectionPalette? palette,
]) {
  final p = palette ?? entryPalette(context, honey);
  return PaletteScope(
    palette: p,
    child: Theme(data: richangTheme(seedColor: p.accent), child: child),
  );
}

/// Semantic palettes keep future personal themes independent of business data.
class SectionPalette {
  const SectionPalette(this.light, this.soft, this.accent, this.deep);
  final Color light, soft, accent, deep;
}

const forest = SectionPalette(
  Color(0xFFEDF3E7),
  Color(0xFFD5E3C8),
  Color(0xFF5C7851),
  Color(0xFF354E36),
);
const ocean = SectionPalette(
  Color(0xFFECF4F9),
  Color(0xFFCDDFED),
  Color(0xFF477896),
  Color(0xFF294D68),
);
const oceanPale = SectionPalette(
  Color(0xFFF0F6FC),
  Color(0xFFD9E8F6),
  Color(0xFF527D9E),
  Color(0xFF2E526F),
);
const oceanShade = SectionPalette(
  Color(0xFFDCEBF5),
  Color(0xFFC0D7E8),
  Color(0xFF3E6F91),
  Color(0xFF24465F),
);
const rose = SectionPalette(
  Color(0xFFFFF0EF),
  Color(0xFFF3D4D9),
  Color(0xFFAB6478),
  Color(0xFF784556),
);
const honey = SectionPalette(
  Color(0xFFFFF3D4),
  Color(0xFFF5DFA5),
  Color(0xFF906821),
  Color(0xFF644B28),
);

// Compatibility names for date fields and existing editor surfaces.
const blueMist = Color(0xFFECF4F9);
const peach = Color(0xFFFFF0EF);
const mint = Color(0xFFEDF3E7);
const lavender = Color(0xFFFFF3D4);

SectionPalette recordPalette(String kind) => switch (kind) {
  '观剧感想' => rose,
  '阅读感想' || '摘录' => forest,
  '重要信息' => ocean,
  _ => honey,
};

// Optional seed is the entry point for future 云次方 palettes. Business data
// stays independent of the chosen visual theme and licensed theme assets.
ThemeData richangTheme({Color seedColor = const Color(0xFF906821)}) {
  final tint = Color.lerp(paper, seedColor, 0.13)!;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
    surface: paper,
    primary: seedColor,
    primaryContainer: tint,
    onPrimaryContainer: ink,
    secondary: seedColor,
    surfaceContainerHighest: tint,
  );
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: paper,
    colorScheme: colorScheme,
    dividerColor: const Color(0xFFEAE5DA),
    iconTheme: IconThemeData(color: seedColor),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tint,
      foregroundColor: seedColor,
      elevation: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: paper,
      selectedColor: tint,
      side: const BorderSide(color: Color(0xFFE3DED2)),
      labelStyle: const TextStyle(color: ink),
    ),
    fontFamily: 'NotoSansSC',
    fontFamilyFallback: const ['NotoEmoji'],
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      scrolledUnderElevation: 0,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: ink),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: paper,
      indicatorColor: tint,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class SceneHeader extends StatelessWidget {
  const SceneHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.icon,
    this.eyebrow,
  });
  final String title, subtitle;
  final String? eyebrow;
  final SectionPalette palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: ColoredBox(
      color: palette.light,
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -24,
            child: ExcludeSemantics(
              child: Icon(
                icon,
                size: 142,
                color: palette.soft.withValues(alpha: 0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.soft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: palette.accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null) ...[
                        Text(
                          eyebrow!,
                          style: TextStyle(fontSize: 11, color: palette.accent),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 19,
                          color: palette.deep,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: palette.accent,
                        ),
                      ),
                    ],
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

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.onTrailing,
    this.palette,
  });
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  final SectionPalette? palette;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: palette?.deep),
          ),
        ),
        if (trailing != null)
          TextButton(
            onPressed: onTrailing,
            style:
                palette == null
                    ? null
                    : TextButton.styleFrom(foregroundColor: palette!.accent),
            child: Text(trailing!),
          ),
      ],
    ),
  );
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.message, {super.key, this.icon = Icons.cloud_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SoftCard(
    color: Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: 0.6),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: ink))),
      ],
    ),
  );
}
