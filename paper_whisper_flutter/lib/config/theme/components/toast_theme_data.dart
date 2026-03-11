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

  Map<String, dynamic> toMap() => {
    'bg': bg,
    'border': border,
    'icon': icon,
    'text': text,
  };
}

/// Toast 主题数据
class ToastThemeData {
  final ToastStyleData? success;
  final ToastStyleData? error;
  final ToastStyleData? warning;
  final ToastStyleData? info;

  const ToastThemeData({
    this.success,
    this.error,
    this.warning,
    this.info,
  });

  Map<String, dynamic> toMap() => {
    if (success != null) 'success': success!.toMap(),
    if (error != null) 'error': error!.toMap(),
    if (warning != null) 'warning': warning!.toMap(),
    if (info != null) 'info': info!.toMap(),
  };
}
