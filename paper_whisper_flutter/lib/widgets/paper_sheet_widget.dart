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
    final bool isSeaFlower = theme == AppTheme.themeSeaFlower;
    
    // Theme-based colors
    final Color paperColor = isSeaFlower 
        ? Colors.white.withValues(alpha: 0.55) // Sea Flower: Glassy white
        : AppTheme.getPaperColor(theme);
        
    final Color accentColor;
    if (isSeaFlower) {
      accentColor = const Color(0xFFEC407A); // Pink Ribbon
    } else if (theme == AppTheme.themeMidnight) {
      accentColor = const Color(0xFF7986cb); // Indigo Ribbon for Midnight
    } else if (theme == AppTheme.themeAmberLens) {
      accentColor = const Color(0xFFFF9800); // Amber Ribbon
    } else if (theme == AppTheme.themeAfterRain) {
      accentColor = const Color(0xFF29B6F6); // After Rain Ribbon (Light Blue)
    } else {
      accentColor = const Color(0xFFC0392B); // Default Red Ribbon
    }
        
    final Border? border;
    if (isSeaFlower) {
      border = Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1);
    } else if (theme == AppTheme.themeMidnight) {
      border = Border.all(color: const Color(0xFF30363d), width: 1); // Subtle dark border
    } else if (theme == AppTheme.themeAmberLens) {
      border = Border.all(color: const Color(0xFFFF9800), width: 1); // Amber Border
    } else if (theme == AppTheme.themeAfterRain) {
      border = Border.all(color: const Color(0x339999BF), width: 1); // After Rain Border
    } else {
      border = const Border(top: BorderSide(color: Color(0xFFC0392B), width: 8)); // Default Red Top
    }

    final List<BoxShadow> shadows;
    if (isSeaFlower) {
      shadows = [
        const BoxShadow(
          color: Color.fromRGBO(200, 150, 200, 0.2),
          offset: Offset(0, 8),
          blurRadius: 32,
        )
      ];
    } else if (theme == AppTheme.themeMidnight) {
      shadows = [
        const BoxShadow(
          color: Colors.black, // Deep black shadow
          offset: Offset(0, 4),
          blurRadius: 20,
        )
      ];
    } else if (theme == AppTheme.themeAmberLens) {
      shadows = [
        const BoxShadow(color: Colors.black, offset: Offset(0, 5), blurRadius: 20)
      ];
    } else if (theme == AppTheme.themeAfterRain) {
      shadows = [
        BoxShadow(
          color: const Color(0xFF8981AA).withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ];
    } else {
      shadows = AppTheme.paperShadow;
    }

    Widget paperContent = Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 300),
      padding: padding,
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(isSeaFlower ? 16 : 2),
        boxShadow: shadows,
        border: border,
      ),
      child: child,
    );

    // Apply Blur for Sea Flower
    if (isSeaFlower) {
      paperContent = ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
