import 'package:flutter/material.dart';

/// 从下向上丝滑覆盖过渡动画路由
/// 
/// 特点：
/// - 新页面从屏幕底部平滑滑入，覆盖在旧页面上
/// - 旧页面保持不动或微微缩放淡出，增强层次感
/// - 使用快速启动、平滑减速的曲线，丝滑自然
class SmoothCoverPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SmoothCoverPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 700), // 优雅从容的节奏
          reverseTransitionDuration: const Duration(milliseconds: 600), // 返回稍快
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _SmoothCoverTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
        );
}

/// 丝滑覆盖过渡组件
class _SmoothCoverTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _SmoothCoverTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // 前进动画：新页面滑入
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart, // 优雅的四次方缓动，匹配项目风格
      reverseCurve: Curves.easeInQuart, // 返回时对称曲线
    );

    // 旧页面的缩放和淡出动画（当前页面被新页面覆盖时）
    final scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92, // 适当增加缩放幅度，增强层次感
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutQuart,
    ));

    final fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7, // 适当增加淡出程度，更明显的层次
    ).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutQuart,
    ));

    return Stack(
      children: [
        // 旧页面：缩放 + 淡出
        if (secondaryAnimation.status != AnimationStatus.dismissed)
          ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: Container(), // 占位，实际内容由 Navigator 管理
            ),
          ),
        
        // 新页面：从底部滑入 + 半透明遮罩
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0), // 从屏幕底部外
            end: Offset.zero, // 滑动到正常位置
          ).animate(curvedAnimation),
          child: Container(
            decoration: BoxDecoration(
              // 添加半透明遮罩，增强层次感
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
