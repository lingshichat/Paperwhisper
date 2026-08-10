import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';

/// 自定义页面转场的集中定义（5 个旧文件中的 6 种 Route 类：
/// slide / fade-slide / unfold / smooth-cover / book-flip / letter-fold）。
///
/// 本文件是跨页转场的唯一真实实现，供 [AppRoutes] 与后续导航消费方
/// 复用。原 `lib/widgets/*_page_route.dart` 兼容层已随导航迁移完成删除。
///
/// 全部类保留原有构造参数、duration、curve、opaque/barrier 语义。

/// 平滑平移过渡动画路由
///
/// 新页面从右侧滑入，旧页面略微向左滑动
/// 返回时反向动画
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlidePageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(
          milliseconds: 700,
        ), // ~700ms leisurely
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
              SlideTransition(position: slideIn, child: child),
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
            child: SlideTransition(position: slideIn, child: child),
          );
        },
      );
}

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
         transitionDuration: Duration(
           milliseconds: usePerformanceMode ? 550 : 800,
         ),
         reverseTransitionDuration: Duration(
           milliseconds: usePerformanceMode ? 500 : 700,
         ),
         opaque: false,
         barrierColor: Colors.transparent,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           // 监听动画状态，完成时触发回调
           animation.addStatusListener((status) {
             if (status == AnimationStatus.completed &&
                 onAnimationComplete != null) {
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
    final source =
        sourceRect ??
        Rect.fromCenter(
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
      child: RepaintBoundary(child: child),
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
        final double contentScale = screenSize.width > 0
            ? currentRect.width / screenSize.width
            : 1.0;

        return Stack(
          children: [
            // 背景遮罩
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: (backgroundColor ?? Colors.black).withValues(
                    alpha: scrimOpacity,
                  ),
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
    final scaleAnimation =
        Tween<double>(
          begin: 1.0,
          end: 0.92, // 适当增加缩放幅度，增强层次感
        ).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeOutQuart,
          ),
        );

    final fadeAnimation =
        Tween<double>(
          begin: 1.0,
          end: 0.7, // 适当增加淡出程度，更明显的层次
        ).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeOutQuart,
          ),
        );

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
                  color: Colors.black.withValues(alpha: 0.2),
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

  const _PageFlipTransition({required this.animation, required this.child});

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

  Widget _buildFlipAnimation(
    BuildContext context,
    double progress,
    Widget child,
  ) {
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

/// 信纸对折展开过渡动画
///
/// 仿"给未来写封信"设计：
/// 动画流程改为流畅的同步过程：
/// 1. 升起、展开、放大同步进行，如同一气呵成
/// 2. 强调纸张的物理飘逸感
class LetterFoldPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  LetterFoldPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 1600), // 保持闲庭信步的速度
        reverseTransitionDuration: const Duration(milliseconds: 1400),
        opaque: false,
        barrierColor: Colors.transparent,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return _LetterFoldTransition(animation: animation, child: child);
        },
      );
}

