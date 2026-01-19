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
  final VoidCallback? onAnimationComplete; // 动画完成回调（用于懒加载优化）
  final bool usePerformanceMode; // 是否启用性能模式（针对长日记）


  UnfoldPageRoute({
    required this.page,
    this.sourceRect,
    this.backgroundColor,
    this.onAnimationComplete,
    this.usePerformanceMode = false,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          // 性能模式下缩短动画时长 (550ms vs 800ms)
          transitionDuration: Duration(milliseconds: usePerformanceMode ? 550 : 800), 
          reverseTransitionDuration: Duration(milliseconds: usePerformanceMode ? 500 : 700),
          opaque: false,
          barrierColor: Colors.transparent,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 监听动画状态，完成时触发回调
            animation.addStatusListener((status) {
              if (status == AnimationStatus.completed && onAnimationComplete != null) {
                onAnimationComplete();
              }
            });
            
            return _UnfoldTransition(
              animation: animation,
              sourceRect: sourceRect,
              backgroundColor: backgroundColor,
              usePerformanceMode: usePerformanceMode,
              child: child,
            );
          },
        );
}

class _UnfoldTransition extends StatelessWidget {
  final Animation<double> animation;
  final Rect? sourceRect;
  final Color? backgroundColor;
  final bool usePerformanceMode;
  final Widget child;

  const _UnfoldTransition({
    required this.animation,
    required this.sourceRect,
    required this.backgroundColor,
    this.usePerformanceMode = false,
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

    // 5. 准备静态子树 (Performance Optimization)
    // 将 OverflowBox 和 RepaintBoundary 提前构建，作为 child 传入 AnimatedBuilder
    // 确保在动画过程中这部分子树完全不会重建/重绘，仅做变换
    final staticChild = OverflowBox(
      minWidth: screenSize.width,
      maxWidth: screenSize.width,
      minHeight: screenSize.height,
      maxHeight: screenSize.height,
      child: RepaintBoundary(
        child: child,
      ),
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      child: staticChild, // Pass static subtree here
      builder: (context, cachedChild) {
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

        // Safety check for screen size to prevent division by zero
        if (screenSize.isEmpty) return const SizedBox();

        // Calculate scale manually to avoid FittedBox infinite scale issues
        final double contentScale = screenSize.width > 0 ? currentRect.width / screenSize.width : 1.0;

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
              child: IgnorePointer(
                ignoring: animation.status != AnimationStatus.completed,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // 透视
                    ..rotateX(foldAngle), // 折纸效果
                  child: Opacity(
                    opacity: opacity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        // 智能分级策略：
                        // 性能模式（长日记）：全程固定圆角，利用 Raster Cache
                        // 全特效模式（短日记）：动态渐变圆角，追求极致视觉
                        usePerformanceMode 
                            ? (progress >= 0.99 ? 0 : 12.0)
                            : _lerpDouble(12, 0, progress), 
                      ),
                      // 核心修复：使用 manual Transform + OverflowBox 替代 FittedBox
                      // 更加稳健，避免 'scaleX.isFinite' 断言错误
                      child: Transform.scale(
                        scale: contentScale,
                        alignment: Alignment.topCenter,
                        child: cachedChild!, 
                      ),
                    ),
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
