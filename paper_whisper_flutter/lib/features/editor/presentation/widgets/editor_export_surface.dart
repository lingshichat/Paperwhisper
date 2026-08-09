import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_theme.dart';
import '../../../../models/diary_entry.dart';
import '../../data/diary_export_service.dart';
import 'editor_branding_footer.dart';
import 'editor_meta_selector.dart';
import 'export_ribbon_painter.dart';
import 'lined_paper_painter.dart';

/// 长图导出分块表面：按导出计划渲染 Header + N 个正文块 + Footer。
///
/// 纯展示组件，props 驱动，不持有会话与业务依赖：
/// - 分块布局、700 宽、纸色/边框/丝带/横线/字体/metadata/footer
///   与原页面 `_buildExportChunks` 逐字一致
/// - [repaintKeys] 由页面创建并拥有（页面负责 RenderRepaintBoundary 查找
///   与捕获），组件只按序绑定到各分块
/// - 标题/日期/天气/心情与兼容模式横线开关由 props 传入，不读 Provider
/// - 不包含任何 capture / IO / service / Toast / Dialog 逻辑
class EditorExportSurface extends StatelessWidget {
  /// 分块捕获 key（页面拥有，用于 RepaintBoundary 查找）。
  final List<GlobalKey> repaintKeys;

  /// 当前导出分块计划（可为 null：计划未就绪时组件不渲染任何
  /// RepaintBoundary，保持父级 Offstage/Positioned 结构安全）。
  final DiaryExportChunkPlan? plan;

  /// 主题名（导出纸色/边框/丝带/横线取色入口）。
  final String theme;

  /// 标题/正文主文本颜色。
  final Color textColor;

  /// 元信息与 footer 次要文本颜色。
  final Color secondaryColor;

  /// 导出标题（为空时渲染「无题」）。
  final String title;

  /// 导出日期字符串（yyyy-MM-dd）。
  final String dateString;

  /// 导出天气。
  final WeatherType weather;

  /// 导出心情。
  final MoodType mood;

  /// 兼容模式：隐藏正文横线。
  final bool hideLines;

  const EditorExportSurface({
    super.key,
    required this.repaintKeys,
    required this.plan,
    required this.theme,
    required this.textColor,
    required this.secondaryColor,
    required this.title,
    required this.dateString,
    required this.weather,
    required this.mood,
    required this.hideLines,
  });

  @override
  Widget build(BuildContext context) {
    final DiaryExportChunkPlan? currentPlan = plan;
    if (currentPlan == null) {
      // 计划未就绪（如路由动画期间清空）：不产生任何 RepaintBoundary。
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _buildChunks(currentPlan),
    );
  }

