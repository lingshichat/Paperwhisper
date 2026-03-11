import 'package:flutter/material.dart';

/// 下拉刷新指示器 主题数据
class AppRefreshIndicatorThemeData {
  final Color bookColor;
  final Color pageColor;
  final Color textColor;

  const AppRefreshIndicatorThemeData({
    required this.bookColor,
    required this.pageColor,
    required this.textColor,
  });

  Map<String, dynamic> toMap() => {
    'bookColor': bookColor,
    'pageColor': pageColor,
    'textColor': textColor,
  };
}
