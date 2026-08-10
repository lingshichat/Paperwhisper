import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';

/// 心情徽章环组件
/// 将心情分布以复古徽章环绕形式展示
class MoodBadgeRing extends StatelessWidget {
  final Map<String, int> moodData;
  final String theme;
  final double size;

  const MoodBadgeRing({
    super.key,
    required this.moodData,
    required this.theme,
    this.size = 240,
  });

  static const Map<String, IconData> _moodIcons = {
    'happy': Icons.sentiment_very_satisfied,
    'calm': Icons.sentiment_satisfied,
    'sad': Icons.sentiment_dissatisfied,
    'excited': Icons.sentiment_very_satisfied,
    'tired': Icons.sentiment_neutral,
  };

  static const Map<String, String> _moodLabels = {
    'happy': '开心',
    'calm': '平静',
    'sad': '难过',
    'excited': '兴奋',
    'tired': '疲惫',
  };

  @override
  Widget build(BuildContext context) {
    if (moodData.isEmpty) return const SizedBox.shrink();

    final colors = _getThemeColors();
    final total = moodData.values.reduce((a, b) => a + b);
    final sortedMoods = moodData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景装饰圆环
          Container(
            width: size * 0.85,
            height: size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.ringColor.withValues(alpha: 0.3),
                width: 2,
              ),
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  colors.centerColor.withValues(alpha: 0.1),
                  colors.centerColor.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          // 中心总数显示
          Container(
            width: size * 0.35,
            height: size * 0.35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.centerGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadowColor.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
              border: Border.all(
                color: colors.ringColor.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$total',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: size * 0.12,
                    fontWeight: FontWeight.bold,
                    color: colors.textColor,
                  ),
                ),
                Text(
                  '篇',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: size * 0.06,
                    color: colors.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // 环绕的心情徽章
          ...sortedMoods.asMap().entries.map((entry) {
            final index = entry.key;
            final mood = entry.value;
            final percentage = (mood.value / total * 100).toInt();
            final angle =
                (index * 2 * math.pi) / sortedMoods.length - math.pi / 2;
            final radius = size * 0.32;
            final x = radius * math.cos(angle);
            final y = radius * math.sin(angle);

            return Positioned(
              left: size / 2 + x - size * 0.08,
              top: size / 2 + y - size * 0.08,
              child: _MoodBadge(
                icon: _moodIcons[mood.key] ?? Icons.sentiment_satisfied,
                label: _moodLabels[mood.key] ?? mood.key,
                value: '${mood.value}',
                percentage: percentage,
                theme: theme,
                size: size * 0.16,
              ),
            );
          }),
        ],
      ),
    );
  }

  _MoodRingColors _getThemeColors() {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return _MoodRingColors(
          ringColor: const Color(0xFF81C784),
          centerColor: const Color(0xFF4CAF50),
          centerGradient: [const Color(0xFF37474F), const Color(0xFF263238)],
          textColor: const Color(0xFFECEFF1),
          shadowColor: Colors.black,
        );
      case AppTheme.themeTwilight:
        return _MoodRingColors(
          ringColor: const Color(0xFFFF9A6C),
          centerColor: const Color(0xFFFF5252),
          centerGradient: [const Color(0xFF352044), const Color(0xFF2E1C55)],
          textColor: const Color(0xFFE4E0EC),
          shadowColor: const Color(0xFFFF5252),
        );
      case AppTheme.themeAfterRain:
        return _MoodRingColors(
          ringColor: const Color(0xFF4FC3F7),
          centerColor: const Color(0xFF0288D1),
          centerGradient: [
            Colors.white.withValues(alpha: 0.9),
            const Color(0xFFF0F8FF),
          ],
          textColor: const Color(0xFF455A64),
          shadowColor: const Color(0xFF0288D1),
        );
      case AppTheme.themeSeaFlower:
        return _MoodRingColors(
          ringColor: const Color(0xFFF06292),
          centerColor: const Color(0xFFF8BBD0),
          centerGradient: [const Color(0xFFFFF5F7), const Color(0xFFFCE4EC)],
          textColor: const Color(0xFF880E4F),
          shadowColor: const Color(0xFFF06292),
        );
      case AppTheme.themeMidnight:
        return _MoodRingColors(
          ringColor: const Color(0xFF7986cb),
          centerColor: const Color(0xFF3949AB),
          centerGradient: [const Color(0xFF1a237e), const Color(0xFF161b22)],
          textColor: const Color(0xFFe6edf3),
          shadowColor: const Color(0xFF7986cb),
        );
      case AppTheme.themeAmberLens:
        return _MoodRingColors(
          ringColor: const Color(0xFFFF9800),
          centerColor: const Color(0xFFFFB74D),
          centerGradient: [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)],
          textColor: const Color(0xFFE0E0E0),
          shadowColor: Colors.black,
        );
      default: // Vintage
        return _MoodRingColors(
          ringColor: const Color(0xFFC0392B),
          centerColor: const Color(0xFFE74C3C),
          centerGradient: [const Color(0xFF5D4037), const Color(0xFF4E342E)],
          textColor: const Color(0xFFF4ECD8), // 改为浅色文字
          shadowColor: const Color(0xFF3E2723),
        );
    }
  }
}

