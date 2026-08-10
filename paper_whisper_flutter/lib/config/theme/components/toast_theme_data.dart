import 'package:flutter/material.dart';

/// Toast 单项样式数据
class ToastStyleData {
  final Color bg;
  final Color border;
  final Color icon;
  final Color text;

  const ToastStyleData({
    required this.bg,
    required this.border,
    required this.icon,
    required this.text,
  });
}

/// Toast 主题数据
class ToastThemeData {
  final ToastStyleData? success;
  final ToastStyleData? error;
  final ToastStyleData? warning;
  final ToastStyleData? info;

  const ToastThemeData({this.success, this.error, this.warning, this.info});
}
