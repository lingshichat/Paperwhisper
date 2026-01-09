import 'package:flutter/material.dart';

class SkeuomorphicContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final Border? border;
  final VoidCallback? onTap;

  const SkeuomorphicContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.gradient,
    this.shadows,
    this.border,
    this.onTap,
  });

  factory SkeuomorphicContainer.paper({
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
    Color bgColor = const Color(0xFFF4ECD8),
    List<BoxShadow>? shadows,
  }) {
    return SkeuomorphicContainer(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      color: bgColor,
      shadows: shadows ?? const [
         BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.3),
          blurRadius: 20,
          offset: Offset(0, 10),
          spreadRadius: -5,
        ),
      ],
      child: child,
    );
  }
  
  factory SkeuomorphicContainer.inset({
    required Widget child,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    BorderRadius? borderRadius,
  }) {
    return SkeuomorphicContainer(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius ?? BorderRadius.circular(4),
      color: const Color(0x1A000000),
      border: Border.all(color: Colors.black12, width: 1.0),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: shadows,
        border: border,
      ),
      child: child,
    );
    
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    
    return content;
  }
}
