import 'package:flutter/material.dart';

/// 横线纸背景 Painter：按固定行高绘制水平线，配合 StrutStyle 固定
/// 行盒高度，使文字恰好落在线上。
///
/// 编辑器正文（编辑/预览/性能模式逐行）与长图导出分块共用。
class LinedPaperPainter extends CustomPainter {
  /// 线条颜色（compatibilityMode 下传透明以隐藏横线）。
  final Color lineColor;

  /// 行高（与正文 TextStyle.height * fontSize 严格对齐）。
  final double lineHeight;

  LinedPaperPainter({required this.lineColor, required this.lineHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    // Start drawing lines from top
    // We want the text to sit ON the line. Text height is fixed via StrutStyle.
    // Draw lines exactly at multiples of lineHeight (bottom of each line box)
    for (
      double y = lineHeight;
      y <= size.height + lineHeight;
      y += lineHeight
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
