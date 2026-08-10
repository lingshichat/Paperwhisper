import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:paper_whisper_flutter/app/navigation/app_routes.dart';
import 'package:paper_whisper_flutter/config/app_theme.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/providers/diary_provider.dart';
import 'package:paper_whisper_flutter/providers/settings_provider.dart';
import 'package:paper_whisper_flutter/widgets/skeuomorphic_dialog.dart';

class BookDirectoryPage extends StatelessWidget {
  final int year;

  const BookDirectoryPage({super.key, required this.year});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;

    // Define Skeuomorphic Paper & Ink Styles
    final bookTheme = ThemeRegistry.get(theme).bookDirectory;

    Color inkColor =
        bookTheme.inkColor ??
        (theme == AppTheme.themeMidnight
            ? Colors.white
            : (theme == AppTheme.themeSeaFlower
                  ? const Color(0xFFC2185B)
                  : (theme == AppTheme.themeAmberLens
                        ? const Color(0xFF3E2723)
                        : const Color(0xFF680000))));
    Color paperColor =
        bookTheme.paperColor ??
        (theme == AppTheme.themeMidnight
            ? const Color(0xFF1A237E).withValues(alpha: 0.6)
            : (theme == AppTheme.themeSeaFlower
                  ? const Color(0xFFFFFFFF).withValues(alpha: 0.7)
                  : (theme == AppTheme.themeAmberLens
                        ? const Color(0xFFFFF8E1).withValues(alpha: 0.85)
                        : const Color(0xFFFFFDE7).withValues(alpha: 0.95))));
    Color paperBorderColor =
        bookTheme.paperBorderColor ??
        (theme == AppTheme.themeMidnight
            ? const Color(0xFF5C6BC0).withValues(alpha: 0.3)
            : (theme == AppTheme.themeSeaFlower
                  ? const Color(0xFFFCE4EC)
                  : (theme == AppTheme.themeAmberLens
                        ? const Color(0xFFFFECB3)
                        : const Color(0xFFFFCDD2).withValues(alpha: 0.5))));
    List<BoxShadow> paperShadow =
        bookTheme.paperShadow ??
        (theme == AppTheme.themeMidnight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : (theme == AppTheme.themeSeaFlower
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF06292).withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : (theme == AppTheme.themeAmberLens
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF3E2723,
                              ).withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: const Color(
                                0xFFB71C1C,
                              ).withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ])));

    // Define AppBar Color (Separate from Ink Color)
    // - Default/Amber/Midnight backgrounds are dark/vibrant -> Use White Text
    // - SeaFlower background is light -> Use Ink Color (Indigo)
    Color appBarColor = Colors.white;
    if (theme == AppTheme.themeSeaFlower ||
        theme == AppTheme.themeAfterRain ||
        theme == AppTheme.themeGardenOfWords) {
      appBarColor = inkColor;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              AppRoutes.bookshelf(initialYear: year),
            );
            if (result != null) {
              if (context.mounted) Navigator.pop(context, result);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$year 目录',
                style: GoogleFonts.notoSerifSc(
                  color: appBarColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more,
                size: 20,
                color: appBarColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. Background
          // Container(decoration: AppTheme.getBackground(theme)), // GLOBALIZED

          // 2. Visual Effects
          // if (theme == AppTheme.themeSeaFlower) const PetalRainWidget(), // GLOBALIZED
          // if (theme == AppTheme.themeMidnight) const StarrySkyWidget(), // GLOBALIZED

          // 3. Content - Single Paper Sheet
          Center(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 100, 24, 32),
              decoration: BoxDecoration(
                color: paperColor,
                borderRadius: BorderRadius.circular(
                  16,
                ), // Rounded paper corners
                border: Border.all(color: paperBorderColor, width: 1.0),
                boxShadow: paperShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Consumer<DiaryProvider>(
                  builder: (context, provider, child) {
                    final grouped = provider.getEntriesGroupedByYearMonth();
                    final yearData = grouped[year] ?? {};

                    return ListView.separated(
                      padding: EdgeInsets.zero, // No padding inside the paper
                      itemCount: 12,
                      separatorBuilder: (ctx, i) => Divider(
                        height: 1,
                        color: paperBorderColor,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (context, index) {
                        final month = index + 1; // 1-12
                        final hasEntries = yearData.containsKey(month);
                        final count = hasEntries ? yearData[month]!.length : 0;
                        final monthTitle = provider.getMonthTitle(year, month);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context, month);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 24,
                              ),
                              child: Row(
                                children: [
                                  // Month / Custom Title (Left Aligned)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          monthTitle,
                                          style: GoogleFonts.notoSerifSc(
                                            fontSize: 18,
                                            fontWeight: hasEntries
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: hasEntries
                                                ? inkColor
                                                : inkColor.withValues(
                                                    alpha: 0.5,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        if (hasEntries)
                                          Expanded(
                                            child: CustomPaint(
                                              painter: DottedLinePainter(
                                                color: inkColor.withValues(
                                                  alpha: 0.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Right Side: Count + Menu
                                  Row(
                                    children: [
                                      if (hasEntries)
                                        Text(
                                          '$count 篇',
                                          style: GoogleFonts.notoSerifSc(
                                            fontSize: 14,
                                            color: inkColor.withValues(
                                              alpha: 0.7,
                                            ),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      const SizedBox(
                                        width: 4,
                                      ), // Reduced spacing slightly to accommodate larger button
                                      SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.more_horiz,
                                            size: 24,
                                            color: inkColor.withValues(
                                              alpha: 0.4,
                                            ),
                                          ), // Slightly larger icon
                                          color: const Color(0xFFFAFAFA),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          onSelected: (action) {
                                            if (action == 'edit') {
                                              _showEditMonthDialog(
                                                context,
                                                provider,
                                                year,
                                                month,
                                                monthTitle,
                                              );
                                            } else if (action == 'reset') {
                                              provider.resetMonthTitle(
                                                year,
                                                month,
                                              );
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    size: 18,
                                                    color: Colors.black87,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '自定义标题',
                                                    style: TextStyle(
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'reset',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.restore,
                                                    size: 18,
                                                    color: Colors.black87,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    '恢复默认',
                                                    style: TextStyle(
                                                      color: Colors.black87,
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
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditMonthDialog(
    BuildContext context,
    DiaryProvider provider,
    int year,
    int month,
    String currentTitle,
  ) {
    final titleController = TextEditingController(
      text: currentTitle.contains('月') ? '' : currentTitle,
    );

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final dialogTheme = ThemeRegistry.get(theme).dialogInput;
    final textColor = dialogTheme.textColor;
    final hintColor = dialogTheme.hintColor;
    final borderColor = dialogTheme.borderColor;
    final focusedBorderColor = dialogTheme.focusedBorderColor;
    final iconColor = dialogTheme.iconColor;
    final descriptionColor = dialogTheme.descriptionColor;

    showDialog(
      context: context,
      builder: (ctx) => SkeuomorphicDialog(
        title: '自定义章节标题',
        headerIcon: Icons.edit_note,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              '为 $year年 $month月 定义一个独特的名字',
              style: TextStyle(color: descriptionColor, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: '章节标题',
                hintText: '例如：初夏、启程、邂逅',
                labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                hintStyle: TextStyle(color: hintColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: focusedBorderColor, width: 2),
                ),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: iconColor),
                  onPressed: () => titleController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          SkeuomorphicDialogButton(
            label: '取消',
            isPrimary: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          SkeuomorphicDialogButton(
            label: '保存',
            isPrimary: true,
            onPressed: () {
              final text = titleController.text.trim();
              if (text.isNotEmpty) {
                provider.setMonthTitle(year, month, text);
              } else {
                provider.resetMonthTitle(year, month);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  final Color color;

  DottedLinePainter({this.color = Colors.black26});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double dashWidth = 4;
    double dashSpace = 4;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant DottedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
