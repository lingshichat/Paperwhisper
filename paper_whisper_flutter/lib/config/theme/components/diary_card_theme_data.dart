import 'package:flutter/material.dart';

/// 日记卡片 主题数据
class DiaryCardThemeData {
  final Color bgColor;
  final Color titleColor;
  final Color contentColor;
  final Color dateColor;
  final Color iconColor;
  final Color dashedLineColor;
  final List<BoxShadow> shadows;
  final List<BoxShadow> hoverShadows;
  final Border? border;
  final Color? hoverBorderColor;
  final FontWeight dateWeight;
  final bool glassEffect;
  final Color glassColor;
  final double blurSigma;
  final double borderRadius;
  final double hoverTranslateY;
  final double hoverScale;
  final bool showStarWatermark;
  final bool showFlowerWatermark;
  final bool usePaperContainer;

  const DiaryCardThemeData({
    required this.bgColor,
    required this.titleColor,
    required this.contentColor,
    required this.dateColor,
    required this.iconColor,
    required this.dashedLineColor,
    required this.shadows,
    required this.hoverShadows,
    this.border,
    this.hoverBorderColor,
    required this.dateWeight,
    required this.glassEffect,
    required this.glassColor,
    required this.blurSigma,
    required this.borderRadius,
    required this.hoverTranslateY,
    required this.hoverScale,
    required this.showStarWatermark,
    required this.showFlowerWatermark,
    required this.usePaperContainer,
  });
}
