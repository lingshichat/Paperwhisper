import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 桌面端随心记页头（纯展示，props 驱动）。
///
/// 原 `moments_page._buildDesktopHeader`：月份标题 + 当日图片数徽标 +
/// 生成日记按钮。颜色由页面从主题 Map 取出后传入。
class MomentsDesktopHeader extends StatelessWidget {
  const MomentsDesktopHeader({
    super.key,
    required this.selectedDate,
    required this.imageCount,
    required this.textColor,
    required this.iconColor,
    required this.onGenerate,
  });

  /// 当前选中日期（用于「2026年3月」标题）。
  final DateTime selectedDate;

  /// 当日图片总数（> 0 时展示徽标）。
  final int imageCount;

  final Color textColor;
  final Color iconColor;

  /// 生成今日日记回调。
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), // Subtle bg for header
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Leading (empty or back?) - No drawer icon needed
          const SizedBox(
            width: 48,
          ), // Spacer to center title if needed, or just let it adjust

          Expanded(
            child: Column(
              children: [
                Text(
                  "${selectedDate.year}年${selectedDate.month}月",
                  style: GoogleFonts.notoSerifSc(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "随心记",
                      style: GoogleFonts.notoSerifSc(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (imageCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image, size: 10, color: iconColor),
                            const SizedBox(width: 2),
                            Text(
                              '$imageCount',
                              style: GoogleFonts.notoSerifSc(
                                color: iconColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          IconButton(
            key: const ValueKey('desktop_generate_btn'),
            icon: Icon(Icons.description_outlined, color: iconColor),
            tooltip: '生成今日日记',
            onPressed: onGenerate,
          ),
        ],
      ),
    );
  }
}
