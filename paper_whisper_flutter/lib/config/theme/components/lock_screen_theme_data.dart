import 'package:flutter/material.dart';

/// 锁屏 主题数据
class LockScreenThemeData {
  final Color? displayBg;
  final Color? displayBorder;
  final Color? accentColor;
  final Color? keyBg;
  final Color? keyBorder;
  final Color? keyText;

  const LockScreenThemeData({
    this.displayBg,
    this.displayBorder,
    this.accentColor,
    this.keyBg,
    this.keyBorder,
    this.keyText,
  });

  Map<String, dynamic> toMap() => {
    if (displayBg != null) 'displayBg': displayBg,
    if (displayBorder != null) 'displayBorder': displayBorder,
    if (accentColor != null) 'accentColor': accentColor,
    if (keyBg != null) 'keyBg': keyBg,
    if (keyBorder != null) 'keyBorder': keyBorder,
    if (keyText != null) 'keyText': keyText,
  };
}
