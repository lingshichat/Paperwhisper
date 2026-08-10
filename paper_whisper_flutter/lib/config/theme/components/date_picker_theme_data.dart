import 'package:flutter/material.dart';

/// 日期选择器 主题数据
class AppDatePickerThemeData {
  final Color dialogBg;
  final Color headerBg;
  final Color headerText;
  final Color bodyText;
  final Color accentColor;
  final Color weekDayColor;
  final Border border;
  final List<BoxShadow> shadows;

  const AppDatePickerThemeData({
    required this.dialogBg,
    required this.headerBg,
    required this.headerText,
    required this.bodyText,
    required this.accentColor,
    required this.weekDayColor,
    required this.border,
    required this.shadows,
  });
}
