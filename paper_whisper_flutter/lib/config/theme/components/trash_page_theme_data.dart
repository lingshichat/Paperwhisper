import 'package:flutter/material.dart';

/// 回收站页面 主题数据
class TrashPageThemeData {
  final Color titleColor;
  final Color iconColor;
  final Color restoreColor;
  final Color dangerColor;
  final Color cardTitleColor;
  final Color cardDateColor;
  final BoxDecoration cardDecoration;

  const TrashPageThemeData({
    required this.titleColor,
    required this.iconColor,
    required this.restoreColor,
    required this.dangerColor,
    required this.cardTitleColor,
    required this.cardDateColor,
    required this.cardDecoration,
  });

  Map<String, dynamic> toMap() => {
    'titleColor': titleColor,
    'iconColor': iconColor,
    'restoreColor': restoreColor,
    'dangerColor': dangerColor,
    'cardTitleColor': cardTitleColor,
    'cardDateColor': cardDateColor,
    'cardDecoration': cardDecoration,
  };
}
