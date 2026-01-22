
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedFingerprint extends StatelessWidget {
  final double size;
  final Color color;

  const AnimatedFingerprint({
    super.key,
    this.size = 80,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        color,
        BlendMode.srcIn,
      ),
      child: Lottie.asset(
         'assets/illustrations/fingerprint.json',
         width: size,
         height: size,
         fit: BoxFit.contain,
         animate: true,
         repeat: false, // Play once on entry
      ),
    );
  }
}
