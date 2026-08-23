import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 随心记顶栏可点击日期标题：`yyyy年M月` + 下拉箭头 + 「随心记」。
class MomentsDateTitle extends StatelessWidget {
  const MomentsDateTitle({
    super.key,
    required this.selectedDate,
    required this.textColor,
    required this.iconColor,
    required this.expanded,
    required this.onTap,
  });

  final DateTime selectedDate;
  final Color textColor;
  final Color iconColor;
  final bool expanded;
  final VoidCallback onTap;

  static const double _arrowExtent = 24;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('moments_date_title'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: expanded ? '收起日历' : '打开日历',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 左侧占位与箭头同宽，让「yyyy年M月」相对顶栏几何中心居中。
                  const SizedBox(width: _arrowExtent),
                  Text(
                    '${selectedDate.year}年${selectedDate.month}月',
                    style: GoogleFonts.notoSerifSc(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(
                    width: _arrowExtent,
                    child: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.arrow_drop_down,
                        color: iconColor,
                        size: _arrowExtent,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '随心记',
                style: GoogleFonts.notoSerifSc(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
