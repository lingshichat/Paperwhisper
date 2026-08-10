import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PostmarkStamp extends StatelessWidget {
  final DateTime date;
  final double size;
  final Color color;

  const PostmarkStamp({
    super.key,
    required this.date,
    this.size = 100,
    this.color = const Color(
      0xCCBF360C,
    ), // Deep Orange/Red, slightly transparent
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -math.pi / 12, // Slight tilt for realism
      child: CustomPaint(
        size: Size(size, size),
        painter: _StampPainter(date: date, color: color),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  final DateTime date;
  final Color color;

  _StampPainter({required this.date, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.5);

    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // 1. Double Circle Border
    canvas.drawCircle(center, radius - 2, paint);

    final Paint innerPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 6, innerPaint);

    // 2. Stars at Top (Three Stars: Left, Center Big, Right)
    final starPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Helper to draw star
    void drawStar(Canvas c, Offset center, double r) {
      Path path = Path();
      for (int i = 0; i < 5; i++) {
        double angle = -math.pi / 2 + i * 4 * math.pi / 5;
        double x = center.dx + r * math.cos(angle);
        double y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      // Fill star slightly hollow look? No, fill is better for stamp.
      // But user wants outline feeling? "Postmark". Maybe stroke?
      // Let's use Fill with some transparency or Stroke.
      // User said "Mark". Stamps are usually solid ink.
      // Let's use solid.
      c.drawPath(path, starPaint);
    }

    // Top Arc position
    // Center Star
    drawStar(
      canvas,
      Offset(center.dx, center.dy - radius * 0.55),
      size.width * 0.08,
    ); // Big
    // Left Star
    drawStar(
      canvas,
      Offset(center.dx - radius * 0.4, center.dy - radius * 0.4),
      size.width * 0.05,
    ); // Small
    // Right Star
    drawStar(
      canvas,
      Offset(center.dx + radius * 0.4, center.dy - radius * 0.4),
      size.width * 0.05,
    ); // Small

    // 3. Center Text: "PAPER WHISPER"
    // Split into two lines if needed, or small.
    // "PAPER WHISPER"
    final TextPainter textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.text = TextSpan(
      text: "PAPER\nWHISPER",
      style: GoogleFonts.oswald(
        fontSize: size.width * 0.14,
        color: color,
        fontWeight: FontWeight.bold,
        height: 1.0,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 + 5,
      ),
    ); // Slightly adjusted due to stars

    // 4. Date (Bottom Curve - simulated with straight text for simplicity or curve?)
    // User wants "Postcard stamp". Bottom curved text is classic.
    // Let's try simple straight text at bottom first to ensure it renders safely,
    // or use canvas rotate for each char.
    // Let's use straight text at bottom for robustness for now.
    String dateStr =
        "${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}";

    textPainter.text = TextSpan(
      text: dateStr,
      style: GoogleFonts.courierPrime(
        fontSize: size.width * 0.09, // Smaller font size
        color: color,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + radius * 0.45),
    );

    // 5. Texture
    final grungePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    final random = math.Random(date.millisecondsSinceEpoch);
    for (int i = 0; i < 40; i++) {
      double dx = random.nextDouble() * size.width;
      double dy = random.nextDouble() * size.height;
      if (_isInsideCircle(dx, dy, center, radius)) {
        canvas.drawCircle(
          Offset(dx, dy),
          random.nextDouble() * 1.5,
          grungePaint,
        );
      }
    }
  }

  bool _isInsideCircle(double x, double y, Offset c, double r) {
    return math.pow(x - c.dx, 2) + math.pow(y - c.dy, 2) <= math.pow(r, 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
