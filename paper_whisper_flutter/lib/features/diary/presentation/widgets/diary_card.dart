import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:paper_whisper_flutter/app/navigation/route_transitions.dart'
    show getWidgetRect;
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_container.dart';

import 'dashed_line_painter.dart';

class DiaryCard extends StatefulWidget {
  final DiaryEntry entry;
  final String theme;
  final VoidCallback? onTap;
  final void Function(Rect cardRect)? onTapWithRect; // 点击时传递卡片位置

  const DiaryCard({
    super.key,
    required this.entry,
    required this.theme,
    this.onTap,
    this.onTapWithRect,
  });

  @override
  State<DiaryCard> createState() => _DiaryCardState();
}

class _DiaryCardState extends State<DiaryCard> {
  bool _isHovering = false;
  final GlobalKey _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // 从强类型注册表获取完整的主题配色
    final tc = ThemeRegistry.get(widget.theme).diaryCard;

    final Color titleColor = tc.titleColor;
    final Color contentColor = tc.contentColor;
    final Color dateColor = tc.dateColor;
    final Color iconColor = tc.iconColor;
    final Color dashedLineColor = tc.dashedLineColor;
    final Color bgColor = tc.bgColor;
    final List<BoxShadow> normalShadows = tc.shadows;
    final List<BoxShadow> hoverShadows = tc.hoverShadows;
    final double borderRadius = tc.borderRadius;

    // 悬停时的边框处理：部分主题悬停时边框颜色会变化
    final Color? hoverBorderColor = tc.hoverBorderColor;
    final Border? baseBorder = tc.border;
    final Border? border = (hoverBorderColor != null && _isHovering)
        ? Border.all(color: hoverBorderColor)
        : baseBorder;

