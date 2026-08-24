import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// --- Petal Rain Effect ---

class PetalRainWidget extends StatefulWidget {
  final bool burst; // Enable explosion effect on start

  const PetalRainWidget({super.key, this.burst = false});

  @override
  State<PetalRainWidget> createState() => _PetalRainWidgetState();
}

class _PetalRainWidgetState extends State<PetalRainWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Petal> _petals = [];
  int _frameId = 0; // 帧计数器，用于优化 shouldRepaint
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

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_updatePetals)
          ..repeat();
  }

  void _updatePetals() {
    _frameId++; // 递增帧号
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
      maxOpacity:
          0.4 + _random.nextDouble() * 0.4, // Increased opacity slightly
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

    final double speed =
        0.015 + _random.nextDouble() * 0.025; // High initial speed

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
      Color(0xFFF8BBD0),
      Color(0xFFF48FB1),
      Color(0xFFE1BEE7),
      Color(0xFFCE93D8),
      Color(0xFFFFE5F1),
      Color(0xFFF3E5F5),
      Color(0xFFEC407A),
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
          return CustomPaint(
            painter: PetalPainter(_petals, _frameId),
            size: Size.infinite,
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
  final int frameId;

  PetalPainter(this.petals, this.frameId);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var petal in petals) {
      if (petal.opacity <= 0.01) continue;

      canvas.save();

      // 位置计算
      final dx = petal.x * size.width + petal.swayX;
      final dy = petal.y * size.height;

      canvas.translate(dx, dy);
      canvas.rotate(petal.rotation);

      // 获取缓存的 TextPainter
      // 优化：使用简单的几何图形代替 TextPainter 绘制花瓣
      // TextPainter 在每一帧大量创建会导致 Texture 上传开销

      final double petalSize = petal.size;
      final double radius = petalSize / 2;
      final double petalRadius = radius * 0.4;
      final double centerRadius = radius * 0.25;

      // 花瓣颜色 (带透明度)
      paint.color = petal.color.withValues(alpha: petal.opacity);
      paint.style = PaintingStyle.fill;

      // 绘制5片花瓣
      for (int i = 0; i < 5; i++) {
        final double angle = (i * 72) * pi / 180;
        final double ox = cos(angle) * (radius * 0.5);
        final double oy = sin(angle) * (radius * 0.5);
        canvas.drawCircle(Offset(ox, oy), petalRadius, paint);
      }

      // 绘制花蕊 (稍微浅一点的颜色)
      paint.color = Colors.white.withValues(alpha: petal.opacity * 0.8);
      canvas.drawCircle(Offset.zero, centerRadius, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant PetalPainter oldDelegate) {
    return oldDelegate.frameId != frameId;
  }
}

// --- After Rain Effect ---

class AfterRainVisuals extends StatelessWidget {
  const AfterRainVisuals({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          // 可以在这里添加一些下雨后的环境效果，如微小的水滴闪烁
        ],
      ),
    );
  }
}

// --- Starry Sky Effect ---

const int _backgroundStarCount = 100;
const int _hangingStarCount = 8;
const int _starSpriteCount = _backgroundStarCount + _hangingStarCount;
const int _starTextureSize = 384;
const double _starTextureCenter = _starTextureSize / 2;
const double _starTextureCoreRadius = _starTextureSize / 6;

class StarrySkyWidget extends StatefulWidget {
  const StarrySkyWidget({super.key});

  @override
  State<StarrySkyWidget> createState() => _StarrySkyWidgetState();
}

class _StarrySkyWidgetState extends State<StarrySkyWidget>
    with SingleTickerProviderStateMixin {
  final List<Star> _stars = [];
  final List<HangingStar> _hangingStars = [];
  final Random _random = Random(42);

  late final AnimationController _controller;
  late final Stopwatch _clock;
  late final ui.Image _starTexture;
  late final StarPainter _painter;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _backgroundStarCount; i++) {
      _stars.add(
        Star(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          radius: _random.nextDouble() * 1.5 + 0.5,
          baseOpacity: _random.nextDouble() * 0.4 + 0.1,
          twinkleOffset: _random.nextDouble() * 2 * pi,
          twinkleSpeed: 0.5 + _random.nextDouble() * 1.5,
        ),
      );
    }

    for (int i = 0; i < _hangingStarCount; i++) {
      final segmentWidth = 1.0 / _hangingStarCount;
      final startX = i * segmentWidth;

      // 在该份内随机偏移 (留出 10% 边距避免太靠边)
      final validWidth = segmentWidth * 0.8;
      final offset = segmentWidth * 0.1;

      _hangingStars.add(
        HangingStar(
          x: startX + offset + _random.nextDouble() * validWidth,
          y: 0.1 + _random.nextDouble() * 0.5,
          size: 8.0 + _random.nextDouble() * 6.0,
          swaySpeed: 0.5 + _random.nextDouble() * 0.5,
          swayOffset: _random.nextDouble() * 2 * pi,
          lineLength: 0.0,
        ),
      );
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _clock = Stopwatch()..start();
    _starTexture = _createStarTexture();
    _painter = StarPainter(
      stars: _stars,
      hangingStars: _hangingStars,
      starTexture: _starTexture,
      clock: _clock,
      repaint: _controller,
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _clock.stop();
    _starTexture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _painter, size: Size.infinite),
      ),
    );
  }
}

