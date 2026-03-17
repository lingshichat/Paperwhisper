import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';

/// 拟物风格 Toast 工具类
/// 提供成功、错误、信息等样式的通知提示
/// 自动适配当前主题颜色
class SkeuomorphicToast {
  /// 显示成功提示
  static void success(BuildContext context, String message) {
    if (!context.mounted) return;
    final colors = _getThemeColors(context, _ToastType.success);
    _show(context, message: message, icon: Icons.check_circle_outline, colors: colors);
  }

  /// 显示错误提示
  static void error(BuildContext context, String message) {
    if (!context.mounted) return;
    final colors = _getThemeColors(context, _ToastType.error);
    _show(context, message: message, icon: Icons.error_outline, colors: colors, duration: const Duration(seconds: 4));
  }

  /// 显示信息提示
  static void info(BuildContext context, String message, {SnackBarAction? action}) {
    if (!context.mounted) return;
    final colors = _getThemeColors(context, _ToastType.info);
    _show(context, message: message, icon: Icons.info_outline, colors: colors, action: action);
  }

  /// 显示警告提示
  static void warning(BuildContext context, String message, {SnackBarAction? action}) {
    if (!context.mounted) return;
    final colors = _getThemeColors(context, _ToastType.warning);
    _show(context, message: message, icon: Icons.warning_amber_outlined, colors: colors, duration: const Duration(seconds: 4), action: action);
  }

  /// 获取当前主题对应的颜色配置
  static _ToastColors _getThemeColors(BuildContext context, _ToastType type) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final themeConfig = AppTheme.getToastTheme(theme);

    if (themeConfig.isNotEmpty) {
      String key;
      switch (type) {
        case _ToastType.success: key = 'success'; break;
        case _ToastType.error: key = 'error'; break;
        case _ToastType.warning: key = 'warning'; break;
        case _ToastType.info: key = 'info'; break;
      }
      final colorMap = themeConfig[key];
      return _ToastColors(
        background: colorMap['bg'],
        border: colorMap['border'],
        icon: colorMap['icon'],
        text: colorMap['text'],
      );
    }

    // 根据主题返回不同的配色方案
    switch (theme) {
      case AppTheme.themeMidnight:
        return _getMidnightColors(type);
      case AppTheme.themeSeaFlower:
        return _getSeaFlowerColors(type);
      default:
        return _getVintageColors(type);
    }
  }

  /// 时光旧物主题配色
  static _ToastColors _getVintageColors(_ToastType type) {
    const bgColor = Color(0xFFF4ECD8); // 复古纸张色
    const textColor = Color(0xFF3E2723);
    
    switch (type) {
      case _ToastType.success:
        return _ToastColors(
          background: bgColor,
          border: const Color(0xFF5D4037),
          icon: const Color(0xFF4CAF50),
          text: textColor,
        );
      case _ToastType.error:
        return _ToastColors(
          background: const Color(0xFFFFF3E0),
          border: const Color(0xFFD84315),
          icon: const Color(0xFFD84315),
          text: textColor,
        );
      case _ToastType.warning:
        return _ToastColors(
          background: const Color(0xFFFFF8E1),
          border: const Color(0xFFFF8F00),
          icon: const Color(0xFFFF8F00),
          text: textColor,
        );
      case _ToastType.info:
        return _ToastColors(
          background: bgColor,
          border: const Color(0xFF8D6E63),
          icon: const Color(0xFF5D4037),
          text: textColor,
        );
    }
  }

  /// 午夜星尘主题配色
  static _ToastColors _getMidnightColors(_ToastType type) {
    const bgColor = Color(0xFF161b22); // 深色背景
    const textColor = Color(0xFFe6edf3);
    
    switch (type) {
      case _ToastType.success:
        return _ToastColors(
          background: bgColor,
          border: const Color(0xFF238636),
          icon: const Color(0xFF3fb950),
          text: textColor,
        );
      case _ToastType.error:
        return _ToastColors(
          background: const Color(0xFF21262d),
          border: const Color(0xFFf85149),
          icon: const Color(0xFFf85149),
          text: textColor,
        );
      case _ToastType.warning:
        return _ToastColors(
          background: const Color(0xFF21262d),
          border: const Color(0xFFd29922),
          icon: const Color(0xFFd29922),
          text: textColor,
        );
      case _ToastType.info:
        return _ToastColors(
          background: bgColor,
          border: const Color(0xFF30363d),
          icon: const Color(0xFF8b949e),
          text: textColor,
        );
    }
  }

  /// 海底花海主题配色
  static _ToastColors _getSeaFlowerColors(_ToastType type) {
    const bgColor = Color(0xFFFCE4EC); // 淡粉背景
    const textColor = Color(0xFF880E4F);
    
    switch (type) {
      case _ToastType.success:
        return _ToastColors(
          background: bgColor,
          border: const Color(0xFFAD1457),
          icon: const Color(0xFF4CAF50),
          text: textColor,
        );
      case _ToastType.error:
        return _ToastColors(
          background: const Color(0xFFFFEBEE),
          border: const Color(0xFFD32F2F),
          icon: const Color(0xFFD32F2F),
          text: textColor,
        );
      case _ToastType.warning:
        return _ToastColors(
          background: const Color(0xFFFFF3E0),
          border: const Color(0xFFFF6F00),
          icon: const Color(0xFFFF6F00),
          text: textColor,
        );
      case _ToastType.info:
        return _ToastColors(
          background: bgColor,
          border: const Color(0xFFC2185B),
          icon: const Color(0xFFC2185B),
          text: textColor,
        );
    }
  }

  /// 内部显示方法
  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required _ToastColors colors,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    // 移除之前的 SnackBar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // 图标
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.icon.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colors.icon, size: 22),
            ),
            const SizedBox(width: 14),
            // 文本
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.notoSerifSc(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.text,
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: colors.background,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border, width: 1.5),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: duration,
      dismissDirection: DismissDirection.horizontal,
      action: action, // Pass action here
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

/// Toast 类型
enum _ToastType { success, error, info, warning }

/// Toast 颜色配置
class _ToastColors {
  final Color background;
  final Color border;
  final Color icon;
  final Color text;

  const _ToastColors({
    required this.background,
    required this.border,
    required this.icon,
    required this.text,
  });
}
