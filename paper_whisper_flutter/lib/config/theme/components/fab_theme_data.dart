import 'package:flutter/material.dart';

/// 悬浮按钮 主题数据
class FabThemeData {
  /// 纯色背景（与 [backgroundGradient] 二选一，构造时断言恰好一个非空）
  final Color? backgroundColor;

  /// 渐变背景（与 [backgroundColor] 二选一，构造时断言恰好一个非空）
  final Gradient? backgroundGradient;

  final BoxShadow shadow;
  final Color iconColor;
  final Border? border;

  const FabThemeData({
    this.backgroundColor,
    this.backgroundGradient,
    required this.shadow,
    required this.iconColor,
    this.border,
  }) : assert(
         (backgroundColor != null) != (backgroundGradient != null),
         'FabThemeData 必须且只能提供 backgroundColor 或 backgroundGradient 之一',
       );

  /// 兼容旧 Map 门面的背景值（Color 或 Gradient），与旧 `bg` 字段语义一致。
  Object get bg => backgroundColor ?? backgroundGradient!;

  Map<String, dynamic> toMap() => {
    'bg': bg,
    'shadow': shadow,
    'iconColor': iconColor,
    if (border != null) 'border': border,
  };
}