  List<Widget> _buildChunks(DiaryExportChunkPlan plan) {
    if (repaintKeys.isEmpty) return [];
    final List<Widget> chunks = [];
    int keyIndex = 0;

    // 通过 AppTheme 获取导出相关颜色
    final tc = AppTheme.getEditorTheme(theme);
    final Color paperColor = tc['exportPaperColor'];
    final Color borderColor = tc['exportBorderColor'];

    // Default theme special case: Top border only.
    final bool isDefaultTheme =
        theme != AppTheme.themeSeaFlower &&
        theme != AppTheme.themeMidnight &&
        theme != AppTheme.themeAmberLens &&
        theme != AppTheme.themeAfterRain;

    // --- Chunk 1: Header ---
    if (keyIndex < repaintKeys.length) {
      chunks.add(
        RepaintBoundary(
          key: repaintKeys[keyIndex++],
          child: Container(
            width: 700,
            decoration: BoxDecoration(
              color: paperColor,
              border: Border(top: BorderSide(color: borderColor, width: 8)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(0),
              ),
            ),
            // Padding handled inside
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 60,
                    right: 60,
                    top: 60,
                    bottom: 0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Default Theme Red Line
                      if (isDefaultTheme)
                        Container(
                          height: 8,
                          width: 80,
                          margin: const EdgeInsets.only(bottom: 20),
                          color: const Color(0xFFC0392B),
                        ),

                      _buildHeader(),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          width: 60,
                          height: 2,
                          color: (tc['cursorColor'] as Color).withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                      ), // Spacing between line and text
                    ],
                  ),
                ),
                // Ribbon (Only on Header)
                Positioned(right: 40, top: -8, child: _buildRibbon()),
              ],
            ),
          ),
        ),
      );
    }

    // --- Body Chunks (文本切片由导出服务的分块计划提供) ---

    for (final String chunkText in plan.bodyChunkTexts) {
      if (keyIndex < repaintKeys.length) {
        chunks.add(
          RepaintBoundary(
            key: repaintKeys[keyIndex++],
            child: Container(
              width: 700,
              decoration: BoxDecoration(
                color: paperColor,
                borderRadius: BorderRadius.zero, // Square for seamless stitch
              ),
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 0),
              child: _buildChunkText(chunkText),
            ),
          ),
        );
      }
    }

    // --- Chunk Last: Footer ---
    if (keyIndex < repaintKeys.length) {
      chunks.add(
        RepaintBoundary(
          key: repaintKeys[keyIndex++],
          child: Container(
            width: 700,
            decoration: BoxDecoration(
              color: paperColor,
              // Rounded Bottom?
            ),
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add a bit of lined paper to fill the gap if last chunk was short?
                // No, simply finish.
                const SizedBox(height: 20),
                EditorBrandingFooter(secondaryColor: secondaryColor),
                const SizedBox(height: 40), // Bottom Padding
              ],
            ),
          ),
        ),
      );
    }

    return chunks;
  }

  /// Export-specific header - uses pure Text widgets to avoid
  /// TextField, DropdownButton, PopupMenuButton artifacts in exported images.
  Widget _buildHeader() {
    return Column(
      children: [
        // Title (always Text, never TextField)
        Text(
          title.isEmpty ? '无题' : title,
          style: GoogleFonts.notoSerifSc(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 15),
        // Meta (all Text, no interactive elements)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              dateString,
              style: EditorMetaSelector.metaStyle(secondaryColor),
            ),
            EditorMetaSelector.metaSeparator(secondaryColor),
            Text(
              weather.name.toUpperCase(),
              style: EditorMetaSelector.metaStyle(secondaryColor),
            ),
            EditorMetaSelector.metaSeparator(secondaryColor),
            Text(
              mood.name.toUpperCase(),
              style: EditorMetaSelector.metaStyle(secondaryColor),
            ),
          ],
        ),
      ],
    );
  }

  /// 导出 header 丝带（颜色来自主题 ribbonAccentColor）。
  Widget _buildRibbon() {
    final tc = AppTheme.getEditorTheme(theme);
    final Color accentColor = tc['ribbonAccentColor'];

    return CustomPaint(
      size: const Size(50, 90),
      painter: ExportRibbonPainter(color: accentColor),
    );
  }

  /// 单个正文分块的横线纸文本块（StrutStyle 固定行盒与线对齐）。
  Widget _buildChunkText(String text) {
    const double fontSize = 18.0;
    const double lineHeight = 32.0;
    final tc = AppTheme.getEditorTheme(theme);

    return CustomPaint(
      foregroundPainter: LinedPaperPainter(
        lineColor: hideLines ? Colors.transparent : tc['lineColor'],
        lineHeight: lineHeight,
      ),
      child: Container(
        // Ensure width constraint match
        width: double.infinity,
        padding: EdgeInsets.zero,
        child: Text(
          text,
          style: GoogleFonts.notoSerifSc(
            fontSize: fontSize,
            color: textColor,
            height: lineHeight / fontSize,
          ),
          strutStyle: StrutStyle(
            fontFamily: GoogleFonts.notoSerifSc().fontFamily,
            fontSize: fontSize,
            height: (lineHeight / fontSize),
            leading: 0,
            forceStrutHeight: true,
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    );
  }
}
