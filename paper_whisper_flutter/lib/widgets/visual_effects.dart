import 'dart:math';
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
    // Initialize petals
    for (int i = 0; i < 40; i++) {
        _petals.add(_generatePetal(true)); // Start randomly on screen
    }

    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 1)
    )..addListener(_updatePetals)
     ..repeat();
  }

  void _updatePetals() {
    for (var petal in _petals) {
      // Update position logic
      petal.y += petal.speed;
      petal.rotation += petal.rotationSpeed;
      petal.x += sin(petal.y * 10) * 0.001; // Gentle sway

      // Reset if out of bounds
      if (petal.y > 1.1) {
         _resetPetal(petal);
      }
    }
  }

  Petal _generatePetal(bool randomY) {
    return Petal(
      x: _random.nextDouble(),
      y: randomY ? _random.nextDouble() : -0.1,
      size: 10 + _random.nextDouble() * 20,
      speed: 0.002 + _random.nextDouble() * 0.003,
      opacity: 0.4 + _random.nextDouble() * 0.5,
      color: _getRandomColor(),
      rotation: _random.nextDouble() * 2 * pi,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.05,
    );
  }

  void _resetPetal(Petal petal) {
    petal.y = -0.1;
    petal.x = _random.nextDouble();
    petal.rotation = _random.nextDouble() * 2 * pi;
    // Keep other properties or randomize them too if desired
  }

  Color _getRandomColor() {
     const colors = [
        Color(0xFFF8BBD0), Color(0xFFF48FB1), Color(0xFFE1BEE7),
        Color(0xFFCE93D8), Color(0xFFFFE5F1), Color(0xFFF3E5F5)
     ];
     return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.stop(); // Explicitly stop animation
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder listens to controller and rebuilds CustomPaint
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return RepaintBoundary(
          child: CustomPaint(
            painter: PetalPainter(_petals),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class Petal {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  Color color;
  double rotation;
  double rotationSpeed;

  Petal({
    required this.x, 
    required this.y, 
    required this.size, 
    required this.speed, 
    required this.opacity, 
    required this.color, 
    required this.rotation, 
    required this.rotationSpeed
  });
}

class PetalPainter extends CustomPainter {
  final List<Petal> petals;

  PetalPainter(this.petals);

  @override
  void paint(Canvas canvas, Size size) {
    for (var petal in petals) {
      final paint = Paint()
        ..color = petal.color.withValues(alpha: petal.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(petal.x * size.width, petal.y * size.height);
      canvas.rotate(petal.rotation);
      
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: petal.size, height: petal.size * 0.6), 
        paint
      );
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Always repaint for animation
}

// --- Starry Sky Effect ---

class StarrySkyWidget extends StatefulWidget {
  const StarrySkyWidget({super.key});

  @override
  State<StarrySkyWidget> createState() => _StarrySkyWidgetState();
}

class _StarrySkyWidgetState extends State<StarrySkyWidget> {
  final List<Star> _stars = [];
  final Random _random = Random(42); // Fixed seed for consistency

  @override
  void initState() {
    super.initState();
    // Pre-calculate stars
    for (int i = 0; i < 100; i++) {
       _stars.add(Star(
         x: _random.nextDouble(),
         y: _random.nextDouble(),
         radius: _random.nextDouble() * 1.5,
         opacity: _random.nextDouble(),
       ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: StarPainter(_stars),
        size: Size.infinite,
      ),
    );
  }
}

class Star {
  final double x;
  final double y;
  final double radius;
  final double opacity;

  Star({required this.x, required this.y, required this.radius, required this.opacity});
}

class StarPainter extends CustomPainter {
  final List<Star> stars;

  StarPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    
    for (var star in stars) {
       paint.color = Colors.white.withValues(alpha: star.opacity);
       // Use stored relative coordinates * current size
       canvas.drawCircle(Offset(star.x * size.width, star.y * size.height), star.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
