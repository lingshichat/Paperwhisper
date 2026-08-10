import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_registry.dart';

/// 主题系统门面：仅保留主题 ID 与真正强类型的全局装饰/ThemeData API。
///
/// 组件主题由消费方直接通过 `ThemeRegistry.get(theme).component` 访问。
class AppTheme {
  // ──────────── 主题 ID 常量 ────────────
  static const String themeDefault = 'default';
  static const String themeAmberLens = 'amber_lens';
  static const String themeAfterRain = 'after_rain';
  static const String themeTwilight = 'twilight';
  static const String themeGardenOfWords = 'garden_of_words';
  static const String themeMidnight = 'midnight';
  static const String themeSeaFlower = 'sea_flower';

  // ──────────── 静态阴影常量 ────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.3),
      offset: Offset(0, 5),
      blurRadius: 5,
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> paperShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.5),
      offset: Offset(0, 5),
      blurRadius: 10,
      spreadRadius: 0,
    ),
  ];

  // 组件主题不再经 Map 门面降级；直接使用 ThemeRegistry typed 数据。

  // ══════════════════════════════════════
  //  全局装饰方法
  // ══════════════════════════════════════

  /// 返回指定主题的背景动画叠加层 Widget 列表。
  static List<Widget> getBackgroundOverlays(String theme) =>
      ThemeRegistry.get(theme).backgroundOverlays;

  static SystemUiOverlayStyle getSystemUiOverlayStyle(String theme) =>
      ThemeRegistry.get(theme).systemUiOverlayStyle;

  static BoxDecoration getBackground(String theme) =>
      ThemeRegistry.get(theme).background;

  static BoxDecoration getSidebarBackground(String theme) =>
      ThemeRegistry.get(theme).sidebarBackground;

  // ══════════════════════════════════════
  //  颜色访问方法
  // ══════════════════════════════════════

  static Color getPaperColor(String theme) =>
      ThemeRegistry.get(theme).colors.paperColor;

  static Color getTextColor(String theme) =>
      ThemeRegistry.get(theme).colors.textPrimary;

  static Color getTextSecondaryColor(String theme) =>
      ThemeRegistry.get(theme).colors.textSecondary;

  static Color getAccentColor(String theme) =>
      ThemeRegistry.get(theme).colors.accent;

  // ══════════════════════════════════════
  //  ThemeData 生成
  // ══════════════════════════════════════

  static ThemeData getThemeData(String theme) {
    final t = ThemeRegistry.get(theme);
    final accentColor = t.colors.accent;

    return ThemeData(
      useMaterial3: true,
      brightness: t.colors.brightness,
      scaffoldBackgroundColor: t.colors.scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: t.colors.seedColor,
        brightness: t.colors.brightness,
        surface: t.colors.scaffoldBg,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: accentColor.withValues(alpha: 0.4),
        selectionHandleColor: accentColor,
      ),
      textTheme: GoogleFonts.notoSerifScTextTheme(
        t.colors.brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SkeuomorphicPageTransitionsBuilder(),
          TargetPlatform.iOS: _SkeuomorphicPageTransitionsBuilder(),
          TargetPlatform.windows: _SkeuomorphicPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// 自定义的拟物风转场动画
/// 特征：沉稳、有分量感。
class _SkeuomorphicPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SkeuomorphicPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }
}
