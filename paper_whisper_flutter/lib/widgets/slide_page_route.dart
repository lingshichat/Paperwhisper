import 'package:flutter/material.dart';

/// 平滑平移过渡动画路由
/// 
/// 新页面从右侧滑入，旧页面略微向左滑动
/// 返回时反向动画
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlidePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 700), // ~700ms leisurely
          reverseTransitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 使用缓动曲线使动画更自然
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            );

            // 新页面从右侧滑入
            final slideIn = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation);

            // 旧页面略微向左滑动（视差效果）
            final slideOut = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.3, 0.0),
            ).animate(curvedAnimation);

            // 旧页面略微变暗
            final fadeOut = Tween<double>(
              begin: 1.0,
              end: 0.9,
            ).animate(curvedAnimation);

            return Stack(
              children: [
                // 旧页面（下层）- 向左滑动并略微变暗
                SlideTransition(
                  position: slideOut,
                  child: FadeTransition(
                    opacity: fadeOut,
                    child: Container(), // 占位，实际由 secondaryAnimation 处理
                  ),
                ),
                // 新页面（上层）- 从右侧滑入
                SlideTransition(
                  position: slideIn,
                  child: child,
                ),
              ],
            );
          },
        );
}

/// 淡入平移过渡（适合设置页等）
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeSlidePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600), // Slower: 600ms
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
              reverseCurve: Curves.easeInQuart,
            );

            // 从底部略微上滑
            final slideIn = Tween<Offset>(
              begin: const Offset(0.0, 0.08),
              end: Offset.zero,
            ).animate(curvedAnimation);

            // 淡入
            final fadeIn = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(curvedAnimation);

            return FadeTransition(
              opacity: fadeIn,
              child: SlideTransition(
                position: slideIn,
                child: child,
              ),
            );
          },
        );
}
