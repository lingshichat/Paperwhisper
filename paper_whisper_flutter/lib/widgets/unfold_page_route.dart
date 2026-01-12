import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 折纸展开过渡动画路由
/// 
/// 从卡片位置展开到全屏，返回时收折回原位置
/// 模拟纸张展开的物理效果
class UnfoldPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Rect? sourceRect; // 源卡片的位置和大小
  final Color? backgroundColor;

  UnfoldPageRoute({
    required this.page,
    this.sourceRect,
    this.backgroundColor,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 800), // Slower: 800ms
          reverseTransitionDuration: const Duration(milliseconds: 700),
          opaque: false,
          barrierColor: Colors.transparent,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _UnfoldTransition(
              animation: animation,
              sourceRect: sourceRect,
              backgroundColor: backgroundColor,
              child: child,
            );
          },
        );
}

class _UnfoldTransition extends StatelessWidget {
  final Animation<double> animation;
  final Rect? sourceRect;
  final Color? backgroundColor;
  final Widget child;

  const _UnfoldTransition({
    required this.animation,
    required this.sourceRect,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenRect = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    
    // 如果没有源位置，使用屏幕中心
    final source = sourceRect ?? Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: 200,
      height: 150,
    );

    // 缓动曲线 - 更平滑
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInQuart,
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, _) {
        final progress = curvedAnimation.value;
        
        // 1. 位置和大小插值
        final currentRect = Rect.lerp(source, screenRect, progress)!;
        
        // 2. 折纸透视效果 (前半段)
        double foldAngle = 0;
        double foldProgress = 0;
        if (progress < 0.5) {
          // 展开阶段：从折叠到展平
          foldProgress = progress * 2; // 0 -> 1
          foldAngle = math.pi * 0.15 * (1 - foldProgress); // 从有角度到0
        }
        
        // 3. 透明度
        final opacity = progress.clamp(0.0, 1.0);
        
        // 4. 背景遮罩
        final scrimOpacity = (progress * 0.6).clamp(0.0, 0.6);

        return Stack(
          children: [
            // 背景遮罩
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: (backgroundColor ?? Colors.black).withValues(alpha: scrimOpacity),
                ),
              ),
            ),
            
            // 展开的页面
            Positioned(
              left: currentRect.left,
              top: currentRect.top,
              width: currentRect.width,
              height: currentRect.height,
              child: Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // 透视
                  ..rotateX(foldAngle), // 折纸效果
                child: Opacity(
                  opacity: opacity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      _lerpDouble(12, 0, progress), // 圆角渐变消失
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t.clamp(0.0, 1.0);
  }
}

/// 获取 Widget 的全局位置和大小
/// 
/// 用于在点击卡片时获取其位置，传递给 UnfoldPageRoute
Rect? getWidgetRect(GlobalKey key) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return null;
  
  final position = renderBox.localToGlobal(Offset.zero);
  final size = renderBox.size;
  
  return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
}
