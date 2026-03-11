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

  Map<String, dynamic> toMap() => {
    if (inkColor != null) 'inkColor': inkColor,
    if (paperColor != null) 'paperColor': paperColor,
    if (paperBorderColor != null) 'paperBorderColor': paperBorderColor,
    if (paperShadow != null) 'paperShadow': paperShadow,
  };
}