class _LetterFoldTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _LetterFoldTransition({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final theme = settings.currentTheme;
    final colors = _getThemeColors(theme);

    // 使用 EaseOutSine 模拟纸张飘落/升起的自然阻尼
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutSine,
      reverseCurve: Curves.easeInOutCubic,
    );

    // 5. 准备静态子树 (Performance Optimization)
    final staticChild = OverflowBox(
      minWidth: screenSize.width,
      maxWidth: screenSize.width,
      minHeight: screenSize.height,
      maxHeight: screenSize.height,
      child: RepaintBoundary(child: child),
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      child: staticChild,
      builder: (context, cachedChild) {
        final double t = curvedAnimation.value;

        // --- 核心动画参数计算 ---
        // 目标：升起、变大、展开是交织在一起的

        // 1. 垂直位移: 从下方升起 (0 -> 1)
        // 纸张先快速升起，然后缓慢到位
        final double slideProgress = _clampInterval(t, 0.0, 0.6);
        final double paperY =
            (1 - Curves.easeOutCubic.transform(slideProgress)) *
            screenSize.height *
            0.5;

        // 2. 展开角度: 180度 -> 0度
        // 在位移进行到一半时开始快速展开
        final double unfoldProgress = _clampInterval(t, 0.1, 0.85);
        final double unfoldCurve = Curves.easeInOutCubic.transform(
          unfoldProgress,
        );
        final double foldAngle = math.pi * 0.95 * (1 - unfoldCurve);

        // 3. 尺寸变化: 初始尺寸 -> 全屏
        // 始终都在变大，直到最后
        final double scaleProgress = _clampInterval(t, 0.0, 1.0);
        final double scaleCurve = Curves.easeOutQuad.transform(scaleProgress);

        final double startWidth = screenSize.width * 0.72;
        final double startHeight = startWidth * 1.4; // 约为A4比例

        // 插值计算当前尺寸
        final double currentWidth = _lerp(
          startWidth,
          screenSize.width,
          scaleCurve,
        );
        final double currentHeight = _lerp(
          startHeight,
          screenSize.height,
          scaleCurve,
        );

        // 4. 内容淡入: 仅在快完全展开时淡入，避免覆盖折叠动画
        final double contentFadeStart = 0.75;
        final double contentProgress = _clampInterval(t, contentFadeStart, 1.0);
        final double contentOpacity = Curves.easeOut.transform(contentProgress);

        // 5. 辅助视觉
        final double borderRadius = 16.0 * (1 - scaleCurve); // 圆角随从变大而减小
        final double scrimOpacity = t * 0.85; // 背景遮罩渐变
        final double shadowIntensity = (1 - unfoldCurve); // 阴影随展开减弱

        return Stack(
          children: [
            // 背景遮罩
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: scrimOpacity),
                ),
              ),
            ),

            // 纸张容器
            Center(
              child: Transform.translate(
                offset: Offset(0, paperY),
                child: SizedBox(
                  width: currentWidth,
                  height: currentHeight,
                  child: Stack(
                    clipBehavior: Clip.hardEdge, // 裁剪超出部分，修复溢出警告
                    children: [
                      // --- 纸张部分 ---

                      // 1. 下半部分 (Base) - 始终静止
                      Positioned(
                        top: currentHeight / 2,
                        left: 0,
                        right: 0,
                        height: currentHeight / 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.paper,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(borderRadius),
                              bottomRight: Radius.circular(borderRadius),
                            ),
                            // 下半部分的阴影
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: 0.15 * shadowIntensity,
                                ),
                                blurRadius: 20 * shadowIntensity,
                                offset: Offset(0, 10 * shadowIntensity),
                              ),
                            ],
                          ),
                          child: _buildPaperLines(colors, currentHeight / 2),
                        ),
                      ),

                      // 2. 上半部分 (Folding Wing) - 执行折叠动画
                      // 始终保留且不透明，作为内容的背景底色，防止黑色闪烁
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: currentHeight / 2,
                        child: Transform(
                          alignment: Alignment.bottomCenter, // 以中间线为轴
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // 3D透视感
                            ..rotateX(foldAngle),
                          child: Container(
                            decoration: BoxDecoration(
                              // 根据是否翻转到背面改变颜色
                              color: foldAngle > math.pi / 2
                                  ? colors.foldedBack
                                  : colors.paper,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(borderRadius),
                                topRight: Radius.circular(borderRadius),
                              ),
                              border: Border(
                                // 给一个非常淡的边框增加质感
                                top: BorderSide(
                                  color: colors.border.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                                left: BorderSide(
                                  color: colors.border.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                                right: BorderSide(
                                  color: colors.border.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: foldAngle > math.pi / 2
                                ? null // 背面不显示线条
                                : _buildPaperLines(colors, currentHeight / 2),
                          ),
                        ),
                      ),

                      // 3. 折痕阴影 (Crease Shadow)
                      // 在折叠处添加一个动态渐变阴影，模拟纸张弯曲的光影
                      if (foldAngle > 0.1 && foldAngle < math.pi * 0.9)
                        Positioned(
                          top: currentHeight / 2 - 25,
                          left: 0,
                          right: 0,
                          height: 50,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    colors.shadow.withValues(
                                      alpha: (0.15 * shadowIntensity).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 4. 内容层 (Content)
                      // 覆盖在纸张之上
                      if (contentOpacity > 0.01)
                        Positioned.fill(
                          child: Builder(
                            builder: (context) {
                              final double contentScale = screenSize.width > 0
                                  ? currentWidth / screenSize.width
                                  : 1.0;

                              return IgnorePointer(
                                ignoring:
                                    animation.status !=
                                    AnimationStatus.completed,
                                child: Opacity(
                                  opacity: contentOpacity,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      borderRadius,
                                    ),
                                    // 核心修复：使用 manual Transform 替代 FittedBox
                                    child: Transform.scale(
                                      scale: contentScale,
                                      alignment: Alignment.topCenter,
                                      child: cachedChild!,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- 辅助方法 ---

  double _clampInterval(double value, double min, double max) {
    if (max <= min) return 0.0;
    return ((value - min) / (max - min)).clamp(0.0, 1.0);
  }

  double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  Widget _buildPaperLines(_LetterColors colors, double height) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _PaperLinesPainter(
        lineColor: colors.foldLine.withValues(alpha: 0.05),
      ),
    );
  }

  _LetterColors _getThemeColors(String theme) {
    switch (theme) {
      case AppTheme.themeMidnight:
        return _LetterColors(
          paper: const Color(0xFF1a1f2e),
          foldedBack: const Color(0xFF141824),
          border: const Color(0xFF30363d),
          shadow: const Color(0xFF000000),
          foldLine: const Color(0xFF505560),
        );
      case AppTheme.themeSeaFlower:
        return _LetterColors(
          paper: const Color(0xFFFCE4EC),
          foldedBack: const Color(0xFFF8BBD0),
          border: const Color(0xFFF48FB1),
          shadow: const Color(0xFF880E4F),
          foldLine: const Color(0xFFEC407A),
        );
      case AppTheme.themeAmberLens:
        return _LetterColors(
          paper: const Color(0xFF1E1E1E),
          foldedBack: const Color(0xFF121212),
          border: const Color(0xFFFF9800),
          shadow: Colors.black,
          foldLine: const Color(0xFFE0E0E0),
        );
      case AppTheme.themeAfterRain: // Add After Rain
        return _LetterColors(
          paper: const Color(0xFFF0F8FF), // Alice Blue
          foldedBack: const Color(0xFFE1F5FE), // Slightly darker blue
          border: Colors.white,
          shadow: const Color(0xFF81D4FA),
          foldLine: const Color(0xFFB3E5FC),
        );
      case AppTheme.themeTwilight:
        return _LetterColors(
          paper: const Color(0xFF352044),
          foldedBack: const Color(0xFF2E1A3C),
          border: const Color(0xFFFF5252), // Musubi Red
          shadow: const Color(0xFFFF5252),
          foldLine: const Color(0xFFFF5252),
        );
      case AppTheme.themeGardenOfWords:
        return _LetterColors(
          paper: const Color(0xFFF0F4F2), // Mist White
          foldedBack: const Color(0xFFE0E8E4), // Slightly darker
          border: const Color(0xFF8BC34A), // Fresh Leaf
          shadow: const Color(0xFF2E4A35), // Dark Green
          foldLine: const Color(0xFF8BC34A),
        );
      default: // Vintage
        return _LetterColors(
          paper: const Color(0xFFF4ECD8),
          foldedBack: const Color(0xFFE8DCC8),
          border: const Color(0xFFD4C4A8),
          shadow: const Color(0xFF5D4037),
          foldLine: const Color(0xFF8D6E63),
        );
    }
  }
}

class _LetterColors {
  final Color paper;
  final Color foldedBack;
  final Color border;
  final Color shadow;
  final Color foldLine;

  const _LetterColors({
    required this.paper,
    required this.foldedBack,
    required this.border,
    required this.shadow,
    required this.foldLine,
  });
}

class _PaperLinesPainter extends CustomPainter {
  final Color lineColor;

  _PaperLinesPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0; // 稍微加粗一点点，更清晰

    const lineSpacing = 28.0; // 行距加大，更有信纸感
    for (double y = lineSpacing; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(24, y), Offset(size.width - 24, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
