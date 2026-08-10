import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paper_whisper_flutter/config/app_theme.dart';
import 'package:paper_whisper_flutter/config/theme/components/statistics_theme_data.dart';
import 'package:paper_whisper_flutter/config/theme/theme_registry.dart';

/// 拟物化统计卡片
/// 根据主题展示不同的质感效果
class SkeuomorphicStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final VoidCallback? onTap;
  final String theme;

  const SkeuomorphicStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final themeConfig = ThemeRegistry.get(theme).statistics;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _buildCardDecoration(themeConfig),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标徽章
            _buildIconBadge(themeConfig),
            const SizedBox(height: 12),
            // 数值
            Text(
              value,
              style: GoogleFonts.notoSerifSc(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: themeConfig.textColor,
              ),
            ),
            const SizedBox(height: 4),
            // 标签
            Text(
              label,
              style: GoogleFonts.notoSerifSc(
                fontSize: 13,
                color: themeConfig.secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡片装饰
  BoxDecoration _buildCardDecoration(StatisticsThemeData themeConfig) {
    final baseDecoration = themeConfig.cardBackground;

    // 根据主题添加特殊效果
    if (theme == AppTheme.themeDefault) {
      // Vintage: 纸张纹理 + 深度阴影
      return BoxDecoration(
        color: baseDecoration.color,
        borderRadius: baseDecoration.borderRadius,
        border: baseDecoration.border,
        boxShadow: [
          // 主阴影
          BoxShadow(
            color: const Color(0xFF3E2723).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
          // 环境光
          BoxShadow(
            color: const Color(0xFF3E2723).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      );
    } else if (theme == AppTheme.themeGardenOfWords) {
      // Garden: 玻璃拟态
      return BoxDecoration(
        color: const Color(0xFF263238).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      );
    } else if (theme == AppTheme.themeAfterRain) {
      // AfterRain: 湿润玻璃
      return BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0288D1).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      );
    } else if (theme == AppTheme.themeTwilight) {
      // Twilight: 发光效果
      return BoxDecoration(
        color: const Color(0xFF352044).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF9A6C).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5252).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 0),
            spreadRadius: -2,
          ),
        ],
      );
    }

    return baseDecoration;
  }

  /// 构建图标徽章
  Widget _buildIconBadge(StatisticsThemeData themeConfig) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _buildBadgeDecoration(),
      child: Icon(icon, size: 24, color: accentColor),
    );
  }

  /// 构建徽章装饰
  BoxDecoration _buildBadgeDecoration() {
    if (theme == AppTheme.themeDefault) {
      // Vintage: 金属质感徽章
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            const Color(0xFFF4ECD8),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      );
    } else if (theme == AppTheme.themeGardenOfWords) {
      // Garden: 水滴效果
      return BoxDecoration(
        color: const Color(0xFF81C784).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF81C784).withValues(alpha: 0.4),
          width: 1,
        ),
      );
    } else if (theme == AppTheme.themeAfterRain) {
      // AfterRain: 水晶效果
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4FC3F7).withValues(alpha: 0.3),
            const Color(0xFF0288D1).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4FC3F7).withValues(alpha: 0.5),
          width: 1,
        ),
      );
    } else if (theme == AppTheme.themeTwilight) {
      // Twilight: 发光徽章
      return BoxDecoration(
        color: const Color(0xFFFF5252).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5252).withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      );
    }

    // 默认
    return BoxDecoration(
      color: accentColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
    );
  }
}

/// 拟物化卷轴横幅（连续写作天数）
class SkeuomorphicScrollBanner extends StatelessWidget {
  final int days;
  final String message;
  final String theme;

  const SkeuomorphicScrollBanner({
    super.key,
    required this.days,
    required this.message,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final themeConfig = ThemeRegistry.get(theme).statistics;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: _buildScrollDecoration(themeConfig),
      child: Row(
        children: [
          // 左侧卷轴轴头
          _buildScrollEnd(themeConfig, isLeft: true),
          const SizedBox(width: 16),
          // 中间内容
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: days > 0
                          ? const Color(0xFFFF6B35)
                          : themeConfig.secondaryTextColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$days',
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: themeConfig.textColor,
                        shadows: days > 0
                            ? [
                                Shadow(
                                  color: const Color(
                                    0xFFFF6B35,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '天',
                      style: GoogleFonts.notoSerifSc(
                        fontSize: 18,
                        color: themeConfig.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 14,
                    color: themeConfig.secondaryTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 右侧卷轴轴头
          _buildScrollEnd(themeConfig, isLeft: false),
        ],
      ),
    );
  }

  BoxDecoration _buildScrollDecoration(StatisticsThemeData themeConfig) {
    if (theme == AppTheme.themeDefault) {
      // Vintage: 羊皮纸卷轴
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF4ECD8),
            const Color(0xFFE8DCC4),
            const Color(0xFFF4ECD8),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF5D4037).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
        ],
      );
    }

    // 其他主题使用玻璃效果
    return BoxDecoration(
      color:
          themeConfig.cardBackground.color?.withValues(alpha: 0.8) ??
          Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      border: themeConfig.cardBorder,
      boxShadow: [themeConfig.cardShadow],
    );
  }

  Widget _buildScrollEnd(
    StatisticsThemeData themeConfig, {
    required bool isLeft,
  }) {
    if (theme == AppTheme.themeDefault) {
      // Vintage: 木质卷轴轴头
      return Container(
        width: 12,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              const Color(0xFF5D4037),
              const Color(0xFF8D6E63),
              const Color(0xFF5D4037),
            ],
          ),
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(6) : Radius.zero,
            right: isLeft ? Radius.zero : const Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: isLeft ? const Offset(-2, 0) : const Offset(2, 0),
            ),
          ],
        ),
      );
    }

    // 其他主题使用装饰性边框
    return Container(
      width: 4,
      height: 60,
      decoration: BoxDecoration(
        color: themeConfig.accentColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
