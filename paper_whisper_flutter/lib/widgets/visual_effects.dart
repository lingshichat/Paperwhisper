import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

// --- Petal Rain Effect ---

class PetalRainWidget extends StatefulWidget {
  const PetalRainWidget({super.key});

  @override
  State<PetalRainWidget> createState() => _PetalRainWidgetState();
}

class _PetalRainWidgetState extends State<PetalRainWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Petal> _petals = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // 初始化花瓣
    for (int i = 0; i < 25; i++) {
        _petals.add(_generatePetal(true));
    }

    _controller = AnimationController(
             vsync: this, 
             duration: const Duration(seconds: 1)
           )..addListener(_updatePetals)
            ..repeat();
  }

  void _updatePetals() {
    for (var petal in _petals) {
      // 1. 更新Y轴下落 (Linear)
      petal.y += petal.speed;
      
      // 计算进度 (Progress 0.0 -> 1.0)
      // Range: -0.2 (Start) to 1.15 (End) -> span = 1.35
      final double progress = (petal.y - (-0.2)) / 1.35;
      
      // 2. 复刻 CSS Keyframes: Sway (X轴偏移)
      // 0%  -> 0
      // 25% -> 25px
      // 50% -> -15px
      // 75% -> 30px
      // 100% -> 0
      if (progress < 0.25) {
        petal.swayX = _lerp(0, 25, progress / 0.25);
      } else if (progress < 0.50) {
        petal.swayX = _lerp(25, -15, (progress - 0.25) / 0.25);
      } else if (progress < 0.75) {
        petal.swayX = _lerp(-15, 30, (progress - 0.50) / 0.25);
      } else {
        petal.swayX = _lerp(30, 0, (progress - 0.75) / 0.25);
      }
      
      // 3. 复刻 CSS Keyframes: Rotation (0 -> 360deg)
      petal.rotation = progress * 2 * pi;
      
      // 4. 复刻 CSS Keyframes: Opacity
      // 0% -> 0
      // 5% -> maxOpacity
      // 95% -> maxOpacity
      // 100% -> 0
      if (progress < 0.05) {
        petal.opacity = _lerp(0, petal.maxOpacity, progress / 0.05);
      } else if (progress > 0.95) {
        petal.opacity = _lerp(petal.maxOpacity, 0, (progress - 0.95) / 0.05);
      } else {
        petal.opacity = petal.maxOpacity;
      }

      // 超出边界时重置
      if (petal.y > 1.2) {
         _resetPetal(petal);
      }
    }
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }

  Petal _generatePetal(bool initial) {
    // 初始生成分布在全屏 (0.0~1.2)，后续只从上方(-0.2)
    final startY = initial ? (_random.nextDouble() * 1.4 - 0.2) : -0.2;
    return Petal(
      x: _random.nextDouble(),
      y: startY, 
      size: 20 + _random.nextDouble() * 20, 
      // 保持极慢速度: 0.0003 ~ 0.0008
      speed: 0.0003 + _random.nextDouble() * 0.0005,
      maxOpacity: 0.2 + _random.nextDouble() * 0.4, // Store max opacity
      color: _getRandomColor(),
    );
  }

  void _resetPetal(Petal petal) {
    petal.y = -0.2; // Reset to top
    petal.x = _random.nextDouble();
    petal.maxOpacity = 0.2 + _random.nextDouble() * 0.4;
    petal.speed = 0.0003 + _random.nextDouble() * 0.0005;
    petal.color = _getRandomColor();
    petal.rotation = 0;
    petal.swayX = 0;
  }

  Color _getRandomColor() {
     const colors = [
        Color(0xFFF8BBD0), Color(0xFFF48FB1), Color(0xFFE1BEE7),
        Color(0xFFCE93D8), Color(0xFFFFE5F1), Color(0xFFF3E5F5), Color(0xFFEC407A),
     ];
     return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer( 
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: PetalPainter(_petals),
              size: Size.infinite,
            ),
          );
        },
      ),
    );
  }
}

class Petal {
  double x; // 0.0-1.0 (Base horizontal position)
  double y; // -0.2-1.2 (Vertical position)
  double size;
  double speed;
  Color color;
  
  // Dynamic properties
  double opacity = 0;
  double maxOpacity;
  double rotation = 0;
  double swayX = 0; // Pixel offset

  Petal({
    required this.x, 
    required this.y, 
    required this.size, 
    required this.speed, 
    required this.maxOpacity, 
    required this.color, 
  });
}

class PetalPainter extends CustomPainter {
  final List<Petal> petals;

