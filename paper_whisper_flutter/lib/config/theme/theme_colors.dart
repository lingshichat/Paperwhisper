import 'package:flutter/material.dart';

/// 核心调色板 — 每个主题的基础颜色定义
class ThemeColors {
  final Color paperColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color bgCenter;
  final Color bgEdge;
  final Brightness brightness;
  final Color scaffoldBg;
  final Color seedColor;

  const ThemeColors({
    required this.paperColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.bgCenter,
    required this.bgEdge,
    required this.brightness,
    required this.scaffoldBg,
    required this.seedColor,
  });
}
