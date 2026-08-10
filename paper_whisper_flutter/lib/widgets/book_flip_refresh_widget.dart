import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme/theme_registry.dart';

/// 刷新状态
enum BookRefreshStatus {
  idle,
  pulling,
  armed,
  refreshing,
  done,
  failed,
}

/// 下拉二楼刷新组件
/// 
/// 效果：下拉时内容下沉，顶部露出刷新区域展示翻书动画
class BookFlipRefreshWidget extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String theme;
  final VoidCallback? onLongRefreshTap; // Callback for the link
  
  const BookFlipRefreshWidget({
    super.key,
    required this.child,
    required this.onRefresh,
    required this.theme,
    this.onLongRefreshTap,
  });

  @override
  State<BookFlipRefreshWidget> createState() => _BookFlipRefreshWidgetState();
}

class _BookFlipRefreshWidgetState extends State<BookFlipRefreshWidget>
    with TickerProviderStateMixin {
  
  // 下拉偏移量
  double _dragOffset = 0.0;
  // 刷新状态
  BookRefreshStatus _status = BookRefreshStatus.idle;
  // 翻页动画控制器
  late AnimationController _pageFlipController;
  // 回弹动画控制器
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  
  // Long refresh state
  bool _showLongRefreshLink = false;
  Timer? _longRefreshTimer;
  
  // 阈值
  static const double _triggerOffset = 100.0;
  static const double _maxDragOffset = 180.0;
  static const double _refreshAreaHeight = 150.0; // Increased height for link space

  @override
  void initState() {
    super.initState();
    // 翻页动画周期加长，更平滑
    _pageFlipController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _bounceController = AnimationController(vsync: this);
    _bounceAnimation = Tween<double>(begin: 0, end: 0).animate(_bounceController);
  }

  @override
  void dispose() {
    _pageFlipController.dispose();
    _bounceController.dispose();
    _longRefreshTimer?.cancel();
    super.dispose();
  }
  
  // ... (overscroll/scrollEnd untouched logic implicitly via keeping it or see next replace) 
  // Simplified replacement: I am replacing fields and initState/dispose only here.
  // Wait, I need to modify _startRefresh too. I'll do that in next chunk to be safe.
  
  // ... keeping _onOverscroll and _onScrollEnd same for now ...
  
   void _onOverscroll(double overscroll) {
    if (_status == BookRefreshStatus.refreshing || 
        _status == BookRefreshStatus.done) {
      return;
    }
    
    setState(() {
      _dragOffset = (_dragOffset - overscroll).clamp(0.0, _maxDragOffset);
      _status = _dragOffset >= _triggerOffset 
          ? BookRefreshStatus.armed 
          : BookRefreshStatus.pulling;
    });
  }

  void _onScrollEnd() {
    if (_status == BookRefreshStatus.refreshing || 
        _status == BookRefreshStatus.done) {
      return;
    }
    
    if (_status == BookRefreshStatus.armed) {
      _startRefresh();
    } else {
      _animateTo(0);
    }
  }

  void _startRefresh() async {
    setState(() {
      _status = BookRefreshStatus.refreshing;
      _showLongRefreshLink = false;
    });
    
    // Start 5s timer
    _longRefreshTimer?.cancel();
    _longRefreshTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _status == BookRefreshStatus.refreshing) {
        setState(() => _showLongRefreshLink = true);
      }
    });
    
    _animateTo(_refreshAreaHeight);
    _pageFlipController.repeat();
    
    try {
      await widget.onRefresh();
      setState(() => _status = BookRefreshStatus.done);
      _pageFlipController.stop();
      
      // 停留展示完成状态
      await Future.delayed(const Duration(milliseconds: 800));
      
    } catch (e) {
      setState(() => _status = BookRefreshStatus.failed);
      _pageFlipController.stop();
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      _longRefreshTimer?.cancel();
      _showLongRefreshLink = false;
    }
    
    // 收起
    _animateTo(0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _status = BookRefreshStatus.idle;
        _pageFlipController.reset();
      });
    }
  }

  void _animateTo(double target) {
    _bounceAnimation = Tween<double>(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOutCubic,
    ));
    
    _bounceController.duration = const Duration(milliseconds: 300);
    _bounceController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _dragOffset = target);
      }
    });
    
    _bounceController.addListener(_onBounceUpdate);
  }

  void _onBounceUpdate() {
    setState(() => _dragOffset = _bounceAnimation.value);
  }

  @override
  Widget build(BuildContext context) {
    final refreshTheme = ThemeRegistry.get(widget.theme).refreshIndicator;
    final Color bookColor = refreshTheme.bookColor;
    final Color pageColor = refreshTheme.pageColor;
    final Color textColor = refreshTheme.textColor;

    final double progress = (_dragOffset / _triggerOffset).clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is OverscrollNotification) {
          if (notification.overscroll < 0) {
            // 向下过度滚动（下拉）
            _onOverscroll(notification.overscroll);
          }
        } else if (notification is ScrollEndNotification) {
          if (_dragOffset > 0) {
            _onScrollEnd();
          }
        }
        return false;
      },
      child: Stack(
        children: [
          // 刷新区域（固定在顶部，被内容遮挡）
          // 使用 AnimatedBuilder 确保翻页动画能触发重建
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _refreshAreaHeight,
            child: AnimatedBuilder(
              animation: _pageFlipController,
              builder: (context, _) => _RefreshAreaWidget(
                bookColor: bookColor,
                pageColor: pageColor,
                textColor: textColor,
                progress: progress,
                flipProgress: _pageFlipController.value,
                status: _status,
                showLink: _showLongRefreshLink,
                onLinkTap: widget.onLongRefreshTap,
              ),
            ),
          ),
          
          // 主内容（下移）
          Transform.translate(
            offset: Offset(0, _dragOffset),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// 刷新区域组件
class _RefreshAreaWidget extends StatelessWidget {
  final Color bookColor;
  final Color pageColor;
  final Color textColor;
  final double progress;
  final double flipProgress;
  final BookRefreshStatus status;
  final bool showLink;
  final VoidCallback? onLinkTap;
  
  const _RefreshAreaWidget({
    required this.bookColor,
    required this.pageColor,
    required this.textColor,
    required this.progress,
    required this.flipProgress,
    required this.status,
    this.showLink = false,
    this.onLinkTap,
  });

  String get statusText {
    switch (status) {
      case BookRefreshStatus.pulling:
        return '下拉刷新';
      case BookRefreshStatus.armed:
        return '松开刷新';
      case BookRefreshStatus.refreshing:
        return '翻阅中...';
      case BookRefreshStatus.done:
        return '刷新完成';
      case BookRefreshStatus.failed:
        return '刷新失败';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const double bookWidth = 50.0;
    const double bookHeight = 38.0;
    const double spineWidth = 4.0;
    
    final bool isFlipping = status == BookRefreshStatus.refreshing;
    final double scale = 0.6 + (progress * 0.4);
    final double opacity = progress.clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 书本动画
            Transform.scale(
              scale: scale,
              child: SizedBox(
                width: bookWidth * 2 + spineWidth,
                height: bookHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 左页
                    Positioned(
                      left: 0,
                      child: _buildPage(bookWidth, bookHeight, true, pageColor, textColor),
                    ),
                    // 右页
                    Positioned(
                      right: 0,
                      child: _buildPage(bookWidth, bookHeight, false, pageColor, textColor),
                    ),
                    // 翻动页 - 使用多层叠加实现连续翻页效果
                    if (isFlipping)
                      for (int i = 0; i < 4; i++)
                        _FlippingPage(
                          width: bookWidth,
                          height: bookHeight,
                          pageColor: pageColor,
                          lineColor: textColor,
                          // 错开每一页的动画进度
                          progress: (flipProgress + i * 0.25) % 1.0,
                        ),
                    // 书脊
                    Container(
                      width: spineWidth,
                      height: bookHeight,
                      decoration: BoxDecoration(
                        color: bookColor,
                        borderRadius: BorderRadius.circular(1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 状态文字
            Text(
              statusText,
              style: GoogleFonts.notoSerifSc(
                color: textColor.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            // 完成/失败图标
            if (status == BookRefreshStatus.done)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, color: Colors.green, size: 18),
              )
            else if (status == BookRefreshStatus.failed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.error, color: Colors.red, size: 18),
              ),
              
            // Long Refresh Link
            if (showLink && onLinkTap != null)
              Padding(
                 padding: const EdgeInsets.only(top: 8),
                 child: InkWell(
                   onTap: onLinkTap,
                   borderRadius: BorderRadius.circular(12),
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           '查看进度详情',
                           style: GoogleFonts.notoSerifSc(
                             color: textColor.withValues(alpha: 1.0),
                             fontSize: 12,
                             decoration: TextDecoration.underline,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         const SizedBox(width: 2),
                         Icon(Icons.arrow_forward_ios, size: 10, color: textColor),
                       ],
                     ),
                   ),
                 ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(double w, double h, bool isLeft, Color pageColor, Color lineColor) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: pageColor,
        borderRadius: BorderRadius.only(
          topLeft: isLeft ? const Radius.circular(2) : Radius.zero,
          bottomLeft: isLeft ? const Radius.circular(2) : Radius.zero,
          topRight: isLeft ? Radius.zero : const Radius.circular(2),
          bottomRight: isLeft ? Radius.zero : const Radius.circular(2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 2,
            offset: Offset(isLeft ? -1 : 1, 1),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _PageLinesPainter(color: lineColor.withValues(alpha: 0.2), isLeft: isLeft),
      ),
    );
  }

}

/// 翻页动画组件 - 实现从右往左翻页效果
class _FlippingPage extends StatelessWidget {
  final double width;
  final double height;
  final Color pageColor;
  final Color lineColor;
  final double progress; // 0.0 -> 1.0
  
  const _FlippingPage({
    required this.width,
    required this.height,
    required this.pageColor,
    required this.lineColor,
    required this.progress,
  });
  
  @override
  Widget build(BuildContext context) {
    // 使用缓动曲线使动画更自然
    final easedProgress = Curves.easeInOutCubic.transform(progress);
    
    // 翻页角度: 0° -> 180°
    final angle = easedProgress * math.pi;
    
    // 动态调整透明度，避免突兀消失
    double opacity = 1.0;
    if (easedProgress < 0.1) {
      opacity = easedProgress / 0.1; // 淡入
    } else if (easedProgress > 0.9) {
      opacity = (1.0 - easedProgress) / 0.1; // 淡出
    }
    
    // 翻页到一半时显示反面（更深的颜色）
    final bool showBackSide = angle > math.pi / 2;
    final displayColor = showBackSide 
        ? Color.lerp(pageColor, lineColor.withValues(alpha: 0.1), 0.2)!
        : pageColor;
    
    return Positioned(
      right: 0,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.centerLeft, // 以左边为轴翻转
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002) // 透视效果
            ..rotateY(-angle), // 从右往左翻
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: displayColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(2),
                bottomRight: Radius.circular(2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15 * (1 - easedProgress)),
                  blurRadius: 3,
                  offset: Offset(2 * (1 - easedProgress), 1),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _PageLinesPainter(
                color: lineColor.withValues(alpha: showBackSide ? 0.08 : 0.2),
                isLeft: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageLinesPainter extends CustomPainter {
  final Color color;
  final bool isLeft;
  
  _PageLinesPainter({required this.color, required this.isLeft});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.6;
    const lineCount = 4;
    final lineSpacing = size.height / (lineCount + 1);
    final startX = isLeft ? 5.0 : 4.0;
    final endX = isLeft ? size.width - 3 : size.width - 5;
    
    for (int i = 1; i <= lineCount; i++) {
      final y = lineSpacing * i;
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
