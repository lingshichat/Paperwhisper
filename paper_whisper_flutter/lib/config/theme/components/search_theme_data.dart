import 'package:flutter/material.dart';

/// 搜索 主题数据
class SearchThemeData {
  final Color? bgColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? iconColor;
  final Border? border;

  const SearchThemeData({
    this.bgColor,
    this.textColor,
    this.hintColor,
    this.iconColor,
    this.border,
  });

  Map<String, dynamic> toMap() => {
    if (bgColor != null) 'bgColor': bgColor,
    if (textColor != null) 'textColor': textColor,
    if (hintColor != null) 'hintColor': hintColor,
    if (iconColor != null) 'iconColor': iconColor,
    if (border != null) 'border': border,
  };
}
