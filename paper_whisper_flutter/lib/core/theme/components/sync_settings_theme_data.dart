import 'package:flutter/material.dart';

/// 同步设置 主题数据
class SyncSettingsThemeData {
  final Color titleColor;
  final Color textColor;
  final Color accentColor;
  final Color lockBtnColor;
  final Color switchTrackColor;
  final Color switchThumbColor;
  final Color switchActiveText;
  final Color switchInactiveText;
  final LinearGradient? primaryGradient;
  final Color? primaryBtnColor;
  final Color primaryShadowColor;
  final Color secondaryBtnColor;
  final Color secondaryBtnTextColor;
  final Color secondaryBorderColor;
  final Color tipsBgColor;
  final Color switchBgColor;
  final double slidingSwitchShadowOpacity;
  final double thumbShadowOpacity;

  const SyncSettingsThemeData({
    required this.titleColor,
    required this.textColor,
    required this.accentColor,
    required this.lockBtnColor,
    required this.switchTrackColor,
    required this.switchThumbColor,
    required this.switchActiveText,
    required this.switchInactiveText,
    this.primaryGradient,
    this.primaryBtnColor,
    required this.primaryShadowColor,
    required this.secondaryBtnColor,
    required this.secondaryBtnTextColor,
    required this.secondaryBorderColor,
    required this.tipsBgColor,
    required this.switchBgColor,
    required this.slidingSwitchShadowOpacity,
    required this.thumbShadowOpacity,
  });
}
