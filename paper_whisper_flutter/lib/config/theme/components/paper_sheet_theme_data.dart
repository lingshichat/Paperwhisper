import 'package:flutter/material.dart';

/// 纸张容器 主题数据
class PaperSheetThemeData {
  final Color paperColor;
  final Color accentColor;
  final Border border;
  final List<BoxShadow> shadows;
  final double borderRadius;
  final bool useGlassEffect;

  const PaperSheetThemeData({
    required this.paperColor,
    required this.accentColor,
    required this.border,
    required this.shadows,
    required this.borderRadius,
    required this.useGlassEffect,
  });

  Map<String, dynamic> toMap() => {
    'paperColor': paperColor,
    'accentColor': accentColor,
    'border': border,
    'shadows': shadows,
    'borderRadius': borderRadius,
    'useGlassEffect': useGlassEffect,
  };
}
