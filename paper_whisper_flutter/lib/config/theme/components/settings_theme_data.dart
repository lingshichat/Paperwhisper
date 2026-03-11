import 'package:flutter/material.dart';

/// 设置页面 主题数据
class SettingsThemeData {
  final BoxDecoration groupDecoration;
  final Color dividerColor;
  final Color textColor;
  final Color activeSwitchColor;
  final Color activeTrackColor;
  final Color titleColor;
  final Shadow titleShadow;
  final Color iconColor;
  final bool showPetalRain;
  final bool showStarrySky;
  final Color sheetTextColor;
  final Color sheetBackgroundColor;
  final Color sheetTitleColor;
  final Color sheetTapeColor;
  final List<BoxShadow> sheetShadows;
  final Border? sheetBorder;
  final bool sheetShowTape;
  final Color sheetInfoBackgroundColor;
  final Color sheetInfoBorderColor;
  final Color sheetInfoDividerColor;
  final Color optionSelectedBgColor;
  final Color optionSelectedTextColor;
  final BoxShadow? optionSelectedShadow;
  final Color optionUnselectedBgColor;
  final Color optionUnselectedTextColor;
  final Border? optionUnselectedBorder;
  final BoxShadow? optionUnselectedShadow;

  const SettingsThemeData({
    required this.groupDecoration,
    required this.dividerColor,
    required this.textColor,
    required this.activeSwitchColor,
    required this.activeTrackColor,
    required this.titleColor,
    required this.titleShadow,
    required this.iconColor,
    required this.showPetalRain,
    required this.showStarrySky,
    required this.sheetTextColor,
    required this.sheetBackgroundColor,
    required this.sheetTitleColor,
    required this.sheetTapeColor,
    required this.sheetShadows,
    this.sheetBorder,
    required this.sheetShowTape,
    required this.sheetInfoBackgroundColor,
    required this.sheetInfoBorderColor,
    required this.sheetInfoDividerColor,
    required this.optionSelectedBgColor,
    required this.optionSelectedTextColor,
    this.optionSelectedShadow,
    required this.optionUnselectedBgColor,
    required this.optionUnselectedTextColor,
    this.optionUnselectedBorder,
    this.optionUnselectedShadow,
  });

  Map<String, dynamic> toMap() => {
    'groupDecoration': groupDecoration,
    'dividerColor': dividerColor,
    'textColor': textColor,
    'activeSwitchColor': activeSwitchColor,
    'activeTrackColor': activeTrackColor,
    'titleColor': titleColor,
    'titleShadow': titleShadow,
    'iconColor': iconColor,
    'showPetalRain': showPetalRain,
    'showStarrySky': showStarrySky,
    'sheetTextColor': sheetTextColor,
    'sheetBackgroundColor': sheetBackgroundColor,
    'sheetTitleColor': sheetTitleColor,
    'sheetTapeColor': sheetTapeColor,
    'sheetShadows': sheetShadows,
    'sheetBorder': sheetBorder,
    'sheetShowTape': sheetShowTape,
    'sheetInfoBackgroundColor': sheetInfoBackgroundColor,
    'sheetInfoBorderColor': sheetInfoBorderColor,
    'sheetInfoDividerColor': sheetInfoDividerColor,
    'optionSelectedBgColor': optionSelectedBgColor,
    'optionSelectedTextColor': optionSelectedTextColor,
    'optionSelectedShadow': optionSelectedShadow,
    'optionUnselectedBgColor': optionUnselectedBgColor,
    'optionUnselectedTextColor': optionUnselectedTextColor,
    'optionUnselectedBorder': optionUnselectedBorder,
    'optionUnselectedShadow': optionUnselectedShadow,
  };
}
