import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';

/// 火漆印章徽章组件
/// 用于展示高光数据，如连续写作天数
class WaxSealBadge extends StatelessWidget {
  final int number;
  final String unit;
  final String label;
  final String theme;
  final double size;
  final IconData? icon;

  const WaxSealBadge({
    super.key,
    required this.number,
    required this.unit,
    required this.label,
    required this.theme,
    this.size = 180,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getThemeColors();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // 主阴影
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
          // 环境光
          BoxShadow(
            color: colors.waxColor.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 0),
            spreadRadius: 5,
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _WaxSealPainter(
          waxColor: colors.waxColor,
          highlightColor: colors.highlightColor,
          textColor: colors.textColor,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 顶部图标
              if (icon != null) ...[
                Icon(
                  icon,
                  color: colors.textColor.withValues(alpha: 0.9),
                  size: size * 0.15,
                ),
                SizedBox(height: size * 0.03),
              ],
              // 数字
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$number',
                    style: GoogleFonts.notoSerifSc(
                      fontSize: size * 0.28,
                      fontWeight: FontWeight.bold,
                      color: colors.textColor,
                      height: 1.0,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: size * 0.02),
                  Padding(
                    padding: EdgeInsets.only(bottom: size * 0.04),
                    child: Text(
                      unit,
                      style: GoogleFonts.notoSerifSc(
                        fontSize: size * 0.1,
                        color: colors.textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: size * 0.02),
              // 标签
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size * 0.08,
                  vertical: size * 0.02,
                ),
                decoration: BoxDecoration(
                  color: colors.textColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(size * 0.05),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.notoSerifSc(
                    fontSize: size * 0.07,
                    color: colors.textColor.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _WaxSealColors _getThemeColors() {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return _WaxSealColors(
          waxColor: const Color(0xFF4CAF50),
          highlightColor: const Color(0xFF81C784),
          textColor: Colors.white,
          shadow: Colors.black,
        );
      case AppTheme.themeTwilight:
        return _WaxSealColors(
          waxColor: const Color(0xFFFF5252),
          highlightColor: const Color(0xFFFF8A80),
          textColor: Colors.white,
          shadow: const Color(0xFFFF5252),
        );
      case AppTheme.themeAfterRain:
        return _WaxSealColors(
          waxColor: const Color(0xFF0288D1),
          highlightColor: const Color(0xFF4FC3F7),
          textColor: Colors.white,
          shadow: const Color(0xFF0288D1),
        );
      case AppTheme.themeSeaFlower:
        return _WaxSealColors(
          waxColor: const Color(0xFFF06292),
          highlightColor: const Color(0xFFF8BBD0),
          textColor: Colors.white,
          shadow: const Color(0xFFF06292),
        );
      case AppTheme.themeMidnight:
        return _WaxSealColors(
          waxColor: const Color(0xFF3949AB),
          highlightColor: const Color(0xFF7986CB),
          textColor: Colors.white,
          shadow: const Color(0xFF3949AB),
        );
      case AppTheme.themeAmberLens:
        return _WaxSealColors(
          waxColor: const Color(0xFFFF9800),
          highlightColor: const Color(0xFFFFB74D),
          textColor: Colors.white,
          shadow: const Color(0xFFFF9800),
        );
      default: // Vintage
        return _WaxSealColors(
          waxColor: const Color(0xFFC0392B),
          highlightColor: const Color(0xFFE74C3C),
          textColor: const Color(0xFFF4ECD8),
          shadow: const Color(0xFF3E2723),
        );
    }
  }
}

class _WaxSealColors {
  final Color waxColor;
  final Color highlightColor;
  final Color textColor;
  final Color shadow;

  _WaxSealColors({
    required this.waxColor,
    required this.highlightColor,
    required this.textColor,
    required this.shadow,
  });
}

class _WaxSealPainter extends CustomPainter {
  final Color waxColor;
  final Color highlightColor;
  final Color textColor;

  _WaxSealPainter({
    required this.waxColor,
    required this.highlightColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. 外圈阴影层
    final shadowPaint = Paint()
      ..color = waxColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, radius * 0.95, shadowPaint);

    // 2. 主蜡质底色
    final basePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.2,
        colors: [highlightColor, waxColor],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.9, basePaint);

    // 3. 内圈边框（模拟蜡质厚度）
    final borderPaint = Paint()
      ..color = waxColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius * 0.85, borderPaint);

    // 4. 外圈锯齿（火漆印章纹理）
    final serratedPaint = Paint()
      ..color = waxColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final serratedPath = Path();
    const serratedCount = 24;
    for (int i = 0; i < serratedCount; i++) {
      final angle = (i * 2 * math.pi) / serratedCount;
      final innerRadius = radius * 0.88;
      final outerRadius = radius * 0.92;

      final x1 = center.dx + innerRadius * math.cos(angle);
      final y1 = center.dy + innerRadius * math.sin(angle);
      final x2 = center.dx + outerRadius * math.cos(angle);
      final y2 = center.dy + outerRadius * math.sin(angle);

      if (i == 0) {
        serratedPath.moveTo(x1, y1);
      } else {
        serratedPath.lineTo(x1, y1);
      }
      serratedPath.lineTo(x2, y2);
    }
    serratedPath.close();
    canvas.drawPath(serratedPath, serratedPaint);

    // 5. 高光效果（模拟蜡质光泽）
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        radius: 0.5,
        colors: [
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.5, highlightPaint);

    // 6. 纹理噪点（模拟蜡质不完美）
    final noisePaint = Paint()
      ..color = waxColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final r = random.nextDouble() * radius * 0.7;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      final dotRadius = random.nextDouble() * 2 + 0.5;
      canvas.drawCircle(Offset(x, y), dotRadius, noisePaint);
    }

    // 7. 底部阴影渐变（增加立体感）
    final bottomShadowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.8),
        radius: 0.8,
        colors: [
          waxColor.withValues(alpha: 0.0),
          waxColor.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.9, bottomShadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
