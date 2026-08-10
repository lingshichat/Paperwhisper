import 'package:flutter/material.dart';

/// 书籍目录 主题数据
class BookDirectoryThemeData {
  final Color? inkColor;
  final Color? paperColor;
  final Color? paperBorderColor;
  final List<BoxShadow>? paperShadow;

  const BookDirectoryThemeData({
    this.inkColor,
    this.paperColor,
    this.paperBorderColor,
    this.paperShadow,
  });
}
