/// 设置页泛型选择弹层。
///
/// 组合 S2a 的 [SettingsBottomSheetFrame] + [SettingsOptionTile]：
/// - options 为 typed label/value，由页面决定消费方（主题 / 启动页）；
/// - [closeOnSelect] 控制选择后是否自动关闭（主题面板保持打开实时预览，
///   启动页选择后立即关闭，与原 settings_page 行为逐字一致）；
/// - 样式由页面从 themeConfig 适配为 [SettingsChoiceSheetStyle] 明确 props，
///   不迁移 AppTheme Map，组件不持有 BuildContext 跨 async。
library;

import 'package:flutter/material.dart';

import 'settings_primitives.dart';

/// 选择弹层的展示样式（颜色 / 阴影 / 边框，由页面显式注入）。
class SettingsChoiceSheetStyle {
  const SettingsChoiceSheetStyle({
    required this.backgroundColor,
    required this.titleColor,
    required this.tapeColor,
    required this.shadows,
    required this.border,
    required this.showTape,
    required this.selectedBackgroundColor,
    required this.unselectedBackgroundColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    this.selectedShadow,
    this.unselectedShadow,
    this.unselectedBorder,
  });

  final Color backgroundColor;
  final Color titleColor;
  final Color tapeColor;
  final List<BoxShadow> shadows;
  final BoxBorder? border;
  final bool showTape;
  final Color selectedBackgroundColor;
  final Color unselectedBackgroundColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final BoxShadow? selectedShadow;
  final BoxShadow? unselectedShadow;
  final Border? unselectedBorder;
}

/// 单个选项：展示 label + typed value。
class SettingsChoiceOption<T> {
  const SettingsChoiceOption({required this.label, required this.value});

  final String label;
  final T value;
}

/// 泛型单选弹层：底部弹层框架 + 选项块列表。
class SettingsChoiceSheet<T> extends StatelessWidget {
  const SettingsChoiceSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.style,
    this.closeOnSelect = true,
  });

  final String title;
  final List<SettingsChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final SettingsChoiceSheetStyle style;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) {
    return SettingsBottomSheetFrame(
      title: title,
      titleColor: style.titleColor,
      backgroundColor: style.backgroundColor,
      tapeColor: style.tapeColor,
      shadows: style.shadows,
      border: style.border,
      showTape: style.showTape,
      children: [
        for (final option in options)
          SettingsOptionTile(
            label: option.label,
            isSelected: option.value == selected,
            onTap: () {
              onSelected(option.value);
              if (closeOnSelect) {
                Navigator.pop(context);
              }
            },
            selectedBackgroundColor: style.selectedBackgroundColor,
            unselectedBackgroundColor: style.unselectedBackgroundColor,
            selectedTextColor: style.selectedTextColor,
            unselectedTextColor: style.unselectedTextColor,
            selectedShadow: style.selectedShadow,
            unselectedShadow: style.unselectedShadow,
            unselectedBorder: style.unselectedBorder,
          ),
      ],
    );
  }
}
