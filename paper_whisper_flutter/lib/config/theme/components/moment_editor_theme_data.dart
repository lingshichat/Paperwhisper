import 'package:flutter/material.dart';

/// 瞬间编辑器 主题数据
class MomentEditorThemeData {
  final Color bgColor;
  final Color appBarTextColor;
  final Color appBarIconColor;
  final Color inputBg;
  final Color inputTextColor;
  final Color hintColor;
  final Color dropdownBg;
  final Color dropdownIconColor;
  final Color dropdownMenuBg;
  final Color dropdownItemColor;
  final Color photoEmptyColor;
  final Color photoIconColor;

  const MomentEditorThemeData({
    required this.bgColor,
    required this.appBarTextColor,
    required this.appBarIconColor,
    required this.inputBg,
    required this.inputTextColor,
    required this.hintColor,
    required this.dropdownBg,
    required this.dropdownIconColor,
    required this.dropdownMenuBg,
    required this.dropdownItemColor,
    required this.photoEmptyColor,
    required this.photoIconColor,
  });

  Map<String, dynamic> toMap() => {
    'bgColor': bgColor,
    'appBarTextColor': appBarTextColor,
    'appBarIconColor': appBarIconColor,
    'inputBg': inputBg,
    'inputTextColor': inputTextColor,
    'hintColor': hintColor,
    'dropdownBg': dropdownBg,
    'dropdownIconColor': dropdownIconColor,
    'dropdownMenuBg': dropdownMenuBg,
    'dropdownItemColor': dropdownItemColor,
    'photoEmptyColor': photoEmptyColor,
    'photoIconColor': photoIconColor,
  };
}