class _MoodRingColors {
  final Color ringColor;
  final Color centerColor;
  final List<Color> centerGradient;
  final Color textColor;
  final Color shadowColor;

  _MoodRingColors({
    required this.ringColor,
    required this.centerColor,
    required this.centerGradient,
    required this.textColor,
    required this.shadowColor,
  });
}

/// 单个心情徽章
class _MoodBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int percentage;
  final String theme;
  final double size;

  const _MoodBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.percentage,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getBadgeColor();

    return Tooltip(
      message: '$label: $value篇 ($percentage%)',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.9),
              color.withValues(alpha: 0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }

  Color _getBadgeColor() {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return const Color(0xFF81C784);
      case AppTheme.themeTwilight:
        return const Color(0xFFFF5252);
      case AppTheme.themeAfterRain:
        return const Color(0xFF0288D1);
      case AppTheme.themeSeaFlower:
        return const Color(0xFFF06292);
      case AppTheme.themeMidnight:
        return const Color(0xFF7986cb);
      case AppTheme.themeAmberLens:
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFFC0392B);
    }
  }
}

/// 简化版心情分布 - 横向徽章列表
class MoodBadgeList extends StatelessWidget {
  final Map<String, int> moodData;
  final String theme;

  const MoodBadgeList({super.key, required this.moodData, required this.theme});

  static const Map<String, IconData> _moodIcons = {
    'happy': Icons.sentiment_very_satisfied,
    'calm': Icons.sentiment_satisfied,
    'sad': Icons.sentiment_dissatisfied,
    'excited': Icons.sentiment_very_satisfied,
    'tired': Icons.sentiment_neutral,
  };

  static const Map<String, String> _moodLabels = {
    'happy': '开心',
    'calm': '平静',
    'sad': '难过',
    'excited': '兴奋',
    'tired': '疲惫',
  };

  static const Map<String, Color> _moodColors = {
    'happy': Color(0xFFFFD93D),
    'calm': Color(0xFF6BCB77),
    'sad': Color(0xFF4D96FF),
    'excited': Color(0xFFFF6B6B),
    'tired': Color(0xFFB8B8B8),
  };

  @override
  Widget build(BuildContext context) {
    if (moodData.isEmpty) return const SizedBox.shrink();

    final total = moodData.values.reduce((a, b) => a + b);
    final sortedMoods = moodData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedMoods.map((entry) {
        final percentage = (entry.value / total * 100).toInt();
        final color = _moodColors[entry.key] ?? Colors.grey;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              // 徽章图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _moodIcons[entry.key] ?? Icons.sentiment_satisfied,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // 标签
              Text(
                _moodLabels[entry.key] ?? entry.key,
                style: GoogleFonts.notoSerifSc(
                  fontSize: 14,
                  color: _getTextColor(),
                ),
              ),
              const SizedBox(width: 8),
              // 进度条
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.value / sortedMoods.first.value,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 数值和百分比
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.value}',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _getTextColor(),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 11,
                      color: _getTextColor().withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getTextColor() {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return const Color(0xFFECEFF1);
      case AppTheme.themeTwilight:
        return const Color(0xFFE4E0EC);
      case AppTheme.themeAfterRain:
        return const Color(0xFF455A64);
      case AppTheme.themeSeaFlower:
        return const Color(0xFF880E4F);
      case AppTheme.themeMidnight:
        return const Color(0xFFe6edf3);
      case AppTheme.themeAmberLens:
        return const Color(0xFFE0E0E0);
      default:
        return const Color(0xFFF4ECD8); // Vintage主题使用浅色文字
    }
  }
}
