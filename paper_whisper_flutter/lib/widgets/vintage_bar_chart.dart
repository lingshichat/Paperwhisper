import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

/// 复古便签墙柱状图
/// 将柱状图展示为软木板上的便签墙
class VintageBarChart extends StatelessWidget {
  final List<int> data;
  final String theme;
  final double height;

  const VintageBarChart({
    super.key,
    required this.data,
    required this.theme,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.every((d) => d == 0)) {
      return _buildEmptyState();
    }

    final colors = _getThemeColors();
    final maxValue = data.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // 软木板背景
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors.corkColors,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                  // 内阴影效果
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // 软木板纹理
                    Positioned.fill(
                      child: CustomPaint(painter: _CorkTexturePainter()),
                    ),
                    // 便签网格
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: data.asMap().entries.map((entry) {
                          final index = entry.key;
                          final value = entry.value;
                          final heightRatio = maxValue > 0
                              ? value / maxValue
                              : 0;
                          final isHighlighted = value > 0 && value == maxValue;

                          // 每5天显示一个日期标签
                          final showLabel = index % 5 == 0;
                          final day = DateTime.now().subtract(
                            Duration(days: (29 - index)),
                          );

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // 便签纸条
                              _StickyNote(
                                height: math.max(20, heightRatio * 120),
                                value: value,
                                isHighlighted: isHighlighted,
                                theme: theme,
                                colors: colors,
                                rotation: (index % 3 - 1) * 0.05, // 轻微随机旋转
                              ),
                              const SizedBox(height: 8),
                              // 日期标签
                              if (showLabel)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${day.day}',
                                    style: GoogleFonts.notoSerifSc(
                                      fontSize: 10,
                                      color: colors.textColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 20),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getThemeColors().corkColors,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无写作数据',
              style: GoogleFonts.notoSerifSc(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '开始写日记来填充这片便签墙吧',
              style: GoogleFonts.notoSerifSc(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _VintageChartColors _getThemeColors() {
    switch (theme) {
      case AppTheme.themeGardenOfWords:
        return _VintageChartColors(
          corkColors: [const Color(0xFF5D4037), const Color(0xFF4E342E)],
          noteColors: [
            const Color(0xFFC8E6C9),
            const Color(0xFFA5D6A7),
            const Color(0xFF81C784),
          ],
          textColor: const Color(0xFF1B5E20),
          accentColor: const Color(0xFF4CAF50),
        );
      case AppTheme.themeTwilight:
        return _VintageChartColors(
          corkColors: [const Color(0xFF4A148C), const Color(0xFF311B92)],
          noteColors: [
            const Color(0xFFF8BBD0),
            const Color(0xFFF48FB1),
            const Color(0xFFF06292),
          ],
          textColor: const Color(0xFF880E4F),
          accentColor: const Color(0xFFFF5252),
        );
      case AppTheme.themeAfterRain:
        return _VintageChartColors(
          corkColors: [const Color(0xFF37474F), const Color(0xFF263238)],
          noteColors: [
            const Color(0xFFE1F5FE),
            const Color(0xFFB3E5FC),
            const Color(0xFF81D4FA),
          ],
          textColor: const Color(0xFF01579B),
          accentColor: const Color(0xFF0288D1),
        );
      case AppTheme.themeSeaFlower:
        return _VintageChartColors(
          corkColors: [const Color(0xFF880E4F), const Color(0xFFAD1457)],
          noteColors: [
            const Color(0xFFFCE4EC),
            const Color(0xFFF8BBD0),
            const Color(0xFFF48FB1),
          ],
          textColor: const Color(0xFF880E4F),
          accentColor: const Color(0xFFF06292),
        );
      case AppTheme.themeMidnight:
        return _VintageChartColors(
          corkColors: [const Color(0xFF0D1117), const Color(0xFF161b22)],
          noteColors: [
            const Color(0xFFC5CAE9),
            const Color(0xFF9FA8DA),
            const Color(0xFF7986CB),
          ],
          textColor: const Color(0xFF1A237E),
          accentColor: const Color(0xFF3949AB),
        );
      case AppTheme.themeAmberLens:
        return _VintageChartColors(
          corkColors: [const Color(0xFF3E2723), const Color(0xFF4E342E)],
          noteColors: [
            const Color(0xFFFFECB3),
            const Color(0xFFFFE082),
            const Color(0xFFFFD54F),
          ],
          textColor: const Color(0xFF795548),
          accentColor: const Color(0xFFFF9800),
        );
      default: // Vintage
        return _VintageChartColors(
          corkColors: [const Color(0xFF8D6E63), const Color(0xFF6D4C41)],
          noteColors: [
            const Color(0xFFFFF9C4),
            const Color(0xFFFFF59D),
            const Color(0xFFFFF176),
          ],
          textColor: const Color(0xFF5D4037),
          accentColor: const Color(0xFFC0392B),
        );
    }
  }
}

class _VintageChartColors {
  final List<Color> corkColors;
  final List<Color> noteColors;
  final Color textColor;
  final Color accentColor;

  _VintageChartColors({
    required this.corkColors,
    required this.noteColors,
    required this.textColor,
    required this.accentColor,
  });
}

/// 便签纸条组件
class _StickyNote extends StatelessWidget {
  final double height;
  final int value;
  final bool isHighlighted;
  final String theme;
  final _VintageChartColors colors;
  final double rotation;

  const _StickyNote({
    required this.height,
    required this.value,
    required this.isHighlighted,
    required this.theme,
    required this.colors,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 根据数值选择颜色
    final colorIndex = value > 0
        ? (value > 500 ? 2 : (value > 100 ? 1 : 0))
        : 0;
    final noteColor = colors.noteColors[colorIndex.clamp(0, 2)];

    return Transform.rotate(
      angle: rotation,
      child: Tooltip(
        message: value > 0 ? '$value字' : '无记录',
        child: Container(
          width: 20,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [noteColor, noteColor.withValues(alpha: 0.9)],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              // 便签投影
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 3),
              ),
              // 边缘高光
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: value > 0
              ? Column(
                  children: [
                    // 胶带效果
                    Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.4),
                            Colors.white.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    if (isHighlighted)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors.accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}

/// 软木板纹理绘制器
class _CorkTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);

    // 绘制斑点纹理
    for (int i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2 + 0.5;
      final opacity = random.nextDouble() * 0.1 + 0.05;

      final paint = Paint()
        ..color = Colors.black.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // 绘制纤维纹理
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final width = random.nextDouble() * 4 + 1;
      final height = random.nextDouble() * 0.5 + 0.2;

      final paint = Paint()
        ..color = Colors.brown.withValues(alpha: 0.05)
        ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTWH(x, y, width, height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
