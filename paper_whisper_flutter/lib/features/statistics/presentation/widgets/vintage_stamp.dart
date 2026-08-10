import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';

/// 复古邮票组件
/// 用于天气分布、标签展示等
class VintageStamp extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String theme;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const VintageStamp({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    this.width = 90,
    this.height = 110,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getThemeColors();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipPath(
          clipper: _StampEdgeClipper(),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.bgColors,
              ),
              border: Border.all(color: colors.borderColor, width: 1.5),
            ),
            child: Stack(
              children: [
                // 纸张纹理
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PaperTexturePainter(color: colors.borderColor),
                  ),
                ),
                // 内容
                Padding(
                  padding: EdgeInsets.all(width * 0.08),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 图标
                      Container(
                        padding: EdgeInsets.all(width * 0.08),
                        decoration: BoxDecoration(
                          color: colors.accentColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.accentColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: width * 0.22,
                          color: colors.accentColor,
                        ),
                      ),
                      SizedBox(height: height * 0.06),
                      // 标签
                      Text(
                        label,
                        style: GoogleFonts.notoSerifSc(
                          fontSize: width * 0.12,
                          color: colors.textColor.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: height * 0.04),
                      // 数值邮戳
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: width * 0.1,
                          vertical: height * 0.02,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(height * 0.1),
                          border: Border.all(
                            color: colors.accentColor.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          value,
                          style: GoogleFonts.notoSerifSc(
                            fontSize: width * 0.14,
                            fontWeight: FontWeight.bold,
                            color: colors.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 邮戳效果
                Positioned(
                  right: -width * 0.05,
                  bottom: -height * 0.04,
                  child: Transform.rotate(
                    angle: math.pi / 6,
                    child: Container(
                      width: width * 0.35,
                      height: width * 0.35,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colors.accentColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _StampColors _getThemeColors() {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return _StampColors(
          bgColors: [const Color(0xFF37474F), const Color(0xFF263238)],
          borderColor: const Color(0xFF81C784).withValues(alpha: 0.4),
          accentColor: const Color(0xFF81C784),
          textColor: const Color(0xFFECEFF1),
        );
      case AppTheme.themeTwilight:
        return _StampColors(
          bgColors: [const Color(0xFF352044), const Color(0xFF2E1C55)],
          borderColor: const Color(0xFFFF9A6C).withValues(alpha: 0.4),
          accentColor: const Color(0xFFFF5252),
          textColor: const Color(0xFFE4E0EC),
        );
      case AppTheme.themeAfterRain:
        return _StampColors(
          bgColors: [
            Colors.white.withValues(alpha: 0.9),
            const Color(0xFFF0F8FF),
          ],
          borderColor: const Color(0xFF4FC3F7).withValues(alpha: 0.5),
          accentColor: const Color(0xFF0288D1),
          textColor: const Color(0xFF455A64),
        );
      case AppTheme.themeSeaFlower:
        return _StampColors(
          bgColors: [const Color(0xFFFFF5F7), const Color(0xFFFCE4EC)],
          borderColor: const Color(0xFFF06292).withValues(alpha: 0.4),
          accentColor: const Color(0xFFF06292),
          textColor: const Color(0xFF880E4F),
        );
      case AppTheme.themeMidnight:
        return _StampColors(
          bgColors: [const Color(0xFF1a237e), const Color(0xFF161b22)],
          borderColor: const Color(0xFF7986cb).withValues(alpha: 0.4),
          accentColor: const Color(0xFF7986cb),
          textColor: const Color(0xFFe6edf3),
        );
      case AppTheme.themeAmberLens:
        return _StampColors(
          bgColors: [const Color(0xFF2C2C2C), const Color(0xFF1E1E1E)],
          borderColor: const Color(0xFFFF9800).withValues(alpha: 0.4),
          accentColor: const Color(0xFFFF9800),
          textColor: const Color(0xFFE0E0E0),
        );
      default: // Vintage
        return _StampColors(
          bgColors: [const Color(0xFFF4ECD8), const Color(0xFFE8DCC4)],
          borderColor: const Color(0xFF5D4037).withValues(alpha: 0.3),
          accentColor: const Color(0xFFC0392B),
          textColor: const Color(0xFF2C3E50),
        );
    }
  }
}

class _StampColors {
  final List<Color> bgColors;
  final Color borderColor;
  final Color accentColor;
  final Color textColor;

  _StampColors({
    required this.bgColors,
    required this.borderColor,
    required this.accentColor,
    required this.textColor,
  });
}

/// 邮票锯齿边缘裁剪器
class _StampEdgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const teethSize = 6.0;
    const teethSpacing = 8.0;

    // 上边
    path.moveTo(0, teethSize);
    double x = 0;
    while (x < size.width) {
      path.lineTo(x + teethSpacing / 2, 0);
      path.lineTo(x + teethSpacing, teethSize);
      x += teethSpacing;
    }

    // 右边
    double y = 0;
    while (y < size.height) {
      path.lineTo(size.width - teethSize, y + teethSpacing / 2);
      path.lineTo(size.width, y + teethSpacing);
      y += teethSpacing;
    }

    // 下边
    x = size.width;
    while (x > 0) {
      path.lineTo(x - teethSpacing / 2, size.height);
      path.lineTo(x - teethSpacing, size.height - teethSize);
      x -= teethSpacing;
    }

    // 左边
    y = size.height;
    while (y > 0) {
      path.lineTo(teethSize, y - teethSpacing / 2);
      path.lineTo(0, y - teethSpacing);
      y -= teethSpacing;
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 纸张纹理绘制器
class _PaperTexturePainter extends CustomPainter {
  final Color color;

  _PaperTexturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final random = math.Random(123);

    // 绘制随机纤维纹理
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final width = random.nextDouble() * 3 + 1;
      final height = random.nextDouble() * 0.5 + 0.2;

      canvas.drawRect(Rect.fromLTWH(x, y, width, height), paint);
    }

    // 绘制一些噪点
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 0.8 + 0.2;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 天气邮票集合组件
class WeatherStampCollection extends StatelessWidget {
  final Map<String, int> weatherData;
  final String theme;

  const WeatherStampCollection({
    super.key,
    required this.weatherData,
    required this.theme,
  });

  static const Map<String, IconData> _weatherIcons = {
    'sunny': Icons.wb_sunny,
    'cloudy': Icons.wb_cloudy,
    'rainy': Icons.water_drop,
    'snowy': Icons.ac_unit,
    'windy': Icons.air,
  };

  static const Map<String, String> _weatherLabels = {
    'sunny': '晴天',
    'cloudy': '多云',
    'rainy': '雨天',
    'snowy': '雪天',
    'windy': '有风',
  };

  @override
  Widget build(BuildContext context) {
    final sortedData = weatherData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: sortedData.map((entry) {
        return VintageStamp(
          icon: _weatherIcons[entry.key] ?? Icons.wb_sunny,
          label: _weatherLabels[entry.key] ?? entry.key,
          value: '${entry.value}',
          theme: theme,
          width: 75,
          height: 90,
        );
      }).toList(),
    );
  }
}
