import 'dart:math';
import 'package:flutter/material.dart';

class CassetteWheel extends AnimatedWidget {
  final double size;

  const CassetteWheel({
    super.key,
    required Animation<double> turns,
    this.size = 40,
  }) : super(listenable: turns);

  Animation<double> get turns => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: turns.value * 2 * pi,
      child: CustomPaint(size: Size(size, size), painter: _ReelPainter()),
    );
  }
}

class _ReelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Reel Body (White Plastic)
    final Paint bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFEEEEEE);
    canvas.drawCircle(center, radius, bodyPaint);

    // 2. Spokes/Teeth visual (6 notches)
    final Paint notchPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.fill;

    final int holesCount = 6;
    final double holeDistance = radius * 0.65;
    final double holeSize = radius * 0.15;

    for (int i = 0; i < holesCount; i++) {
      double angle = (2 * pi / holesCount) * i;
      double hx = center.dx + cos(angle) * holeDistance;
      double hy = center.dy + sin(angle) * holeDistance;

      // Draw little holes
      canvas.drawCircle(Offset(hx, hy), holeSize, notchPaint);
    }

    // 3. Inner Drive Hub (Star/Toothed Shape)
    // Draw a small dark circle with white teeth
    final double hubRadius = radius * 0.3;
    final Paint hubPaint = Paint()..color = const Color(0xFFDDDDDD);
    canvas.drawCircle(center, hubRadius, hubPaint);

    // Draw Axle Hole (Dark)
    canvas.drawCircle(
      center,
      radius * 0.15,
      Paint()..color = const Color(0xFF333333),
    );

    // 4. Subtle Shading/Ring
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black12
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.9, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
