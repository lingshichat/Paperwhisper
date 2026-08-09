import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 品牌页脚：正文底部与长图导出 footer 共用视觉。
///
/// 纯展示组件，props 仅为颜色。
class EditorBrandingFooter extends StatelessWidget {
  /// 次要文本颜色（两行文字的不透明度渐变基于此色）。
  final Color secondaryColor;

  const EditorBrandingFooter({super.key, required this.secondaryColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'CREATED WITH',
            style: GoogleFonts.courierPrime(
              fontSize: 10,
              color: secondaryColor.withValues(alpha: 0.4),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '纸语 PaperWhisper',
            style: GoogleFonts.notoSerifSc(
              fontSize: 12,
              color: secondaryColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10), // Bottom padding
        ],
      ),
    );
  }
}
