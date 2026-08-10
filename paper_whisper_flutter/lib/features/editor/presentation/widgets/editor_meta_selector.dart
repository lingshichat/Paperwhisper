import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/theme/theme_registry.dart';
import '../../../../models/diary_entry.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_date_picker.dart';

/// 编辑器元信息选择器：日期 / 天气 / 心情。
///
/// 保持原页面实现与文案：编辑态使用 SkeuomorphicDatePicker 弹窗、
/// DropdownButton（天气）与 PopupMenuButton（心情），只读态渲染纯文本。
/// 变更通过回调上报，由页面写入会话并触发重建；本组件不持有会话状态。
///
/// 日期选择弹窗属于组件自身的局部交互 UI（与 Dropdown/Menu 同类），
/// 不涉及业务导航。
class EditorMetaSelector extends StatelessWidget {
  /// 当前主题名（Dropdown/Menu 配色入口）。
  final String theme;

  /// 元信息文本颜色（原 _metaStyle 的 color，页面传入 secondaryColor）。
  final Color metaTextColor;

  /// 是否处于编辑态。
  final bool isEditing;

  /// 当前日期字符串（yyyy-MM-dd）。
  final String dateString;

  /// 当前天气。
  final WeatherType weather;

  /// 当前心情。
  final MoodType mood;

  /// 日期选择回调（页面写入会话并 setState）。
  final ValueChanged<DateTime> onDateChanged;

  /// 天气变更回调。
  final ValueChanged<WeatherType> onWeatherChanged;

  /// 心情变更回调。
  final ValueChanged<MoodType> onMoodChanged;

  const EditorMetaSelector({
    super.key,
    required this.theme,
    required this.metaTextColor,
    required this.isEditing,
    required this.dateString,
    required this.weather,
    required this.mood,
    required this.onDateChanged,
    required this.onWeatherChanged,
    required this.onMoodChanged,
  });

  /// 元信息文本样式（导出 header 复用，保持单一实现源）。
  static TextStyle metaStyle(Color color) =>
      GoogleFonts.courierPrime(fontSize: 14, color: color);

  /// 元信息分隔符（导出 header 复用，保持单一实现源）。
  static Widget metaSeparator(Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      '·',
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    ),
  );

  /// 单行 Row 布局所需的最小可用宽度阈值。
  ///
  /// 基于实际可用 maxWidth 判定：达到该宽度即保留原始单行 Row（Widget
  /// 树、间距、文案与交互完全不变）；低于该宽度改用 Wrap 分组换行，
  /// 避免 360 宽窄屏下元信息横向溢出。
  ///
  /// 数值依据：真实 Courier Prime（等宽 0.6em）下日期 + 两个分隔符 +
  /// 天气 + 心情的最宽组合约 266px，取 300 保留约 34px 余量；编辑器
  /// 内容区宽度 = 屏宽 - 纸张两侧 60px 内边距，360 宽屏为 240px，
  /// 480 宽屏为 360px，桌面常宽 580px，均落在正确分支。
  static const double _rowMinWidth = 300;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _rowMinWidth) {
          // 宽度充足：保留原单行 Row 布局，Widget 树与间距完全不变。
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildDateSelector(context),
              metaSeparator(metaTextColor),
              _buildWeatherSelector(),
              metaSeparator(metaTextColor),
              _buildMoodSelector(),
            ],
          );
        }

        // 窄内容区：Wrap 分组换行。日期单独成项，后续每个元信息与其
        // 前置分隔符作为一组，避免分隔符孤立在行尾；组内水平间距与
        // 垂直居中和原 Row 保持一致，控件类型与文案不变。
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 0,
          runSpacing: 4,
          children: [
            _buildDateSelector(context),
            _metaGroup(_buildWeatherSelector()),
            _metaGroup(_buildMoodSelector()),
          ],
        );
      },
    );
  }

  /// 日期选择器：SkeuomorphicDatePicker 弹窗与 async mounted 守卫保持原实现。
  Widget _buildDateSelector(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        DateTime initialDate;
        try {
          initialDate = DateTime.parse(dateString);
        } catch (_) {
          initialDate = DateTime.now();
        }

        // 选择结果经回调暂存：SkeuomorphicDatePicker 在选中后延迟 200ms
        // 自行关闭对话框，这里不主动 pop，保留原有交互时序。
        DateTime? selectedDate;
        await showDialog<void>(
          context: context,
          builder: (ctx) => SkeuomorphicDatePicker(
            initialDate: initialDate,
            onDateSelected: (date) => selectedDate = date,
          ),
        );
        final selected = selectedDate;
        if (selected == null) return; // 未选择（点遮罩/返回关闭）：不更新
        if (!context.mounted) return; // await 后 context 可能已失效
        onDateChanged(selected);
      },
      child: Text(dateString, style: metaStyle(metaTextColor)),
    );
  }

  /// 分隔符与其后的元信息作为一组（Wrap 换行时避免分隔符孤立在行尾）。
  Widget _metaGroup(Widget content) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [metaSeparator(metaTextColor), content],
    );
  }

  Widget _buildWeatherSelector() {
    if (!isEditing) {
      return Text(weather.name.toUpperCase(), style: metaStyle(metaTextColor));
    }

    final tc = ThemeRegistry.get(theme).editor;

    // Dropdown Menu Style
    final Color dropdownBg = tc.dropdownBg;
    final Color dropdownText = tc.dropdownText;

    return DropdownButton<WeatherType>(
      value: weather,
      underline: const SizedBox(),
      icon: const SizedBox(),
      dropdownColor: dropdownBg,
      isDense: true,
      alignment: AlignmentDirectional.center, // Center text in button
      // The text shown on the button (when closed)
      selectedItemBuilder: (BuildContext context) {
        return WeatherType.values.map((w) {
          return Container(
            alignment: Alignment.center,
            child: Text(w.name.toUpperCase(), style: metaStyle(metaTextColor)),
          );
        }).toList();
      },
      items: WeatherType.values
          .map(
            (w) => DropdownMenuItem(
              value: w,
              alignment: AlignmentDirectional.center,
              child: Text(
                w.name.toUpperCase(),
                style: GoogleFonts.courierPrime(
                  fontSize: 14,
                  color: dropdownText,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        if (val != null) onWeatherChanged(val);
      },
    );
  }

  Widget _buildMoodSelector() {
    if (!isEditing) {
      return Text(mood.name.toUpperCase(), style: metaStyle(metaTextColor));
    }

    final tc = ThemeRegistry.get(theme).editor;

    final Color menuBg = tc.dropdownBg;
    final Color menuText = tc.dropdownText;

    return PopupMenuButton<MoodType>(
      initialValue: mood,
      color: menuBg,
      padding: EdgeInsets.zero,
      tooltip: '',
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: onMoodChanged,
      itemBuilder: (context) => MoodType.values
          .map(
            (m) => PopupMenuItem(
              value: m,
              child: Text(
                m.name.toUpperCase(),
                style: GoogleFonts.courierPrime(fontSize: 14, color: menuText),
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          mood.name.toUpperCase(),
          style: metaStyle(metaTextColor).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
