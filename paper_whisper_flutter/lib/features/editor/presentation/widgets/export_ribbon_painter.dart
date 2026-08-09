import 'package:flutter/material.dart';

/// 长图导出 header 的丝带装饰 Painter：带柔和阴影的斜角丝带。
///
/// 绘制路径与尺寸与原页面私有 `_ExportRibbonPainter` 完全一致，
/// 独立成文件供导出表面复用；颜色来自主题 ribbonAccentColor。
class ExportRibbonPainter extends CustomPainter {
  /// 丝带主体颜色。
  final Color color;

  ExportRibbonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double ribbonWidth = 40;
    const double ribbonHeight = 80;
    const double offsetX = 5;
    const double offsetY = 0;

    // Shadow
    final ribbonPath = Path();
    ribbonPath.moveTo(offsetX, offsetY);
    ribbonPath.lineTo(offsetX + ribbonWidth, offsetY);
    ribbonPath.lineTo(offsetX + ribbonWidth, offsetY + ribbonHeight);
    ribbonPath.lineTo(offsetX + ribbonWidth / 2, offsetY + ribbonHeight - 20);
    ribbonPath.lineTo(offsetX, offsetY + ribbonHeight);
    ribbonPath.close();

    canvas.save();
    canvas.translate(2, 5);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        4,
      ); // Lighter shadow for export
    canvas.drawPath(ribbonPath, shadowPaint);
    canvas.restore();

    // Body
    final ribbonPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final mainPath = Path();
    mainPath.moveTo(offsetX, offsetY);
    mainPath.lineTo(offsetX + ribbonWidth, offsetY);
    mainPath.lineTo(offsetX + ribbonWidth, offsetY + ribbonHeight);
    mainPath.lineTo(offsetX + ribbonWidth / 2, offsetY + ribbonHeight - 20);
    mainPath.lineTo(offsetX, offsetY + ribbonHeight);
    mainPath.close();
    canvas.drawPath(mainPath, ribbonPaint);
  }

  @override
  bool shouldRepaint(covariant ExportRibbonPainter oldDelegate) =>
      oldDelegate.color != color;
}
