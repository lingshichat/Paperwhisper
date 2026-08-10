import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';

/// 随心记空态（纯展示，props 驱动）。
///
/// 原 `moments_page._buildEmptyStateForDate`：今天展示「无限可能」，
/// 其余日期展示「这天没有留下记录」。主题 Map 访问与原来一致。
class MomentsEmptyState extends StatelessWidget {
  const MomentsEmptyState({super.key, required this.date, required this.theme});

  /// 目标日期（决定展示今天/历史空态文案与图标）。
  final DateTime date;

  /// 主题名（页面从 SettingsProvider 传入）。
  final String theme;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final themeConfig = ThemeRegistry.get(theme).moments;
    final Color iconColor = themeConfig.emptyStateIconColor;
    final Color textColor = themeConfig.emptyStateTextColor;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isToday ? Icons.lightbulb_outline : Icons.edit_note,
            size: 80,
            color: iconColor,
          ),
          const SizedBox(height: 24),
          Text(
            isToday ? "这一天不仅是空白，更是无限可能" : "这天没有留下记录",
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: 16,
              color: textColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
