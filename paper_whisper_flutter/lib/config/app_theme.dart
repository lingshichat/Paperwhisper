import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/theme_registry.dart';

/// 主题系统门面 — 保持向后兼容，内部委托给 ThemeRegistry
///
/// 所有 get*Theme() 方法签名不变，消费方无需修改。
/// 新代码推荐直接使用 ThemeRegistry.get(theme).xxx 获取类型安全的访问。
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

  // ══════════════════════════════════════
  //  组件主题方法 (Map<String, dynamic>)
  // ══════════════════════════════════════

  // 1. FAB Theme
  static Map<String, dynamic> getFabTheme(String theme) =>
      ThemeRegistry.get(theme).fab.toMap();

  // 2. Sidebar Theme
  static Map<String, dynamic> getSidebarTheme(String theme) =>
      ThemeRegistry.get(theme).sidebar.toMap();

  // 3. Settings Theme
  static Map<String, dynamic> getSettingsTheme(String theme) =>
      ThemeRegistry.get(theme).settings.toMap();

  // 4. Editor Theme
  static Map<String, dynamic> getEditorTheme(String theme) =>
      ThemeRegistry.get(theme).editor.toMap();

  // 5. Diary Card Theme
  static Map<String, dynamic> getDiaryCardTheme(String theme) =>
      ThemeRegistry.get(theme).diaryCard.toMap();

  // 6. Moment Card Theme
  static Map<String, dynamic> getMomentCardTheme(String theme) =>
      ThemeRegistry.get(theme).momentCard.toMap();

  // 7. Book Directory Theme
  static Map<String, dynamic> getBookDirectoryTheme(String theme) =>
      ThemeRegistry.get(theme).bookDirectory.toMap();

  // 8. Moments Theme
  static Map<String, dynamic> getMomentsTheme(String theme) =>
      ThemeRegistry.get(theme).moments.toMap();

  // 9. Search Theme
  static Map<String, dynamic> getSearchTheme(String theme) =>
      ThemeRegistry.get(theme).search.toMap();

  // 10. Month Divider Theme
  static Map<String, dynamic> getMonthDividerTheme(String theme) =>
      ThemeRegistry.get(theme).monthDivider.toMap();

  // 11. Dialog Theme
  static Map<String, dynamic> getDialogTheme(String theme) =>
      ThemeRegistry.get(theme).dialog.toMap();

  // 12. Toast Theme
  static Map<String, dynamic> getToastTheme(String theme) =>
      ThemeRegistry.get(theme).toast.toMap();

  // 13. Lock Screen Theme
  static Map<String, dynamic> getLockScreenTheme(String theme) =>
      ThemeRegistry.get(theme).lockScreen.toMap();

  // 14. Statistics Theme
  static Map<String, dynamic> getStatisticsTheme(String theme) =>
      ThemeRegistry.get(theme).statistics.toMap();

  // 15. Trash Page Theme
  static Map<String, dynamic> getTrashPageTheme(String theme) =>
      ThemeRegistry.get(theme).trashPage.toMap();

  // 16. Sync Settings Theme
  static Map<String, dynamic> getSyncSettingsTheme(String theme) =>
      ThemeRegistry.get(theme).syncSettings.toMap();

  // 17. Moment Input Theme
  static Map<String, dynamic> getMomentInputTheme(String theme) =>
      ThemeRegistry.get(theme).momentInput.toMap();

  // 18. Moment Editor Theme
  static Map<String, dynamic> getMomentEditorTheme(String theme) =>
      ThemeRegistry.get(theme).momentEditor.toMap();

  // 19. Refresh Indicator Theme
  static Map<String, dynamic> getRefreshIndicatorTheme(String theme) =>
      ThemeRegistry.get(theme).refreshIndicator.toMap();

  // 20. Privacy Dialog Theme
  static Map<String, dynamic> getPrivacyDialogTheme(String theme) =>
      ThemeRegistry.get(theme).privacyDialog.toMap();

  // 21. Paper Sheet Theme
  static Map<String, dynamic> getPaperSheetTheme(String theme) =>
      ThemeRegistry.get(theme).paperSheet.toMap();

  // 22. Diary List Page Theme
  static Map<String, dynamic> getDiaryListPageTheme(String theme) =>
      ThemeRegistry.get(theme).diaryListPage.toMap();

  // 23. Moment Standard Card Theme
  static Map<String, dynamic> getMomentStandardCardTheme(String theme) =>
      ThemeRegistry.get(theme).momentStandardCard.toMap();

  // 24. Date Picker Theme
  static Map<String, dynamic> getDatePickerTheme(String theme) =>
      ThemeRegistry.get(theme).datePicker.toMap();

  // ══════════════════════════════════════
  //  Map<String, Color> 方法
  // ══════════════════════════════════════

  // 移动端顶栏颜色
  static Map<String, Color> getMobileHeaderColors(String theme) =>
      ThemeRegistry.get(theme).mobileHeader.toMap();

  // 对话框输入框主题
  static Map<String, Color> getDialogInputTheme(String theme) =>
      ThemeRegistry.get(theme).dialogInput.toMap();

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
        selectionColor: accentColor.withOpacity(0.4),
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
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
        ),
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      ),
    );
  }
}
