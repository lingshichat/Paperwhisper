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
}
