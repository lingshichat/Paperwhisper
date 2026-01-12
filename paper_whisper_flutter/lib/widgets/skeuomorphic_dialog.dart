import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';

/// 拟物风格弹窗 - 支持多主题适配
class SkeuomorphicDialog extends StatelessWidget {
  final String title;
  final Widget? content;
  final List<Widget>? actions;
  final bool showTape;
  final IconData? headerIcon;

  const SkeuomorphicDialog({
    super.key,
    required this.title,
    this.content,
    this.actions,
    this.showTape = true,
    this.headerIcon,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final colors = _getThemeColors(theme);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 1. 纸张背景
          Container(
            width: 320,
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
            decoration: BoxDecoration(
              color: colors.paper,
              borderRadius: BorderRadius.circular(2),
              border: colors.border != null 
                  ? Border.all(color: colors.border!, width: 1)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  offset: const Offset(0, 10),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 头部图标
                if (headerIcon != null) ...[
                  Icon(headerIcon, size: 48, color: colors.icon),
                  const SizedBox(height: 20),
                ],

                // 标题
                Text(
                  title,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.title,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // 内容
                if (content != null) ...[
                  const SizedBox(height: 15),
                  Flexible(
                    child: SingleChildScrollView(
                      child: DefaultTextStyle(
                        style: GoogleFonts.notoSerifSc(
                          fontSize: 15,
                          color: colors.text,
                          height: 1.6,
                        ),
                        child: content!,
                      ),
                    ),
                  ),
                ],

                // 操作按钮
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Row(
                    children: actions!.map((action) {
                      return Expanded(child: action);
                    }).expand((widget) => [widget, const SizedBox(width: 10)])
                     .take(actions!.length * 2 - 1).toList(),
                  ),
                ],
              ],
            ),
          ),
          
          // 2. 胶带装饰
          if (showTape)
            Positioned(
              top: -15,
              child: Container(
                transform: Matrix4.rotationZ(-0.05),
                width: 120,
                height: 35,
                decoration: BoxDecoration(
                  color: colors.tape,
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 根据主题获取颜色配置
  _DialogColors _getThemeColors(String theme) {
    switch (theme) {
      case AppTheme.themeMidnight:
        return _DialogColors(
          paper: const Color(0xFF161b22),
          title: const Color(0xFFe6edf3),
          text: const Color(0xFFc9d1d9),
          icon: const Color(0xFF7986cb),
          tape: const Color(0xFF30363d),
          shadow: const Color.fromRGBO(0, 0, 0, 0.6),
          border: const Color(0xFF30363d),
        );
      case AppTheme.themeSeaFlower:
        return _DialogColors(
          paper: const Color(0xFFFCE4EC),
          title: const Color(0xFF880E4F),
          text: const Color(0xFFAD1457),
          icon: const Color(0xFFF06292),
          tape: const Color(0xFFF8BBD0),
          shadow: const Color.fromRGBO(173, 20, 87, 0.25),
          border: const Color(0xFFF48FB1),
        );
      default: // 时光旧物
        return _DialogColors(
          paper: const Color(0xFFF4ECD8),
          title: const Color(0xFF2d241f),
          text: const Color(0xFF5D4037),
          icon: const Color(0xFF5D4037),
          tape: const Color(0xD9E0E0E0),
          shadow: const Color.fromRGBO(0, 0, 0, 0.4),
          border: null,
        );
    }
  }
}

/// 弹窗颜色配置
class _DialogColors {
  final Color paper;
  final Color title;
  final Color text;
  final Color icon;
  final Color tape;
  final Color shadow;
  final Color? border;

  const _DialogColors({
    required this.paper,
    required this.title,
    required this.text,
    required this.icon,
    required this.tape,
    required this.shadow,
    this.border,
  });
}

/// 拟物风格按钮 - 支持多主题适配
class SkeuomorphicDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const SkeuomorphicDialogButton({
    super.key, 
    required this.label, 
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final colors = _getButtonColors(theme);

    if (!isPrimary) {
      return TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: colors.secondary,
        ),
        child: Text(
          label,
          style: GoogleFonts.notoSerifSc(fontWeight: FontWeight.bold),
        ),
      );
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: colors.primaryShadow,
              offset: const Offset(0, 4),
              blurRadius: 8,
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.notoSerifSc(
            color: colors.primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 根据主题获取按钮颜色
  _ButtonColors _getButtonColors(String theme) {
    switch (theme) {
      case AppTheme.themeMidnight:
        return _ButtonColors(
          primary: const Color(0xFF5C6BC0),
          primaryText: const Color(0xFFe6edf3),
          primaryShadow: const Color.fromRGBO(92, 107, 192, 0.4),
          secondary: const Color(0xFF8b949e),
        );
      case AppTheme.themeSeaFlower:
        return _ButtonColors(
          primary: const Color(0xFFEC407A),
          primaryText: Colors.white,
          primaryShadow: const Color.fromRGBO(236, 64, 122, 0.4),
          secondary: const Color(0xFFAD1457),
        );
      default: // 时光旧物
        return _ButtonColors(
          primary: const Color(0xFF5D4037),
          primaryText: const Color(0xFFF4ECD8),
          primaryShadow: const Color.fromRGBO(93, 64, 55, 0.4),
          secondary: const Color(0xFF8D6E63),
        );
    }
  }
}

/// 按钮颜色配置
class _ButtonColors {
  final Color primary;
  final Color primaryText;
  final Color primaryShadow;
  final Color secondary;

  const _ButtonColors({
    required this.primary,
    required this.primaryText,
    required this.primaryShadow,
    required this.secondary,
  });
}
