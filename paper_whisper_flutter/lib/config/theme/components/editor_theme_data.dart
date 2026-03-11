import 'package:flutter/material.dart';

/// 编辑器 主题数据
class EditorThemeData {
  final Color appBarBg;
  final Color iconColor;
  final Color cursorColor;
  final Color lineColor;
  final Color dividerColor;
  final Border? appBarBorder;
  final bool applyBlur;
  final Color saveButtonBg;
  final Color saveButtonTextColor;
  final Color saveButtonCheckColor;
  final Color dropdownBg;
  final Color dropdownText;
  final Color exportPaperColor;
  final Color exportBorderColor;
  final Color ribbonAccentColor;
  final Color hintColor;

  const EditorThemeData({
    required this.appBarBg,
    required this.iconColor,
    required this.cursorColor,
    required this.lineColor,
    required this.dividerColor,
    this.appBarBorder,
    required this.applyBlur,
    required this.saveButtonBg,
    required this.saveButtonTextColor,
    required this.saveButtonCheckColor,
    required this.dropdownBg,
    required this.dropdownText,
    required this.exportPaperColor,
    required this.exportBorderColor,
    required this.ribbonAccentColor,
    required this.hintColor,
  });

  Map<String, dynamic> toMap() => {
    'appBarBg': appBarBg,
    'iconColor': iconColor,
    'cursorColor': cursorColor,
    'lineColor': lineColor,
    'dividerColor': dividerColor,
    'appBarBorder': appBarBorder,
    'applyBlur': applyBlur,
    'saveButtonBg': saveButtonBg,
    'saveButtonTextColor': saveButtonTextColor,
    'saveButtonCheckColor': saveButtonCheckColor,
    'dropdownBg': dropdownBg,
    'dropdownText': dropdownText,
    'exportPaperColor': exportPaperColor,
    'exportBorderColor': exportBorderColor,
    'ribbonAccentColor': ribbonAccentColor,
    'hintColor': hintColor,
  };
}
