import 'package:flutter/material.dart';

/// 对话框 主题数据
class AppDialogThemeData {
  final Color? paper;
  final Color? title;
  final Color? text;
  final Color? icon;
  final Color? tape;
  final Color? shadow;
  final Color? border;
  final Color? primaryBtn;
  final Color? primaryBtnText;
  final Color? secondaryBtn;

  const AppDialogThemeData({
    this.paper,
    this.title,
    this.text,
    this.icon,
    this.tape,
    this.shadow,
    this.border,
    this.primaryBtn,
    this.primaryBtnText,
    this.secondaryBtn,
  });
}
