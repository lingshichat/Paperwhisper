import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

// --- Petal Rain Effect ---

class PetalRainWidget extends StatefulWidget {
  final bool burst; // Enable explosion effect on start

  const PetalRainWidget({super.key, this.burst = false});

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
    
    // 初始化
    if (widget.burst) {
      // 侧边爆炸模式 (Confetti Cannons)
      // 左侧发射
      for (int i = 0; i < 40; i++) {
        _petals.add(_generateSideBurstPetal(true));
      }
      // 右侧发射
      for (int i = 0; i < 40; i++) {
        _petals.add(_generateSideBurstPetal(false));
      }
      // 同时添加少量自然下落的，保证延续性
      for (int i = 0; i < 10; i++) {
        _petals.add(_generatePetal(true));
      }
    } else {
      // 普通模式：均匀分布
      for (int i = 0; i < 25; i++) {
          _petals.add(_generatePetal(true));
      }
    }

    _controller = AnimationController(
             vsync: this, 
             duration: const Duration(seconds: 1)
           )..addListener(_updatePetals)
            ..repeat();
  }

  void _updatePetals() {
    // 持续生成新花瓣逻辑 (Rain)
    if (_random.nextDouble() < 0.05 && _petals.length < 100) {
       _petals.add(_generatePetal(false));
    }

    for (var petal in _petals) {
      // 检查是否有物理加速度 (爆炸产生的)
      if (petal.vx != 0 || petal.vy != 0) {
        // 物理模拟
        petal.x += petal.vx;
        petal.y += petal.vy;
        
        // 重力
        petal.vy += 0.0005; // Gravity
        
        // 空气阻力
        petal.vx *= 0.98;
        petal.vy *= 0.98;
        
        // 旋转跟随速度
        petal.rotation += _random.nextDouble() * 0.1;
        
        // 渐隐
        if (petal.opacity < petal.maxOpacity) {
            petal.opacity += 0.05;
        }
        // 如果落到底部或飞出边界，重置为普通下落花瓣
        if (petal.y > 1.2 || petal.x < -0.2 || petal.x > 1.2) {
           _resetPetal(petal);
        }
      } else {
        // 普通下落逻辑
        // 1. 更新Y轴下落 (Linear)
        petal.y += petal.speed;
        
        // 计算进度 (Progress 0.0 -> 1.0)
        // Range: -0.2 (Start) to 1.15 (End) -> span = 1.35
        final double progress = (petal.y - (-0.2)) / 1.35;
        
        // 2. 复刻 CSS Keyframes: Sway (X轴偏移)
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
      maxOpacity: 0.4 + _random.nextDouble() * 0.4, // Increased opacity slightly
      color: _getRandomColor(),
      vx: 0,
      vy: 0,
    );
  }

  Petal _generateSideBurstPetal(bool isLeft) {
    // 侧边大炮：从屏幕两侧下方 (Y=0.7) 向内上方发射
    final double startX = isLeft ? -0.1 : 1.1;
    final double startY = 0.6 + _random.nextDouble() * 0.2; // 0.6 ~ 0.8
    
    // 发射角度：
    // 左侧: -80度(向上) ~ -10度(向右) -> rad: -1.4 ~ -0.2
    // 右侧: -170度(向左) ~ -100度(向上) -> rad: -3.0 ~ -1.7
    final double angle = isLeft 
        ? -1.4 + _random.nextDouble() * 1.2
        : -3.0 + _random.nextDouble() * 1.3;
        
    final double speed = 0.015 + _random.nextDouble() * 0.025; // High initial speed
    
    return Petal(
      x: startX,
      y: startY, 
      size: 20 + _random.nextDouble() * 30, 
      speed: 0, 
      maxOpacity: 0.8 + _random.nextDouble() * 0.2, 
      color: _getRandomColor(),
      vx: cos(angle) * speed * 0.6, // Aspect ratio fix
      vy: sin(angle) * speed,
    )..opacity = 1.0; // Start fully visible
  }

  void _resetPetal(Petal petal) {
    petal.y = -0.2; // Reset to top
    petal.x = _random.nextDouble();
    petal.maxOpacity = 0.2 + _random.nextDouble() * 0.4;
    petal.speed = 0.0003 + _random.nextDouble() * 0.0005;
    petal.color = _getRandomColor();
    petal.rotation = 0;
    petal.swayX = 0;
    petal.vx = 0;
    petal.vy = 0;
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
  
  // Physics for explosion
  double vx = 0; // Velocity X
  double vy = 0; // Velocity Y

  Petal({
    required this.x, 
    required this.y, 
    required this.size, 
    required this.speed, 
    required this.maxOpacity, 
    required this.color, 
    this.vx = 0,
    this.vy = 0,
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
          // 移除阴影以大幅提升移动端性能
          // shadows: [
          //   BoxShadow(
          //     color: const Color(0xFFF06292).withValues(alpha: 0.3),
          //     blurRadius: 4,
          //     offset: const Offset(0, 2),
          //   )
          // ],
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

    // 2. 初始化悬挂星星 (Hanging Stars) - 均匀分布
    int starCount = 8;
    for (int i = 0; i < starCount; i++) {
        // 将屏幕水平分为 8 等份，每个星星占据一份
        double segmentWidth = 1.0 / starCount;
        double startX = i * segmentWidth;
        
        // 在该份内随机偏移 (留出 10% 边距避免太靠边)
        double validWidth = segmentWidth * 0.8;
        double offset = segmentWidth * 0.1;
        
        _hangingStars.add(HangingStar(
            x: startX + offset + _random.nextDouble() * validWidth, 
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
    // 1. Draw Glow using RadialGradient (Much cheaper than MaskFilter.blur)
    final glowRadius = radius * 3.0;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: opacity * 0.4), // Core glow
          Colors.white.withValues(alpha: 0.0), // Fade out
        ],
        stops: const [0.1, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, glowPaint);

    // 2. Draw Core (Solid)
    paint.color = Colors.white.withValues(alpha: opacity);
    paint.maskFilter = null; // Ensure no blur
    // Use fill for core
    paint.style = PaintingStyle.fill;
    
    final path = _createStarPath(center, radius, radius * 0.4);
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
