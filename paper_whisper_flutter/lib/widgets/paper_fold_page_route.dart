import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/settings_provider.dart';

/// 信纸对折展开过渡动画
/// 
/// 仿"给未来写封信"设计：
/// 动画流程改为流畅的同步过程：
/// 1. 升起、展开、放大同步进行，如同一气呵成
/// 2. 强调纸张的物理飘逸感
class LetterFoldPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  LetterFoldPageRoute({
    required this.page,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 1600), // 保持闲庭信步的速度
          reverseTransitionDuration: const Duration(milliseconds: 1400),
          opaque: false,
          barrierColor: Colors.transparent,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _LetterFoldTransition(
              animation: animation,
              child: child,
            );
          },
        );
}

class _LetterFoldTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _LetterFoldTransition({
    required this.animation,
    required this.child,
  });

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
      child: RepaintBoundary(
        child: child,
      ),
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
        final double paperY = (1 - Curves.easeOutCubic.transform(slideProgress)) * screenSize.height * 0.5;

        // 2. 展开角度: 180度 -> 0度
        // 在位移进行到一半时开始快速展开
        final double unfoldProgress = _clampInterval(t, 0.1, 0.85);
        final double unfoldCurve = Curves.easeInOutCubic.transform(unfoldProgress);
        final double foldAngle = math.pi * 0.95 * (1 - unfoldCurve);

        // 3. 尺寸变化: 初始尺寸 -> 全屏
        // 始终都在变大，直到最后
        final double scaleProgress = _clampInterval(t, 0.0, 1.0);
        final double scaleCurve = Curves.easeOutQuad.transform(scaleProgress);
        
        final double startWidth = screenSize.width * 0.72;
        final double startHeight = startWidth * 1.4; // 约为A4比例
        
        // 插值计算当前尺寸
        final double currentWidth = _lerp(startWidth, screenSize.width, scaleCurve);
        final double currentHeight = _lerp(startHeight, screenSize.height, scaleCurve);

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
                                color: Colors.black.withValues(alpha: 0.15 * shadowIntensity),
                                blurRadius: 20 * shadowIntensity,
                                offset: Offset(0, 10 * shadowIntensity),
                              )
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
                              color: foldAngle > math.pi / 2 ? colors.foldedBack : colors.paper,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(borderRadius),
                                topRight: Radius.circular(borderRadius),
                              ),
                              border: Border(
                                // 给一个非常淡的边框增加质感
                                top: BorderSide(color: colors.border.withValues(alpha: 0.3), width: 0.5),
                                left: BorderSide(color: colors.border.withValues(alpha: 0.3), width: 0.5),
                                right: BorderSide(color: colors.border.withValues(alpha: 0.3), width: 0.5),
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
                                    colors.shadow.withValues(alpha: (0.15 * shadowIntensity).clamp(0.0, 1.0)), 
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
                        // 4. 内容层 (Content)
                      // 覆盖在纸张之上
                        // 4. 内容层 (Content)
                      // 覆盖在纸张之上
                      if (contentOpacity > 0.01)
                        Positioned.fill(
                           child: Builder( // 使用 Builder 获取 constraints 上下文，或者直接使用 screenSize
                             builder: (context) {
                               // Calculate explicit scale
                               // 信纸动画中，container 宽度已经在变化 (currentWidth)，我们希望内容是以 screenSize 为基础缩放适配 currentWidth
                               // 但是这里 currentWidth 是 Container 的宽度。
                               // 我们的目标是: Content 固定 width=screenSize.width (或 700px on desktop?)
                               // 
                               // 之前 LetterFoldPageRoute 中的 child 是 _LetterFoldTransition 的 child，即 EditorPage。
                               // 这里的布局逻辑：
                               // Container (currentWidth, currentHeight)
                               //   -> Stack
                               //     -> Positioned.fill
                               //       -> Opacity
                               //         -> ClipRRect
                               //           -> FittedBox (OLD) / Transform (NEW)
                               //             -> OverflowBox(screenSize) -> Child
                               
                               final double contentScale = screenSize.width > 0 ? currentWidth / screenSize.width : 1.0;

                               return IgnorePointer(
                                 ignoring: animation.status != AnimationStatus.completed,
                                 child: Opacity(
                                   opacity: contentOpacity,
                                   child: ClipRRect(
                                     borderRadius: BorderRadius.circular(borderRadius),
                                     // 核心修复：使用 manual Transform 替代 FittedBox
                                     child: Transform.scale(
                                       scale: contentScale,
                                       alignment: Alignment.topCenter,
                                       child: cachedChild!,
                                     ),
                                   ),
                                 ),
                               );
                             }
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
      painter: _PaperLinesPainter(lineColor: colors.foldLine.withValues(alpha: 0.05)),
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
      canvas.drawLine(
        Offset(24, y),
        Offset(size.width - 24, y),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
