import 'package:flutter/material.dart';

/// 月份分割线 主题数据
class MonthDividerThemeData {
  final Color? textColor;
  final Color? lineColor;
  final Color? paperColor;
  final List<BoxShadow>? shadows;

  const MonthDividerThemeData({
    this.textColor,
    this.lineColor,
    this.paperColor,
    this.shadows,
  });
}
