import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class PaperSheetWidget extends StatelessWidget {
  final Widget child;
  final double width;
  final EdgeInsets padding;
  final bool showRibbon;

  const PaperSheetWidget({
    super.key,
    required this.child,
    this.width = 700,
    this.padding = const EdgeInsets.all(0),
    this.showRibbon = true, // Default to true for legacy feel
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final paperColor = AppTheme.getPaperColor(theme);
    
    // Legacy Red Accent for Sticky Tape / Ribbon
    final accentColor = const Color(0xFFC0392B); 

    return Center(
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.none, // Allow ribbon to overflow top
          children: [
            Container(
              width: width,
              constraints: const BoxConstraints(minHeight: 800),
              padding: padding,
              decoration: BoxDecoration(
                color: paperColor,
                borderRadius: BorderRadius.circular(2), // Slight radius
                boxShadow: AppTheme.paperShadow, // Defined in AppTheme
                // Red Top Bar (Border)
                border: const Border(
                  top: BorderSide(color: Color(0xFFC0392B), width: 8),
                ),
              ),
              child: child,
            ),
            
            if (showRibbon)
              Positioned(
                right: 40,
                top: -8, // Slight overlap
                child: _buildRibbon(accentColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbon(Color color) {
    return SizedBox(
      width: 50, // 稍微加宽以容纳阴影
      height: 90, // 稍微加高以容纳阴影
      child: CustomPaint(
        painter: _RibbonPainter(color: color),
      ),
    );
  }
}

/// 书签绘制器：统一绘制阴影、本体和虚线装饰
class _RibbonPainter extends CustomPainter {
  final Color color;
  
  _RibbonPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    // 书签尺寸和位置（居中，留出阴影空间）
    const double ribbonWidth = 40;
    const double ribbonHeight = 80;
    const double offsetX = 5; // 左侧留出空间
    const double offsetY = 0;
    
    // 创建书签路径（燕尾形）
    final ribbonPath = Path();
    ribbonPath.moveTo(offsetX, offsetY);
    ribbonPath.lineTo(offsetX + ribbonWidth, offsetY);
    ribbonPath.lineTo(offsetX + ribbonWidth, offsetY + ribbonHeight);
    ribbonPath.lineTo(offsetX + ribbonWidth / 2, offsetY + ribbonHeight - 20);
    ribbonPath.lineTo(offsetX, offsetY + ribbonHeight);
    ribbonPath.close();
    
    // 1. 绘制阴影
    canvas.save();
    canvas.translate(2, 5); // 阴影偏移
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(ribbonPath, shadowPaint);
    canvas.restore();
    
    // 2. 绘制书签本体
    final ribbonPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // 需要重新创建路径（因为 translate 只影响 canvas）
    final mainPath = Path();
    mainPath.moveTo(offsetX, offsetY);
    mainPath.lineTo(offsetX + ribbonWidth, offsetY);
    mainPath.lineTo(offsetX + ribbonWidth, offsetY + ribbonHeight);
    mainPath.lineTo(offsetX + ribbonWidth / 2, offsetY + ribbonHeight - 20);
    mainPath.lineTo(offsetX, offsetY + ribbonHeight);
    mainPath.close();
    canvas.drawPath(mainPath, ribbonPaint);
    
    // 3. 绘制两侧虚线装饰
    final stitchPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    const dashHeight = 4.0;
    const dashGap = 3.0;
    const stitchMargin = 5.0;
    const stitchTop = 0.0;
    const stitchBottom = ribbonHeight - 25; // 留出燕尾区域
    
    // 左侧虚线
    double y = stitchTop;
    while (y < stitchBottom) {
      canvas.drawLine(
        Offset(offsetX + stitchMargin, y),
        Offset(offsetX + stitchMargin, y + dashHeight),
        stitchPaint,
      );
      y += dashHeight + dashGap;
    }
    
    // 右侧虚线
    y = stitchTop;
    while (y < stitchBottom) {
      canvas.drawLine(
        Offset(offsetX + ribbonWidth - stitchMargin, y),
        Offset(offsetX + ribbonWidth - stitchMargin, y + dashHeight),
        stitchPaint,
      );
      y += dashHeight + dashGap;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
