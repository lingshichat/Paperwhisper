import 'package:flutter/material.dart';

/// 悬浮按钮 主题数据
class FabThemeData {
  /// 背景（可以是 Color 或 Gradient）
  final dynamic bg;
  final BoxShadow shadow;
  final Color iconColor;
  final Border? border;

  const FabThemeData({
    required this.bg,
    required this.shadow,
    required this.iconColor,
    this.border,
  });

  Map<String, dynamic> toMap() => {
    'bg': bg,
    'shadow': shadow,
    'iconColor': iconColor,
    if (border != null) 'border': border,
  };
}