  PetalPainter(this.petals);

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var petal in petals) {
      if (petal.opacity <= 0) continue;

      // 1. 设置文本样式 ('✿')
      textPainter.text = TextSpan(
        text: '✿',
        style: TextStyle(
          fontSize: petal.size,
          color: petal.color.withValues(alpha: petal.opacity),
          shadows: [
            BoxShadow(
              color: const Color(0xFFF06292).withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
          fontFamily: 'Noto Serif SC', 
        ),
      );
      
      textPainter.layout();

      canvas.save();
      
      // 2. 位置 (Base X ratio + Sway px)
      final dx = petal.x * size.width + petal.swayX;
      final dy = petal.y * size.height;
      
      // 为了中心旋转，需要先移动到中心，旋转，再画
      canvas.translate(dx, dy);
      canvas.rotate(petal.rotation);
      
      // 居中绘制
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- Starry Sky Effect ---

// --- Starry Sky Effect ---

class StarrySkyWidget extends StatefulWidget {
  const StarrySkyWidget({super.key});

  @override
  State<StarrySkyWidget> createState() => _StarrySkyWidgetState();
}

class _StarrySkyWidgetState extends State<StarrySkyWidget> with SingleTickerProviderStateMixin {
  final List<Star> _stars = [];
  final List<HangingStar> _hangingStars = [];
  final Random _random = Random(42); 
  
  late Ticker _ticker;
  double _time = 0.0;

  @override
  void initState() {
    super.initState();
    // 1. 初始化背景闪烁星星 (Twinkling Background Stars)
    for (int i = 0; i < 100; i++) {
       _stars.add(Star(
         x: _random.nextDouble(),
         y: _random.nextDouble(),
         radius: _random.nextDouble() * 1.5 + 0.5,
         baseOpacity: _random.nextDouble() * 0.4 + 0.1,
         twinkleOffset: _random.nextDouble() * 2 * pi,
         twinkleSpeed: 0.5 + _random.nextDouble() * 1.5,
       ));
    }

    // 2. 初始化悬挂星星 (Hanging Stars)
    for (int i = 0; i < 8; i++) {
      _hangingStars.add(HangingStar(
        x: 0.1 + _random.nextDouble() * 0.8, 
        y: 0.1 + _random.nextDouble() * 0.5, 
        size: 8.0 + _random.nextDouble() * 6.0,
        swaySpeed: 0.5 + _random.nextDouble() * 0.5,
        swayOffset: _random.nextDouble() * 2 * pi,
        lineLength: 0.0, 
      ));
    }

    // 3. 使用 Ticker 实现无缝无限循环
    _ticker = createTicker((elapsed) {
      setState(() {
        // Simple linear time, no reset loop to cause jumps
        _time = elapsed.inMilliseconds / 1000.0; 
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: StarPainter(_stars, _hangingStars, _time),
        size: Size.infinite,
      ),
    );
  }
}

class Star {
  final double x;
  final double y;
  final double radius;
  final double baseOpacity;
  final double twinkleOffset;
  final double twinkleSpeed;

  Star({
    required this.x, 
    required this.y, 
    required this.radius, 
    required this.baseOpacity,
    required this.twinkleOffset,
    required this.twinkleSpeed,
  });
}

class HangingStar {
  final double x;
  final double y; 
  final double size;
  final double swaySpeed;
  final double swayOffset;
  final double lineLength; 

  HangingStar({
    required this.x, 
    required this.y, 
    required this.size, 
    required this.swaySpeed, 
    required this.swayOffset,
    required this.lineLength,
  });
}

class StarPainter extends CustomPainter {
  final List<Star> stars;
  final List<HangingStar> hangingStars;
  final double time; 

  StarPainter(this.stars, this.hangingStars, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    // 1. Draw Background Stars (Small 5-pointed stars)
    for (var star in stars) {
       // Continuous sine wave: 0.5 * (1 + sin) -> range 0.0 ~ 1.0. 
       // Scaled to 0.4 ~ 1.0 logic similar to SVG
       final double wave = sin(time * star.twinkleSpeed + star.twinkleOffset);
       final double opacityRatio = 0.5 * (1 + wave); 
       final double currentOpacity = star.baseOpacity + (opacityRatio * (1.0 - star.baseOpacity)); 
       
       // Draw with glow (Anti-aliasing and Blur)
       _drawGlowingStar(canvas, Offset(star.x * size.width, star.y * size.height), star.radius, paint, currentOpacity.clamp(0.0, 1.0));
    }

    // 2. Draw Hanging Stars
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    for (var hStar in hangingStars) {
      // Gentle sway: 5px max
      final double sway = sin(time * hStar.swaySpeed + hStar.swayOffset) * 5.0; 
      
      final double startX = hStar.x * size.width;
      final double targetX = startX + sway;
      final double targetY = hStar.y * size.height;

      // Draw Thread
      canvas.drawLine(Offset(startX, 0), Offset(targetX, targetY - hStar.size), linePaint);
      
      // Calculate opacity for hanging star
      // Slower blink for hanging stars: speed ~ 0.5-1.0
      final double wave = sin(time * 0.8 + hStar.swayOffset); 
      // Mapped to 0.5 ~ 1.0
      final double starOpacity = 0.75 + 0.25 * wave; 

      // Draw Star with Glow
      _drawGlowingStar(canvas, Offset(targetX, targetY), hStar.size, paint, starOpacity.clamp(0.0, 1.0));
    }
  }

  void _drawGlowingStar(Canvas canvas, Offset center, double radius, Paint paint, double opacity) {
    paint.isAntiAlias = true;
    final path = _createStarPath(center, radius, radius * 0.4);

    // 1. Draw Glow (Using multiple blurred layers for smoothness)
    // Layer 1: Wide faint glow
    paint.color = Colors.white.withValues(alpha: opacity * 0.2);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0); 
    canvas.drawPath(path, paint);

    // Layer 2: Core glow
    paint.color = Colors.white.withValues(alpha: opacity * 0.4);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0); 
    canvas.drawPath(path, paint);

    // 2. Draw Core (Solid)
    paint.color = Colors.white.withValues(alpha: opacity);
    paint.maskFilter = null; // Clear blur
    canvas.drawPath(path, paint);
  }

  Path _createStarPath(Offset center, double radius, double innerRadius) {
    final path = Path();
    final double rot = -pi / 2; // Start at top
    final double step = pi / 5;

    path.moveTo(
      center.dx + cos(rot) * radius, 
      center.dy + sin(rot) * radius
    );

    for (int i = 1; i <= 5; i++) {
       double angle = rot + step * (2 * i - 1);
       path.lineTo(
         center.dx + cos(angle) * innerRadius,
         center.dy + sin(angle) * innerRadius
       );
       angle = rot + step * 2 * i;
       path.lineTo(
         center.dx + cos(angle) * radius,
         center.dy + sin(angle) * radius
       );
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) => true;
}
