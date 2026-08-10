import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashed_line_painter.dart';

/// 日记列表空态组件（搜索无结果 / 普通空态）。
///
/// 文案、字号、间距、虚线 [DashedLinePainter] 与蜘蛛网 [SpiderWebIconPainter]
/// 与旧 `diary_list_page._buildEmptyState` 逐字保持一致。颜色由页面从
/// 7 主题动态 Map 取色后以 props 显式传入，本组件不持有主题上下文；
/// 「去擦拭灰尘」回调由页面负责（打开编辑器与路由动画不进组件）。
class DiaryEmptyState extends StatelessWidget {
  /// 当前搜索关键词；非空时渲染「搜索无结果」状态。
  final String query;

  /// 搜索无结果状态的图标与文案颜色。
  final Color searchTextColor;

  /// 普通空态蜘蛛网图标颜色。
  final Color iconColor;

  /// 普通空态主文案颜色。
  final Color textColor;

  /// 普通空态链接文字与虚线颜色。
  final Color linkColor;

  /// 「去擦拭灰尘 (写一篇) →」点击回调。
  final VoidCallback onCreate;

  const DiaryEmptyState({
    super.key,
    required this.query,
    required this.searchTextColor,
    required this.iconColor,
    required this.textColor,
    required this.linkColor,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isNotEmpty) {
      // 搜索无结果状态
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: searchTextColor),
            const SizedBox(height: 24),
            Text(
              '没有找到关于"$query"的篇章...',
              style: GoogleFonts.notoSerifSc(
                color: searchTextColor,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 蜘蛛网图标 - 使用 CustomPaint 绘制
          CustomPaint(
            size: const Size(64, 64), // 设计图中图标不需要太大
            painter: SpiderWebIconPainter(color: iconColor),
          ),
          const SizedBox(height: 32),
          Text(
            '这里似乎落了一层灰，等待你来翻阅',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSerifSc(
              fontSize: 16,
              color: textColor,
              height: 1.5,
              fontStyle: FontStyle.italic, // 恢复斜体
            ),
          ),
          const SizedBox(height: 48), // 增加间距
          // "去擦拭灰尘（写一篇）→" 按钮 - 带虚线
          GestureDetector(
            onTap: onCreate,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '去擦拭灰尘 (写一篇) →',
                  style: GoogleFonts.notoSerifSc(
                    fontSize: 15,
                    color: linkColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4), // 文字和虚线的间距
                SizedBox(
                  width: 180, // 根据文字长度估算，确保虚线覆盖文字
                  height: 1,
                  child: CustomPaint(
                    painter: DashedLinePainter(
                      color: linkColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 蜘蛛网图标绘制器 - 用于空状态显示
/// 设计：六边形框架 + 内部蜘蛛网线条，体现"落灰"的意象
class SpiderWebIconPainter extends CustomPainter {
  final Color color;

  SpiderWebIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          3.0 // 加粗外框
      ..strokeJoin = StrokeJoin.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 六边形顶点（从顶部开始顺时针）
    final double radius = size.width * 0.45;
    final List<Offset> hexPoints = [];
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * math.pi / 180; // 从顶部开始
      hexPoints.add(
        Offset(
          centerX + radius * math.cos(angle),
          centerY + radius * math.sin(angle),
        ),
      );
    }

    // 绘制六边形外框（拟物化：使用贝塞尔曲线向内凹陷）
    final hexPath = Path();
    hexPath.moveTo(hexPoints[0].dx, hexPoints[0].dy);
    for (int i = 0; i < 6; i++) {
      // 当前点
      final p1 = hexPoints[i];
      // 下一个点
      final p2 = hexPoints[(i + 1) % 6];

      // 计算中点
      final midX = (p1.dx + p2.dx) / 2;
      final midY = (p1.dy + p2.dy) / 2;

      // 计算控制点：向中心凹陷
      const curveFactor = 0.12; // 外框稍微绷紧一点
      final controlX = midX + (centerX - midX) * curveFactor;
      final controlY = midY + (centerY - midY) * curveFactor;

      hexPath.quadraticBezierTo(controlX, controlY, p2.dx, p2.dy);
    }
    // hexPath.close(); // Closed by loop logic
    canvas.drawPath(hexPath, paint);

    // 绘制从中心到六个顶点的辐射线
    final thinPaint = Paint()
      ..color = color
          .withValues(alpha: 0.8) // 稍微加深
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0; // 加粗线条

    final center = Offset(centerX, centerY);
    for (final point in hexPoints) {
      canvas.drawLine(center, point, thinPaint);
    }

    // 绘制内部蜘蛛网同心六边形（2层）
    final webPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (double scale in [0.33, 0.66]) {
      final innerPath = Path();
      // 计算这一层的顶点
      final List<Offset> layerPoints = [];
      for (int i = 0; i < 6; i++) {
        layerPoints.add(
          Offset(
            centerX + (hexPoints[i].dx - centerX) * scale,
            centerY + (hexPoints[i].dy - centerY) * scale,
          ),
        );
      }

      innerPath.moveTo(layerPoints[0].dx, layerPoints[0].dy);

      for (int i = 0; i < 6; i++) {
        // 当前点
        final p1 = layerPoints[i];
        // 下一个点
        final p2 = layerPoints[(i + 1) % 6];

        // 计算中点
        final midX = (p1.dx + p2.dx) / 2;
        final midY = (p1.dy + p2.dy) / 2;

        // 计算控制点：向中心凹陷
        // 简单的做法是取中点和中心的连线上的某一点
        // 凹陷程度因子 (0.0 = 直线, 1.0 = 到中心)
        const curveFactor = 0.15;
        final controlX = midX + (centerX - midX) * curveFactor;
        final controlY = midY + (centerY - midY) * curveFactor;

        innerPath.quadraticBezierTo(controlX, controlY, p2.dx, p2.dy);
      }
      // innerPath.close(); // quadraticBezierTo 已经闭合回去了（最后一个点连回第一个点）
      canvas.drawPath(innerPath, webPaint);
    }

    // 中心小圆点
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant SpiderWebIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
