import 'dart:ui';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/diary_entry.dart';
import '../config/app_theme.dart';
import '../widgets/skeuomorphic_container.dart';
import '../widgets/dashed_line_painter.dart';
import '../widgets/unfold_page_route.dart';

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
    // 海底花海主题判断
    final bool isSeaFlower = widget.theme == AppTheme.themeSeaFlower;
    final bool isMidnight = widget.theme == AppTheme.themeMidnight;
    final bool isAmber = widget.theme == AppTheme.themeAmberLens;

    // 颜色配置
    final Color titleColor;
    final Color contentColor;
    final Color dateColor;
    final Color iconColor;
    final Color dashedLineColor;

    if (isSeaFlower) {
      titleColor = const Color(0xFF880E4F);
      contentColor = const Color(0xFFC2185B);
      dateColor = const Color(0xFFAD1457);
      iconColor = const Color(0xFFEC407A); 
      dashedLineColor = const Color(0x4DC2185B); 
    } else if (isMidnight) {
      titleColor = const Color(0xFFe6edf3);
      contentColor = const Color(0xFF8b949e);
      dateColor = const Color(0xFF8b949e);
      iconColor = const Color(0xFF7986cb);
      dashedLineColor = const Color(0xFF30363d);
    } else if (isAmber) {
      titleColor = const Color(0xFFE0E0E0);
      contentColor = const Color(0xFFBDBDBD);
      dateColor = const Color(0xFFFF9800);
      iconColor = const Color(0xFFFF9800);
      dashedLineColor = const Color(0x40FF9800); // Amber 25%
    } else {
      titleColor = const Color(0xFF5D4037);
      contentColor = const Color(0xFF5D4037).withValues(alpha: 0.9);
      dateColor = const Color(0xFF8D6E63);
      iconColor = const Color(0xFF8D6E63);
      dashedLineColor = const Color.fromRGBO(93, 64, 55, 0.15);
    }

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
                  fontWeight: isSeaFlower || isAmber ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(_getWeatherIcon(widget.entry.weather), size: 16, color: iconColor),
                  const SizedBox(width: 5),
                  Icon(_getMoodIcon(widget.entry.mood), size: 16, color: iconColor),
                ],
              )
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
          widget.entry.content.replaceAll('\n', ' ').substring(
                  0,
                  widget.entry.content.length > 80
                      ? 80
                      : widget.entry.content.length) +
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

    // 通用悬停交互逻辑
    List<BoxShadow> normalShadows;
    List<BoxShadow> hoverShadows;
    Color bgColor;
    Border? border; 

    if (isSeaFlower) {
      bgColor = Colors.white.withOpacity(0.35);
      normalShadows = [
        const BoxShadow(
          color: Color.fromRGBO(200, 150, 200, 0.2),
          offset: Offset(0, 8),
          blurRadius: 32,
        )
      ];
       hoverShadows = [
          const BoxShadow(
           color: Color.fromRGBO(255, 255, 255, 0.6), // White glow
           offset: Offset(0, 0), // Surrounding glow
           blurRadius: 20,
           spreadRadius: 4,
         )
       ];
      border = Border.all(color: Colors.white.withOpacity(0.5));
    } else if (isMidnight) {
      bgColor = const Color(0xFF161b22).withOpacity(0.9);
      normalShadows = [
        const BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.5),
          offset: Offset(0, 4),
          blurRadius: 10,
        )
      ];
      hoverShadows = [
         const BoxShadow(
          color: Color(0xFF7986cb), // Indigo glow
          offset: Offset(0, 0),
          blurRadius: 15,
          spreadRadius: 1,
        ),
         const BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.8),
          offset: Offset(0, 10),
          blurRadius: 25,
        )
      ];
      border = Border.all(color: _isHovering ? const Color(0xFF7986cb) : const Color(0xFF30363d));
    } else if (isAmber) {
      bgColor = const Color(0xFF1E1E1E).withOpacity(0.95);
      normalShadows = [
        const BoxShadow(color: Colors.black, offset: Offset(0, 4), blurRadius: 8)
      ];
      hoverShadows = [
        const BoxShadow(
          color: Color(0x66FF9800), // Amber glow
          offset: Offset(0, 0),
          blurRadius: 15,
          spreadRadius: 1,
        ),
        const BoxShadow(color: Colors.black, offset: Offset(0, 10), blurRadius: 20)
      ];
      border = Border.all(color: _isHovering ? const Color(0xFFFF9800) : const Color(0xFF424242));
    } else {
      bgColor = AppTheme.getPaperColor(widget.theme);
      normalShadows = [
        const BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.1),
          offset: Offset(0, 5),
          blurRadius: 10,
        )
      ];
      hoverShadows = [
        const BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.15),
          offset: Offset(0, 10),
          blurRadius: 20,
        )
      ];
      border = null;
    }

    Widget containerBody;

    if (isSeaFlower) {
       // 优化：增加背景不透明度，降低模糊强度，减少滚动时的视觉跳变
       // 使用更高的不透明度让背景填充更"实"，减少对模糊的依赖
       bgColor = Colors.white.withValues(alpha: 0.65);

       containerBody = ClipRRect(
         borderRadius: BorderRadius.circular(16),
         child: BackdropFilter(
           // 降低模糊强度：sigma 20 -> 8，性能更好且滚动时变化更小
           filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
           child: AnimatedContainer(
             duration: const Duration(milliseconds: 300),
             curve: Curves.easeOut,
             padding: const EdgeInsets.all(25),
             decoration: BoxDecoration(
               color: bgColor,
               borderRadius: BorderRadius.circular(16),
               border: border,
               boxShadow: _isHovering ? hoverShadows : normalShadows,
             ),
             child: cardContent,
           ),
         ),
       );
    } else if (isMidnight || isAmber) {
        containerBody = AnimatedContainer(
             duration: const Duration(milliseconds: 300),
             curve: Curves.easeOut,
             padding: const EdgeInsets.all(25),
             decoration: BoxDecoration(
               color: bgColor,
               borderRadius: BorderRadius.circular(6), // Slightly rounded
               border: border,
               boxShadow: _isHovering ? hoverShadows : normalShadows,
             ),
             child: cardContent,
        );
    } else {
        containerBody = AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
          ),
          child: SkeuomorphicContainer.paper(
            padding: const EdgeInsets.all(25),
            bgColor: bgColor,
            shadows: _isHovering ? hoverShadows : normalShadows, 
            child: cardContent,
          ),
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
            ..translate(0.0, _isHovering ? (isSeaFlower ? -8.0 : -4.0) : 0.0)
            ..scale((_isHovering && isSeaFlower) ? 1.02 : 1.0),
          child: Stack(
            children: [
               containerBody,

               // Starry Sky Watermark
               if (isMidnight)
                 Positioned(
                    bottom: 15,
                    right: 20,
                    child: IgnorePointer(
                     child: TweenAnimationBuilder<double>(
                       tween: Tween<double>(begin: 0, end: _isHovering ? 1.0 : 0.0),
                       duration: const Duration(milliseconds: 600),
                       curve: Curves.easeOutBack, // Bouncy effect for star
                       builder: (context, value, child) {
                          // Prevent negative values from easeOutBack curve when animating to 0
                          final safeValue = value.clamp(0.0, 1.0);
                          
                          return Transform(
                             transform: Matrix4.identity()
                                ..translate(0.0, -10.0 * value) // Float up (allow overshoot here for effect)
                                ..rotateZ(pi * value), // Rotate 180 deg
                             alignment: Alignment.center,
                             child: Opacity(
                               opacity: (0.3 + 0.5 * safeValue).clamp(0.0, 1.0),
                               child: Text(
                                 '✦',
                                 style: GoogleFonts.notoSerifSc(
                                   fontSize: 40,
                                   color: const Color(0xFF7986cb),
                                   shadows: [
                                     BoxShadow(
                                       color: const Color(0xFF7986cb).withValues(alpha: 0.8 * safeValue), 
                                       blurRadius: max(0, 15 * value) // Ensure non-negative
                                     )
                                   ]
                                 ),
                               ),
                             ),
                           );
                       },
                     ),
                    ),
                 ),

               // Sea Flower Watermark
               if (isSeaFlower)
                 Positioned(
                   right: 0, 
                   bottom: 0,
                   child: IgnorePointer(
                     child: TweenAnimationBuilder<double>(
                       tween: Tween<double>(begin: 0, end: _isHovering ? 1.0 : 0.0),
                       duration: const Duration(milliseconds: 500),
                       curve: Curves.easeOutCubic,
                       builder: (context, value, child) {
                          // 插值位置: (-2,-8) -> (8,2)
                          // Right: -2 -> 8 (delta +10)
                          // Bottom: -8 -> 2 (delta +10)
                          
                          // 我们使用 Transform.translate 移动 Container 内部内容
                          // 锚点在 Container 右下角(因为父级 Positioned 是 right:0, bottom:0)
                          
                          // 初始视觉位置：right: -2, bottom: -8 (相对于 Stack 右下角)
                          // 我们在 Positioned(right:0, bottom:0) 里面放置一个容器
                          // 该容器应该偏移到 (-2, -8) 吗? 
                          // Positioned(right:0, bottom:0) 意味着子组件右下角对齐 Stack 右下角
                          // 如果我们要初始偏移 (-2, -8)，即向右2, 向下8 (出去了?) 
                          // Web: right: -2px (overflows slightly), bottom: -8px (overflows)
                          // Flutter Positioned right: -2 works.
                          
                          // 为了简单，我们让 Positioned 始终在 (0,0)，用 Transform 移动
                          
                          // 初始状态 (value=0): Translate(2, 8) -> 对应 right=-2, bottom=-8
                          // 悬停状态 (value=1): Translate(-8, -2) -> 对应 right=8, bottom=2
                          
                          final double currentRight = _lerp(-2.0, 8.0, value);
                          final double currentBottom = _lerp(-8.0, 2.0, value);

                          // Positioned(right: 0, bottom: 0)
                          // Translate(x, y)
                          // right=N 意味着 x = -N (向左移动N距离)
                          // bottom=M 意味着 y = -M (向上移动M距离)
                          
                          return Transform.translate(
                             offset: Offset(-currentRight, -currentBottom),
                             child: Transform(
                               transform: Matrix4.identity()
                                  ..rotateZ(0.35 * value) // ~20 deg
                                  ..scale(1.0 + 0.15 * value),
                               alignment: Alignment.center,
                               child: Opacity(
                                 opacity: 0.2 + 0.3 * value,
                                 child: const Text(
                                   '✿',
                                   style: TextStyle(
                                     fontSize: 60,
                                     color: Color(0xFFEC407A),
                                     fontWeight: FontWeight.bold,
                                     shadows: [
                                        BoxShadow(
                                          color: Color(0x33E91E63),
                                          blurRadius: 10,
                                        )
                                     ]
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
      case WeatherType.sunny: return Icons.wb_sunny_outlined;
      case WeatherType.cloudy: return Icons.cloud_outlined;
      case WeatherType.rainy: return Icons.grain;
      case WeatherType.snowy: return Icons.ac_unit;
      case WeatherType.windy: return Icons.air;
    }
  }

  IconData _getMoodIcon(MoodType m) {
    switch (m) {
      case MoodType.happy: return Icons.sentiment_satisfied_alt;
      case MoodType.calm: return Icons.spa;
      case MoodType.sad: return Icons.sentiment_dissatisfied;
      case MoodType.excited: return Icons.sentiment_very_satisfied;
      case MoodType.tired: return Icons.airline_seat_flat_angled; 
    }
  }
}
