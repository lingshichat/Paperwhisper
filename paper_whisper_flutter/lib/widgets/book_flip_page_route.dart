import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 书本翻页过渡动画路由
/// 
/// 模拟翻开书本的动画：
/// - 新页面从左向右翻开
/// - 使用深色背景避免闪白
/// - 流畅的3D旋转效果
class BookFlipPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  BookFlipPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 500), // 快速流畅
          reverseTransitionDuration: const Duration(milliseconds: 450),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _PageFlipTransition(
              animation: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic, // 快速启动，平滑结束
                reverseCurve: Curves.easeInCubic,
              ),
              child: child,
            );
          },
        );
}

/// 翻页过渡组件
class _PageFlipTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _PageFlipTransition({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;
        
        // 使用透明背景，让主题背景自然显示
        return _buildFlipAnimation(context, progress, child!);
      },
      child: child,
    );
  }

  Widget _buildFlipAnimation(BuildContext context, double progress, Widget child) {
    final screenSize = MediaQuery.of(context).size;
    
    // 旋转角度：从 -90度 旋转到 0度（从左侧翻开）
    final angle = (1 - progress) * (-math.pi / 2);
    
    // 计算透视变换
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0015) // 透视强度
      ..rotateY(angle);
    
    // 动态阴影
    final shadowOpacity = ((1 - progress) * 0.5).clamp(0.0, 0.5);

    return Transform(
      alignment: Alignment.centerLeft, // 以左侧为轴旋转
      transform: transform,
      child: Container(
        width: screenSize.width,
        height: screenSize.height,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowOpacity),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
