import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

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
  
  const BookFlipRefreshWidget({
    super.key,
    required this.child,
    required this.onRefresh,
    required this.theme,
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
  
  // 阈值
  static const double _triggerOffset = 100.0;
  static const double _maxDragOffset = 180.0;
  static const double _refreshAreaHeight = 120.0;

  @override
  void initState() {
    super.initState();
    _pageFlipController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceController = AnimationController(vsync: this);
    _bounceAnimation = Tween<double>(begin: 0, end: 0).animate(_bounceController);
  }

  @override
  void dispose() {
    _pageFlipController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onOverscroll(double overscroll) {
    if (_status == BookRefreshStatus.refreshing || 
        _status == BookRefreshStatus.done) return;
    
    setState(() {
      _dragOffset = (_dragOffset - overscroll).clamp(0.0, _maxDragOffset);
      _status = _dragOffset >= _triggerOffset 
          ? BookRefreshStatus.armed 
          : BookRefreshStatus.pulling;
    });
  }

  void _onScrollEnd() {
    if (_status == BookRefreshStatus.refreshing || 
        _status == BookRefreshStatus.done) return;
    
    if (_status == BookRefreshStatus.armed) {
      _startRefresh();
    } else {
      _animateTo(0);
    }
  }

  void _startRefresh() async {
    setState(() => _status = BookRefreshStatus.refreshing);
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步失败: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      await Future.delayed(const Duration(milliseconds: 500));
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
    final bool isSeaFlower = widget.theme == AppTheme.themeSeaFlower;
    final bool isMidnight = widget.theme == AppTheme.themeMidnight;
    
    final Color bookColor = isSeaFlower 
        ? const Color(0xFFAD1457)
        : (isMidnight ? const Color(0xFF5C6BC0) : const Color(0xFF6D4C41));
    final Color pageColor = isSeaFlower
        ? const Color(0xFFFCE4EC)
        : (isMidnight ? const Color(0xFFE8EAF6) : const Color(0xFFFAF8F5));
    final Color textColor = isSeaFlower
        ? const Color(0xFFAD1457)
        : (isMidnight ? const Color(0xFFB0BEC5) : const Color(0xFF8D6E63));

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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _refreshAreaHeight,
            child: _RefreshAreaWidget(
              bookColor: bookColor,
              pageColor: pageColor,
              textColor: textColor,
              progress: progress,
              flipProgress: _pageFlipController.value,
              status: _status,
            ),
          ),
          
          // 主内容（下移）
          AnimatedBuilder(
            animation: _pageFlipController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _dragOffset),
                child: widget.child,
              );
            },
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
  
  const _RefreshAreaWidget({
    required this.bookColor,
    required this.pageColor,
    required this.textColor,
    required this.progress,
    required this.flipProgress,
    required this.status,
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
                    // 翻动页
                    if (isFlipping)
                      for (int i = 0; i < 3; i++)
                        Positioned(
                          right: 0,
                          child: _buildFlippingPage(
                            bookWidth, bookHeight, pageColor, textColor,
                            (flipProgress + i * 0.3) % 1.0,
                          ),
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
                            color: Colors.black.withOpacity(0.2),
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
                color: textColor.withOpacity(0.9),
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 2,
            offset: Offset(isLeft ? -1 : 1, 1),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _PageLinesPainter(color: lineColor.withOpacity(0.2), isLeft: isLeft),
      ),
    );
  }

  Widget _buildFlippingPage(double w, double h, Color pageColor, Color lineColor, double progress) {
    if (progress > 0.5) return const SizedBox.shrink();
    
    return Transform(
      alignment: Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(-progress * math.pi),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: pageColor,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(2),
            bottomRight: Radius.circular(2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _PageLinesPainter(color: lineColor.withOpacity(0.15), isLeft: false),
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
