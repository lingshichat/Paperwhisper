import 'package:flutter/material.dart';

/// 对话框输入框 主题数据
class DialogInputThemeData {
  final Color textColor;
  final Color hintColor;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color iconColor;
  final Color backgroundColor;
  final Color descriptionColor;

  const DialogInputThemeData({
    required this.textColor,
    required this.hintColor,
    required this.borderColor,
    required this.focusedBorderColor,
    required this.iconColor,
    required this.backgroundColor,
    required this.descriptionColor,
  });

  Map<String, Color> toMap() => {
    'textColor': textColor,
    'hintColor': hintColor,
    'borderColor': borderColor,
    'focusedBorderColor': focusedBorderColor,
    'iconColor': iconColor,
    'backgroundColor': backgroundColor,
    'descriptionColor': descriptionColor,
  };
}
