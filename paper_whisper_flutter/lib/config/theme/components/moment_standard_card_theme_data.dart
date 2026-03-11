import 'package:flutter/material.dart';

/// 瞬间标准卡片（导出分享） 主题数据
class MomentStandardCardThemeData {
  final Color cardBg;
  final Color textColor;
  final Color metaColor;

  const MomentStandardCardThemeData({
    required this.cardBg,
    required this.textColor,
    required this.metaColor,
  });

  Map<String, dynamic> toMap() => {
    'cardBg': cardBg,
    'textColor': textColor,
    'metaColor': metaColor,
  };
}
