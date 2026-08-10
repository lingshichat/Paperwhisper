import 'package:flutter/material.dart';

/// 日记列表页面 主题数据
class DiaryListPageThemeData {
  final Color drawerScrimColor;
  final List<BoxShadow> headerBoxShadow;
  final bool headerApplyBlur;
  final Color emptyStateIconColor;
  final Color emptyStateTextColor;
  final Color emptyStateLinkColor;
  final Color updateDialogSecondaryColor;

  const DiaryListPageThemeData({
    required this.drawerScrimColor,
    required this.headerBoxShadow,
    required this.headerApplyBlur,
    required this.emptyStateIconColor,
    required this.emptyStateTextColor,
    required this.emptyStateLinkColor,
    required this.updateDialogSecondaryColor,
  });
}
