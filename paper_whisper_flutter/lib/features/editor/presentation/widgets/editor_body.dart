import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_theme.dart';
import '../../../../models/diary_entry.dart';
import '../../../../widgets/paper_sheet_widget.dart';
import 'editor_branding_footer.dart';
import 'editor_meta_selector.dart';
import 'lined_paper_painter.dart';

/// 编辑器主体：标题、元信息、正文编辑/预览与字数统计。
///
/// 纯展示组件（props 驱动）：持有来自会话的三个 TextEditingController、
/// 编辑元数据与主题配色，内部按内容长度选择性能模式（Sliver 逐行渲染）
/// 或标准模式（单列滚动），200 字 preview 截断由 [isPreviewMode] 驱动。
///
/// 不持有 Provider/业务编排：主题、compatibilityMode（[hideLines]）与
/// 各类变更回调均由页面注入；FocusNode 由页面持有并传入。
/// 性能模式下只读行点击进入编辑的 setState 与焦点请求也由页面注入
/// （[onTapToEdit]），本组件只负责渲染与回调透传。
class EditorBody extends StatelessWidget {
  /// 标题输入控制器。
  final TextEditingController titleController;

  /// 正文输入控制器（完整内容）。
  final TextEditingController contentController;

  /// 200 字截断预览控制器（首屏优化）。
  final TextEditingController previewController;

  /// 是否处于编辑态（标题/正文渲染 TextField 或纯文本）。
  final bool isEditing;

  /// 是否处于首屏预览模式（显示截断预览文本，极大减少渲染压力）。
  final bool isPreviewMode;

  /// 正文编辑焦点节点（性能模式点击行后请求焦点）。
  final FocusNode focusNode;

  /// 当前主题名。
  final String theme;

  /// 正文文本颜色。
  final Color textColor;

  /// 次要文本颜色（字数统计/品牌页脚/元信息）。
  final Color secondaryColor;

  /// 是否隐藏横线（SettingsProvider.compatibilityMode，页面注入）。
  final bool hideLines;

  /// 当前日期字符串（yyyy-MM-dd，透传给元信息选择器）。
  final String dateString;

  /// 当前天气（透传给元信息选择器）。
  final WeatherType weather;

  /// 当前心情（透传给元信息选择器）。
  final MoodType mood;

  /// 日期选择回调（页面写入会话并 setState）。
  final ValueChanged<DateTime> onDateChanged;

  /// 天气变更回调（页面写入会话并 setState）。
  final ValueChanged<WeatherType> onWeatherChanged;

  /// 心情变更回调（页面写入会话并 setState）。
  final ValueChanged<MoodType> onMoodChanged;

  /// 性能模式只读行点击进入编辑回调（页面 setState + 延迟请求焦点）。
  final VoidCallback onTapToEdit;

  const EditorBody({
    super.key,
    required this.titleController,
    required this.contentController,
    required this.previewController,
    required this.isEditing,
    required this.isPreviewMode,
    required this.focusNode,
    required this.theme,
    required this.textColor,
    required this.secondaryColor,
    required this.hideLines,
    required this.dateString,
    required this.weather,
    required this.mood,
    required this.onDateChanged,
    required this.onWeatherChanged,
    required this.onMoodChanged,
    required this.onTapToEdit,
  });

