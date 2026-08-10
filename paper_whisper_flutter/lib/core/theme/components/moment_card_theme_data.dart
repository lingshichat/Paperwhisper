import 'package:flutter/material.dart';

/// 瞬间卡片 主题数据
class MomentCardThemeData {
  final Color cardColor;
  final Color textColor;
  final Color metaColor;
  final Color iconColor;
  final List<BoxShadow> cardShadows;
  final Border? cardBorder;
  final bool useGlassEffect;
  final double cardBlurSigma;
  final Color imageStackColor;
  final Color imageStackBorderColor;
  final BoxShadow imageStackShadow;
  final Color imageSurfaceColor;
  final BoxShadow imageSurfaceShadow;
  final Color indicatorActiveColor;
  final Color indicatorInactiveColor;
  final Color watermarkDividerColor;
  final Color audioSurfaceColor;
  final Color audioSurfaceBorderColor;
  final Color audioButtonColor;
  final Color audioButtonIconColor;
  final BoxShadow audioButtonShadow;
  final Color audioProgressBgColor;
  final Color audioProgressColor;
  final Color audioDurationColor;
  final Color deleteIconColor;

  const MomentCardThemeData({
    required this.cardColor,
    required this.textColor,
    required this.metaColor,
    required this.iconColor,
    required this.cardShadows,
    this.cardBorder,
    required this.useGlassEffect,
    required this.cardBlurSigma,
    required this.imageStackColor,
    required this.imageStackBorderColor,
    required this.imageStackShadow,
    required this.imageSurfaceColor,
    required this.imageSurfaceShadow,
    required this.indicatorActiveColor,
    required this.indicatorInactiveColor,
    required this.watermarkDividerColor,
    required this.audioSurfaceColor,
    required this.audioSurfaceBorderColor,
    required this.audioButtonColor,
    required this.audioButtonIconColor,
    required this.audioButtonShadow,
    required this.audioProgressBgColor,
    required this.audioProgressColor,
    required this.audioDurationColor,
    required this.deleteIconColor,
  });
}
