import 'package:flutter/material.dart';

/// 统计徽章样式数据
class StatisticsBadgeStyleData {
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;

  const StatisticsBadgeStyleData({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
  });

  Map<String, dynamic> toMap() => {
    'backgroundColor': backgroundColor,
    'textColor': textColor,
    'borderColor': borderColor,
  };
}

/// 统计页面 主题数据
class StatisticsThemeData {
  final BoxDecoration cardBackground;
  final BoxShadow cardShadow;
  final Border cardBorder;
  final Color accentColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color chartColor;
  final StatisticsBadgeStyleData badgeStyle;

  const StatisticsThemeData({
    required this.cardBackground,
    required this.cardShadow,
    required this.cardBorder,
    required this.accentColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.chartColor,
    required this.badgeStyle,
  });

  Map<String, dynamic> toMap() => {
    'cardBackground': cardBackground,
    'cardShadow': cardShadow,
    'cardBorder': cardBorder,
    'accentColor': accentColor,
    'textColor': textColor,
    'secondaryTextColor': secondaryTextColor,
    'chartColor': chartColor,
    'badgeStyle': badgeStyle.toMap(),
  };
}