    Widget cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.entry.dateString,
                style: GoogleFonts.courierPrime(
                  fontSize: 12,
                  height: 1.2, // Ensure clean baseline
                  color: dateColor,
                  fontWeight: tc.dateWeight,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    _getWeatherIcon(widget.entry.weather),
                    size: 16,
                    color: iconColor,
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    _getMoodIcon(widget.entry.mood),
                    size: 16,
                    color: iconColor,
                  ),
                ],
              ),
            ],
          ),
        ),
        // Dashed Line
        CustomPaint(
          size: const Size(double.infinity, 1),
          painter: DashedLinePainter(color: dashedLineColor),
        ),
        const SizedBox(height: 12),

        // Title
        Text(
          widget.entry.title,
          style: GoogleFonts.notoSerifSc(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),

        // Preview
        Text(
          widget.entry.content
                  .replaceAll('\n', ' ')
                  .substring(
                    0,
                    widget.entry.content.length > 80
                        ? 80
                        : widget.entry.content.length,
                  ) +
              (widget.entry.content.length > 80 ? '...' : ''),
          style: GoogleFonts.notoSerifSc(
            fontSize: 15,
            height: 1.8,
            color: contentColor,
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    // 构建卡片容器
    Widget containerBody;

    if (tc.glassEffect) {
      // 玻璃拟态逻辑（SeaFlower / Twilight）
      final Color glassColor = tc.glassColor;
      final double blurSigma = tc.blurSigma;

      containerBody = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: border,
              boxShadow: _isHovering ? hoverShadows : normalShadows,
            ),
            child: cardContent,
          ),
        ),
      );
    } else if (tc.usePaperContainer) {
      // 默认主题使用 SkeuomorphicContainer.paper
      containerBody = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: const BoxDecoration(),
        child: SkeuomorphicContainer.paper(
          padding: const EdgeInsets.all(25),
          bgColor: bgColor,
          shadows: _isHovering ? hoverShadows : normalShadows,
          child: cardContent,
        ),
      );
    } else {
      // 其他主题使用普通 AnimatedContainer
      containerBody = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
          boxShadow: _isHovering ? hoverShadows : normalShadows,
        ),
        child: cardContent,
      );
    }

    return GestureDetector(
      onTap: () {
        // 获取卡片位置并触发回调
        if (widget.onTapWithRect != null) {
          final rect = getWidgetRect(_cardKey);
          if (rect != null) {
            widget.onTapWithRect!(rect);
            return;
          }
        }
        // 降级到普通回调
        widget.onTap?.call();
      },
      child: MouseRegion(
        key: _cardKey, // 用于获取位置
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translateByDouble(
              0.0,
              _isHovering ? tc.hoverTranslateY : 0.0,
              0.0,
              1.0,
            )
            ..scaleByDouble(
              _isHovering ? tc.hoverScale : 1.0,
              _isHovering ? tc.hoverScale : 1.0,
              1.0,
              1.0,
            ),
          child: Stack(
            children: [
              containerBody,

              // Starry Sky Watermark (午夜星尘)
              if (tc.showStarWatermark)
                Positioned(
                  bottom: 15,
                  right: 20,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: _isHovering ? 1.0 : 0.0,
                      ),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack, // Bouncy effect for star
                      builder: (context, value, child) {
                        // Prevent negative values from easeOutBack curve when animating to 0
                        final safeValue = value.clamp(0.0, 1.0);

                        return Transform(
                          transform: Matrix4.identity()
                            ..translateByDouble(
                              0.0,
                              -10.0 * value,
                              0.0,
                              1.0,
                            ) // Float up (allow overshoot here for effect)
                            ..rotateZ(pi * value), // Rotate 180 deg
                          alignment: Alignment.center,
                          child: Opacity(
                            opacity: (0.3 + 0.5 * safeValue).clamp(0.0, 1.0),
                            child: Text(
                              '\u2726',
                              style: GoogleFonts.notoSerifSc(
                                fontSize: 40,
                                color: const Color(0xFF7986cb),
                                shadows: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7986cb,
                                    ).withValues(alpha: 0.8 * safeValue),
                                    blurRadius: max(
                                      0,
                                      15 * value,
                                    ), // Ensure non-negative
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Sea Flower Watermark (海底花海)
              if (tc.showFlowerWatermark)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: _isHovering ? 1.0 : 0.0,
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        final double currentRight = _lerp(-2.0, 8.0, value);
                        final double currentBottom = _lerp(-8.0, 2.0, value);

                        return Transform.translate(
                          offset: Offset(-currentRight, -currentBottom),
                          child: Transform(
                            transform: Matrix4.identity()
                              ..rotateZ(0.35 * value) // ~20 deg
                              ..scaleByDouble(
                                1.0 + 0.15 * value,
                                1.0 + 0.15 * value,
                                1.0,
                                1.0,
                              ),
                            alignment: Alignment.center,
                            child: Opacity(
                              opacity: 0.2 + 0.3 * value,
                              child: const Text(
                                '\u273F',
                                style: TextStyle(
                                  fontSize: 60,
                                  color: Color(0xFFEC407A),
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    BoxShadow(
                                      color: Color(0x33E91E63),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  IconData _getWeatherIcon(WeatherType w) {
    switch (w) {
      case WeatherType.sunny:
        return Icons.wb_sunny_outlined;
      case WeatherType.cloudy:
        return Icons.cloud_outlined;
      case WeatherType.rainy:
        return (widget.theme == AppTheme.themeAfterRain)
            ? Icons.umbrella_outlined
            : Icons.grain;
      case WeatherType.snowy:
        return Icons.ac_unit;
      case WeatherType.windy:
        return Icons.air;
    }
  }

  IconData _getMoodIcon(MoodType m) {
    switch (m) {
      case MoodType.happy:
        return Icons.sentiment_satisfied_alt;
      case MoodType.calm:
        return Icons.spa;
      case MoodType.sad:
        return Icons.sentiment_dissatisfied;
      case MoodType.excited:
        return Icons.sentiment_very_satisfied;
      case MoodType.tired:
        return Icons.airline_seat_flat_angled;
    }
  }
}
