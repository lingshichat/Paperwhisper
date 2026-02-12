import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

class MonthDivider extends StatelessWidget {
  final int year;
  final int month;
  final String title;
  final String theme;

  const MonthDivider({
    super.key,
    required this.year,
    required this.month,
    required this.title,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 根据主题定义颜色
    final themeConfig = AppTheme.getMonthDividerTheme(theme);
    
    Color textColor = themeConfig.isNotEmpty ? themeConfig['textColor'] : (theme == AppTheme.themeMidnight ? const Color(0xFFE8EAF6) : (theme == AppTheme.themeTwilight ? const Color(0xFFEF5350) : (theme == AppTheme.themeSeaFlower ? const Color(0xFFC2185B) : (theme == AppTheme.themeAmberLens ? const Color(0xFF3E2723) : const Color(0xFF5D4037)))));
    Color lineColor = themeConfig.isNotEmpty ? themeConfig['lineColor'] : (theme == AppTheme.themeMidnight ? const Color(0xFF5C6BC0) : (theme == AppTheme.themeTwilight ? const Color(0xFFEF5350).withValues(alpha: 0.4) : (theme == AppTheme.themeSeaFlower ? const Color(0xFFF48FB1) : (theme == AppTheme.themeAmberLens ? const Color(0xFFFFD54F) : const Color(0xFFA1887F)))));
    Color paperColor = themeConfig.isNotEmpty ? themeConfig['paperColor'] : (theme == AppTheme.themeMidnight ? const Color(0xFF283593) : (theme == AppTheme.themeTwilight ? const Color(0xFF352044).withValues(alpha: 0.6) : (theme == AppTheme.themeSeaFlower ? const Color(0xFFFCE4EC).withValues(alpha: 0.9) : (theme == AppTheme.themeAmberLens ? const Color(0xFFFFF8E1) : const Color(0xFFEFEBE9)))));
    List<BoxShadow> shadows = themeConfig.isNotEmpty ? themeConfig['shadows'] : (theme == AppTheme.themeMidnight ? [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 2))] : (theme == AppTheme.themeTwilight ? [BoxShadow(color: const Color(0xFFEF5350).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))] : (theme == AppTheme.themeSeaFlower ? [] : (theme == AppTheme.themeAmberLens ? [BoxShadow(color: const Color(0xFF3E2723).withValues(alpha: 0.1), blurRadius: 3, offset: const Offset(0, 1))] : [BoxShadow(color: const Color(0xFF5D4037).withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))]))));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row( // Use Row instead of Stack to prevent line crossing
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Line
          Expanded(
            child: Divider(
              color: lineColor.withOpacity(0.5),
              thickness: 1,
              indent: 20,
              endIndent: 12, // Space before bubble
            ),
          ),
          
          // Center Bubble (Paper Tag)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: paperColor,
              borderRadius: BorderRadius.circular(20), // Capsule shape
              border: Border.all(
                color: lineColor.withOpacity(0.6),
                width: 1,
              ),
              boxShadow: shadows,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year Label
                Text(
                  '$year',
                  style: GoogleFonts.merriweather(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 1,
                  height: 12,
                  color: lineColor,
                ),
                // Month Label
                Text(
                  title.isNotEmpty ? title : '$month月',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 1.2,
                  ),
                ),
                if (title.isNotEmpty && !title.contains('月')) ...[
                   const SizedBox(width: 4),
                   Text(
                    '($month月)',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ]
              ],
            ),
          ),

          // Right Line
          Expanded(
            child: Divider(
              color: lineColor.withOpacity(0.5),
              thickness: 1,
              indent: 12, // Space after bubble
              endIndent: 20,
            ),
          ),
        ],
      ),
    );
  }
}
