import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

/// 手账分隔线组件
/// 模拟手账本中的虚线分隔效果
class LedgerDivider extends StatelessWidget {
  final String? label;
  final String theme;
  final double thickness;
  final IconData? icon;

  const LedgerDivider({
    super.key,
    this.label,
    required this.theme,
    this.thickness = 1,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getDividerColor();

    if (label == null && icon == null) {
      // 纯虚线
      return CustomPaint(
        size: const Size(double.infinity, 24),
        painter: _DashedLinePainter(
          color: color,
          strokeWidth: thickness,
        ),
      );
    }

    // 带标签的分隔线
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 24),
              painter: _DashedLinePainter(
                color: color,
                strokeWidth: thickness,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 6),
                ],
                if (label != null)
                  Text(
                    label!,
                    style: GoogleFonts.notoSerifSc(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 24),
              painter: _DashedLinePainter(
                color: color,
                strokeWidth: thickness,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDividerColor() {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return const Color(0xFF81C784).withOpacity(0.4);
      case AppTheme.themeTwilight:
        return const Color(0xFFFF9A6C).withOpacity(0.4);
      case AppTheme.themeAfterRain:
        return const Color(0xFF4FC3F7).withOpacity(0.4);
      case AppTheme.themeSeaFlower:
        return const Color(0xFFF06292).withOpacity(0.4);
      case AppTheme.themeMidnight:
        return const Color(0xFF7986cb).withOpacity(0.4);
      case AppTheme.themeAmberLens:
        return const Color(0xFFFF9800).withOpacity(0.4);
      default: // Vintage
        return const Color(0xFF5D4037).withOpacity(0.3);
    }
  }

  Color _getBackgroundColor() {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return const Color(0xFF263238).withOpacity(0.5);
      case AppTheme.themeTwilight:
        return const Color(0xFF352044).withOpacity(0.5);
      case AppTheme.themeAfterRain:
        return Colors.white.withOpacity(0.5);
      case AppTheme.themeSeaFlower:
        return const Color(0xFFFCE4EC).withOpacity(0.5);
      case AppTheme.themeMidnight:
        return const Color(0xFF161b22).withOpacity(0.5);
      case AppTheme.themeAmberLens:
        return const Color(0xFF2C2C2C).withOpacity(0.5);
      default: // Vintage
        return const Color(0xFFF4ECD8).withOpacity(0.5);
    }
  }
}

/// 装饰性分隔线 - 带花纹
class DecorativeDivider extends StatelessWidget {
  final String theme;
  final String? label;

  const DecorativeDivider({
    super.key,
    required this.theme,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getDividerColor();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0),
                        color.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 8,
                      color: color.withOpacity(0.6),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.star,
                      size: 12,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.favorite,
                      size: 8,
                      color: color.withOpacity(0.6),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.5),
                        color.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(
              label!,
              style: GoogleFonts.notoSerifSc(
                fontSize: 12,
                color: color.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getDividerColor() {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return const Color(0xFF81C784);
      case AppTheme.themeTwilight:
        return const Color(0xFFFF9A6C);
      case AppTheme.themeAfterRain:
        return const Color(0xFF4FC3F7);
      case AppTheme.themeSeaFlower:
        return const Color(0xFFF06292);
      case AppTheme.themeMidnight:
        return const Color(0xFF7986cb);
      case AppTheme.themeAmberLens:
        return const Color(0xFFFF9800);
      default: // Vintage
        return const Color(0xFFC0392B);
    }
  }
}

/// 虚线绘制器
class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedLinePainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final centerY = size.height / 2;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, centerY),
        Offset(startX + dashWidth, centerY),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