  @override
  Widget build(BuildContext context) {
    // Threshold for switching to performance mode
    // ~200 lines or ~5000 chars
    bool usePerformanceMode = contentController.text.length > 3000;
    final tc = AppTheme.getEditorTheme(theme);

    if (usePerformanceMode) {
      // --- Performance Mode (Slivers) ---
      // Fully expanded, no outer padding
      return RepaintBoundary(
        // key: _sheetKey, // Removed to avoid conflict with export view
        child: PaperSheetWidget(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildHeader(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 2,
                      color: (tc['cursorColor'] as Color).withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              _buildContentSliver(),
              SliverToBoxAdapter(child: const SizedBox(height: 40)),
              SliverToBoxAdapter(child: _buildWordCount()),
              // Word Count
              SliverToBoxAdapter(child: const SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: EditorBrandingFooter(secondaryColor: secondaryColor),
              ),
              // Sufficient bottom padding inside the scroll view
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ),
      );
    } else {
      // --- Standard Mode (SingleChildScrollView) ---
      // Uses shrinkWrap to float as a card when short, fills screen when long
      return RepaintBoundary(
        // key: _sheetKey, // Removed to avoid conflict with export view
        child: PaperSheetWidget(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                Center(
                  child: Container(
                    width: 60,
                    height: 2,
                    color: (tc['cursorColor'] as Color).withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 30),
                // Standard Content Area (TextField/Text)
                _buildContentArea(),
                const SizedBox(height: 30),
                _buildWordCount(), // Word Count
                const SizedBox(height: 10),
                EditorBrandingFooter(secondaryColor: secondaryColor),
                // Bottom padding inside scroll view
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      );
    }
  }

  /// 标题 + 元信息选择器（编辑态 TextField / 只读态 Text）。
  Widget _buildHeader() {
    final tc = AppTheme.getEditorTheme(theme);
    return Column(
      children: [
        if (isEditing)
          TextField(
            controller: titleController,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            cursorColor: tc['cursorColor'],
            decoration: InputDecoration(
              hintText: '在此输入标题...',
              hintStyle: TextStyle(color: tc['hintColor']),
              border: InputBorder.none,
            ),
          )
        else
          Text(
            titleController.text.isEmpty ? '无题' : titleController.text,
            style: GoogleFonts.notoSerifSc(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: textColor, // Use dynamic theme color
            ),
            textAlign: TextAlign.center,
          ),

        const SizedBox(height: 15),
        // Meta
        EditorMetaSelector(
          theme: theme,
          metaTextColor: secondaryColor,
          isEditing: isEditing,
          dateString: dateString,
          weather: weather,
          mood: mood,
          onDateChanged: onDateChanged,
          onWeatherChanged: onWeatherChanged,
          onMoodChanged: onMoodChanged,
        ),
      ],
    );
  }

  /// 标准模式正文区域（横线纸 + 编辑 TextField / 只读 Text）。
  Widget _buildContentArea() {
    const double fontSize = 18.0;
    const double lineHeight = 32.0;

    // Strict alignment: height = 32/18 = 1.7777...
    final tc = AppTheme.getEditorTheme(theme);
    return CustomPaint(
      foregroundPainter: LinedPaperPainter(
        lineColor: hideLines ? Colors.transparent : tc['lineColor'],
        lineHeight: lineHeight,
      ),
      child: Container(
        padding: const EdgeInsets.only(top: 0), // Adjust if needed
        constraints: const BoxConstraints(minHeight: 300),
        child: isEditing
            ? TextField(
                controller: isPreviewMode
                    ? previewController
                    : contentController, // Fix 1
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
                cursorColor: tc['cursorColor'],
                cursorHeight: 22,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.zero, // Important: keep zero to match Strut
                  isCollapsed: true,
                  isDense: true,
                  counterText: "",
                ),
                maxLines: null,
              )
            : Text(
                isPreviewMode
                    ? previewController.text
                    : contentController.text, // Fix 2: Critical for preview lag
                style: GoogleFonts.notoSerifSc(
                  fontSize: fontSize,
                  color: textColor,
                  height: lineHeight / fontSize,
                ),
                // Ensure display text matches input style exactly
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

  /// 字数统计（空内容不渲染）。
  Widget _buildWordCount() {
    if (contentController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 1,
            width: 20,
            color: secondaryColor.withValues(alpha: 0.2),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '${contentController.text.length} 字',
              style: GoogleFonts.notoSerifSc(
                fontSize: 12,
                color: secondaryColor.withValues(alpha: 0.4),
                letterSpacing: 1,
              ),
            ),
          ),
          Container(
            height: 1,
            width: 20,
            color: secondaryColor.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  /// 品牌页脚：由共享的 [EditorBrandingFooter] 提供（正文底部与导出
  /// footer 共用），此处不再重复实现。

  /// 性能模式正文：逐行 SliverList（编辑 TextField / 只读逐行 Text）。
  Widget _buildContentSliver() {
    if (isEditing) {
      return SliverToBoxAdapter(child: _buildEditorField());
    } else {
      // Split content into lines for performance
      // 在预览模式下，使用截断的文本，这会生成非常少的 lines，极大提升首屏渲染性能
      final text = isPreviewMode
          ? previewController.text
          : contentController.text;
      final lines = text.split('\n');
      if (lines.isEmpty) lines.add('');

      const double fontSize = 18.0;
      const double lineHeight = 32.0;

      final style = GoogleFonts.notoSerifSc(
        fontSize: fontSize,
        height: lineHeight / fontSize,
        color: textColor,
      );

      final tc = AppTheme.getEditorTheme(theme);

      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final line = lines[index];

          return CustomPaint(
            foregroundPainter: LinedPaperPainter(
              lineColor: hideLines ? Colors.transparent : tc['lineColor'],
              lineHeight: lineHeight,
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: lineHeight),
              padding: const EdgeInsets.symmetric(
                horizontal: 0,
              ), // Already padded by PaperSheetWidget
              alignment: Alignment.centerLeft, // Ensure text starts from left
              child: GestureDetector(
                onTap: onTapToEdit,
                child: Text(
                  line.isEmpty ? ' ' : line,
                  style: style,
                  strutStyle: StrutStyle(
                    fontFamily: GoogleFonts.notoSerifSc().fontFamily,
                    fontSize: fontSize,
                    height: lineHeight / fontSize,
                    forceStrutHeight: true,
                  ),
                ),
              ),
            ),
          );
        }, childCount: lines.length),
      );
    }
  }

  /// 性能模式编辑态正文（横线纸 + 绑定 FocusNode 的 TextField）。
  Widget _buildEditorField() {
    const double fontSize = 18.0;
    const double lineHeight = 32.0;

    final tc = AppTheme.getEditorTheme(theme);
    return CustomPaint(
      foregroundPainter: LinedPaperPainter(
        lineColor: hideLines ? Colors.transparent : tc['lineColor'],
        lineHeight: lineHeight,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: TextField(
          controller: isPreviewMode
              ? previewController
              : contentController, // 预览模式使用截断文本
          focusNode: focusNode,
          maxLines: null,
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
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isCollapsed: true,
            isDense: true,
          ),
          cursorColor: textColor,
        ),
      ),
    );
  }
}
