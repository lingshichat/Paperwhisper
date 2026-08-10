import 'package:flutter/material.dart';

/// 侧边栏 主题数据
class SidebarThemeData {
  final BoxDecoration bgDecoration;
  final Color textColor;
  final Color activeTextColor;
  final Color subTextColor;
  final Color hitokotoBackgroundColor;
  final Color hitokotoBorderColor;
  final Color dividerColor;
  final Color pillColor;
  final List<BoxShadow> pillShadows;
  final Border? pillBorder;
  final LinearGradient buttonGradient;
  final BoxShadow? buttonShadow;

  const SidebarThemeData({
    required this.bgDecoration,
    required this.textColor,
    required this.activeTextColor,
    required this.subTextColor,
    required this.hitokotoBackgroundColor,
    required this.hitokotoBorderColor,
    required this.dividerColor,
    required this.pillColor,
    required this.pillShadows,
    this.pillBorder,
    required this.buttonGradient,
    this.buttonShadow,
  });
}
