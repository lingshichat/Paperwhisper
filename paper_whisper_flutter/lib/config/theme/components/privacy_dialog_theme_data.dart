import 'package:flutter/material.dart';

/// 隐私协议弹窗 主题数据
class PrivacyDialogThemeData {
  final Color linkColor;
  final Color contentTextColor;
  final Color disclaimerTextColor;

  const PrivacyDialogThemeData({
    required this.linkColor,
    required this.contentTextColor,
    required this.disclaimerTextColor,
  });

  Map<String, dynamic> toMap() => {
    'linkColor': linkColor,
    'contentTextColor': contentTextColor,
    'disclaimerTextColor': disclaimerTextColor,
  };
}
