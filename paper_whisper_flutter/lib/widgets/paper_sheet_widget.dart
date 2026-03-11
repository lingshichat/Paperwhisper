import 'dart:ui';
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
    this.showRibbon = true,
  });

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final theme = settings.currentTheme;
    final tc = AppTheme.getPaperSheetTheme(theme);

    // 从主题配置中读取样式
    final Color paperColor = tc['paperColor'] as Color;
    final Color accentColor = tc['accentColor'] as Color;
    final BoxBorder border = tc['border'] as BoxBorder;
    final List<BoxShadow> shadows = tc['shadows'] as List<BoxShadow>;
    final double borderRadius = tc['borderRadius'] as double;
    final bool useGlassEffect = tc['useGlassEffect'] as bool;

    Widget paperContent = Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 300),
      padding: padding,
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
        border: border,
      ),
      child: child,
    );

    // 毛玻璃效果
    if (useGlassEffect) {
      paperContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: paperContent,
        ),
      );
    }

    return Center(
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            paperContent,
            
            if (showRibbon)
              Positioned(
                right: 40,
                top: -8,
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