ui.Image _createStarTexture() {
  const center = Offset(_starTextureCenter, _starTextureCenter);
  const glowRadius = _starTextureCenter;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final glowShader = const RadialGradient(
    colors: [Color.fromRGBO(255, 255, 255, 0.4), Colors.transparent],
    stops: [0.1, 1.0],
  ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
  final glowPaint = Paint()..shader = glowShader;

  canvas.drawCircle(center, glowRadius, glowPaint);
  canvas.drawPath(
    _createStarPath(
      center,
      _starTextureCoreRadius,
      _starTextureCoreRadius * 0.4,
    ),
    Paint()..color = Colors.white,
  );

  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(_starTextureSize, _starTextureSize);
  } finally {
    picture.dispose();
    glowShader.dispose();
  }
}

Path _createStarPath(Offset center, double radius, double innerRadius) {
  final path = Path();
  const rotation = -pi / 2;
  const step = pi / 5;

  path.moveTo(
    center.dx + cos(rotation) * radius,
    center.dy + sin(rotation) * radius,
  );
  for (int i = 1; i <= 5; i++) {
    var angle = rotation + step * (2 * i - 1);
    path.lineTo(
      center.dx + cos(angle) * innerRadius,
      center.dy + sin(angle) * innerRadius,
    );
    angle = rotation + step * 2 * i;
    path.lineTo(
      center.dx + cos(angle) * radius,
      center.dy + sin(angle) * radius,
    );
  }
  return path..close();
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
  StarPainter({
    required this.stars,
    required this.hangingStars,
    required ui.Image starTexture,
    required Stopwatch clock,
    required Listenable repaint,
  }) : _starTexture = starTexture,
       _clock = clock,
       _transforms = Float32List(_starSpriteCount * 4),
       _sourceRects = Float32List(_starSpriteCount * 4),
       _colors = Int32List(_starSpriteCount),
       super(repaint: repaint) {
    for (int i = 0; i < _starSpriteCount; i++) {
      final offset = i * 4;
      _sourceRects[offset] = 0;
      _sourceRects[offset + 1] = 0;
      _sourceRects[offset + 2] = _starTextureSize.toDouble();
      _sourceRects[offset + 3] = _starTextureSize.toDouble();
    }
  }

  final List<Star> stars;
  final List<HangingStar> hangingStars;
  final ui.Image _starTexture;
  final Stopwatch _clock;
  final Float32List _transforms;
  final Float32List _sourceRects;
  final Int32List _colors;
  final Path _hangingLines = Path();
  final Paint _atlasPaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _linePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.1)
    ..strokeWidth = 1
    ..isAntiAlias = true;
  Size? _layoutSize;

  @override
  void paint(Canvas canvas, Size size) {
    final time = _clock.elapsedMicroseconds / Duration.microsecondsPerSecond;
    if (_layoutSize != size) {
      _updateBackgroundTransforms(size);
      _layoutSize = size;
    }

    for (int i = 0; i < stars.length; i++) {
      final star = stars[i];
      final double wave = sin(time * star.twinkleSpeed + star.twinkleOffset);
      final double opacityRatio = 0.5 * (1 + wave);
      final double currentOpacity =
          star.baseOpacity + (opacityRatio * (1.0 - star.baseOpacity));
      _colors[i] = _alphaColor(currentOpacity);
    }

    _hangingLines.reset();
    for (int i = 0; i < hangingStars.length; i++) {
      final hStar = hangingStars[i];
      final double sway = sin(time * hStar.swaySpeed + hStar.swayOffset) * 5.0;
      final double startX = hStar.x * size.width;
      final double targetX = startX + sway;
      final double targetY = hStar.y * size.height;

      _hangingLines
        ..moveTo(startX, 0)
        ..lineTo(targetX, targetY - hStar.size);

      final spriteIndex = stars.length + i;
      _updateTransform(
        spriteIndex,
        centerX: targetX,
        centerY: targetY,
        radius: hStar.size,
      );
      final double wave = sin(time * 0.8 + hStar.swayOffset);
      _colors[spriteIndex] = _alphaColor(0.75 + 0.25 * wave);
    }

    canvas.drawPath(_hangingLines, _linePaint);
    canvas.drawRawAtlas(
      _starTexture,
      _transforms,
      _sourceRects,
      _colors,
      BlendMode.srcIn,
      Offset.zero & size,
      _atlasPaint,
    );
  }

  void _updateBackgroundTransforms(Size size) {
    for (int i = 0; i < stars.length; i++) {
      final star = stars[i];
      _updateTransform(
        i,
        centerX: star.x * size.width,
        centerY: star.y * size.height,
        radius: star.radius,
      );
    }
  }

  void _updateTransform(
    int index, {
    required double centerX,
    required double centerY,
    required double radius,
  }) {
    final scale = radius / _starTextureCoreRadius;
    final halfExtent = _starTextureCenter * scale;
    final offset = index * 4;
    _transforms[offset] = scale;
    _transforms[offset + 1] = 0;
    _transforms[offset + 2] = centerX - halfExtent;
    _transforms[offset + 3] = centerY - halfExtent;
  }

  int _alphaColor(double opacity) {
    final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
    return alpha << 24;
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) => false;
}
