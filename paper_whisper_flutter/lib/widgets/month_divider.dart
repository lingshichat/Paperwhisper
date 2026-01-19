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
    Color textColor;
    Color lineColor;
    Color paperColor;
    List<BoxShadow> shadows;

    switch (theme) {
      case AppTheme.themeMidnight:
        textColor = const Color(0xFFE8EAF6);
        lineColor = const Color(0xFF5C6BC0);
        paperColor = const Color(0xFF283593); // 深蓝纸条
        shadows = [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ];
        break;
      case AppTheme.themeSeaFlower:
        textColor = const Color(0xFFC2185B); // 洋红色文字
        lineColor = const Color(0xFFF48FB1); // 粉色线条
        paperColor = const Color(0xFFFCE4EC).withOpacity(0.9); // 浅粉色背景
        shadows = []; // 海底花海较为扁平柔和
        break;
      case AppTheme.themeAmberLens:
        textColor = const Color(0xFF3E2723);
        lineColor = const Color(0xFFFFD54F);
        paperColor = const Color(0xFFFFF8E1);
        shadows = [
          BoxShadow(
            color: const Color(0xFF3E2723).withOpacity(0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ];
        break;
      default: // Vintage / Default
        textColor = const Color(0xFF5D4037);
        lineColor = const Color(0xFFA1887F);
        paperColor = const Color(0xFFEFEBE9); // 浅灰褐色
        shadows = [
          BoxShadow(
            color: const Color(0xFF5D4037).withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ];
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 2. 背景线 (模拟书页缝隙或装饰线)
          Divider(
            color: lineColor.withOpacity(0.5),
            thickness: 1,
            indent: 20,
            endIndent: 20,
          ),
          
          // 3. 中间标签 (拟物化纸条)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: paperColor,
              borderRadius: BorderRadius.circular(20), // 胶囊形状
              border: Border.all(
                color: lineColor.withOpacity(0.6),
                width: 1,
              ),
              boxShadow: shadows,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 年份小标
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
                // 月份大标
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
        ],
      ),
    );
  }
}
