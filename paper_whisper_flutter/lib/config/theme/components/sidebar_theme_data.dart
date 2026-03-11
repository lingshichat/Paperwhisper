import 'package:flutter/material.dart';

/// 侧边栏 主题数据
class SidebarThemeData {
  final BoxDecoration bgDecoration;
  final Color textColor;
  final Color activeTextColor;
  final Color subTextColor;
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
    required this.pillColor,
    required this.pillShadows,
    this.pillBorder,
    required this.buttonGradient,
    this.buttonShadow,
  });

  Map<String, dynamic> toMap() => {
    'bgDecoration': bgDecoration,
    'textColor': textColor,
    'activeTextColor': activeTextColor,
    'subTextColor': subTextColor,
    'pillColor': pillColor,
    'pillShadows': pillShadows,
    'pillBorder': pillBorder,
    'buttonGradient': buttonGradient,
    if (buttonShadow != null) 'buttonShadow': buttonShadow,
  };
}
