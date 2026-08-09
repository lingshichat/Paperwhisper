import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/moments/application/moments_timeline_controller.dart';

/// MomentsTimelineController 单元测试（阶段 4 Wave A）。
///
/// 契约覆盖（与 `moments_page` 原日期状态机逐字一致）：
/// - 起点 = 今天 - 5 年，初始索引 = 今天距起点天数（钳制 ≥ 0）；
/// - 日期 ↔ 索引往返、尺子偏移（70 单位）↔ 页索引互逆换算；
/// - Ruler/Page 互斥来源决策：一方活跃时另一方通知被忽略；
/// - selectDate 归一化到当日零点、isSameDay 同日判定；
/// - dispose 释放 page/ruler 控制器。
///
/// 时钟经 [MomentsTimelineController] 的 clock seam 注入固定值，无 I/O。
void main() {
  final DateTime fixedNow = DateTime(2026, 3, 10, 15, 30);

  MomentsTimelineController buildController({DateTime? initialDate}) {
    return MomentsTimelineController(
      initialDate: initialDate,
      clock: () => fixedNow,
    );
  }

  group('起点与初始索引', () {
    test('起点 = 今天 - 5 年，初始索引 = 今天距起点天数', () {
      final c = buildController();
      final today = DateTime(2026, 3, 10);
      final expectedStart = today.subtract(const Duration(days: 365 * 5));
      // 与原 `date.difference(_startDate).inDays` 表达式一致（避免 DST 边界）。
      final expectedIndex = today.difference(expectedStart).inDays;

      expect(c.startDate, expectedStart);
      expect(c.selectedDate, today);
      expect(c.indexForDate(today), expectedIndex);
      expect(c.pageController.initialPage, expectedIndex);
      expect(c.rulerController.initialItem, expectedIndex);
    });

    test('initialDate 早于起点时初始索引钳制为 0', () {
      final c = buildController(initialDate: DateTime(2000, 1, 1));
      expect(c.indexForDate(c.selectedDate), 0);
      expect(c.pageController.initialPage, 0);
      expect(c.rulerController.initialItem, 0);
    });

    test('dayRange 覆盖 3650 天', () {
      expect(MomentsTimelineController.dayRange, 3650);
      expect(MomentsTimelineController.rulerItemExtent, 70.0);
    });
  });

  group('索引换算', () {
    test('indexForDate / dateForIndex 往返（同一天）', () {
      final c = buildController();
      final target = DateTime(2026, 3, 12);
      final roundTrip = c.dateForIndex(c.indexForDate(target));
      expect(c.isSameDay(roundTrip, target), isTrue);
    });

    test('indexForDate 早于起点钳制为 0', () {
      final c = buildController();
      expect(c.indexForDate(DateTime(1990, 1, 1)), 0);
    });

    test('rulerOffsetForPage / pageForRulerOffset 互逆（70 单位）', () {
      final c = buildController();
      expect(c.rulerOffsetForPage(3), 210.0);
      expect(c.pageForRulerOffset(210.0), 3.0);
      expect(c.pageForRulerOffset(70.0), 1.0);
      expect(c.rulerOffsetForPage(0), 0.0);
    });
  });

  group('互斥来源决策', () {
    test('Ruler 活跃时 Page 滚动通知被忽略', () {
      final c = buildController();
      expect(c.shouldProcessRulerScroll(), isTrue);
      expect(c.isRulerActive, isTrue);
      expect(c.shouldProcessPageScroll(), isFalse);
      expect(c.isPageActive, isFalse);
    });

    test('Page 活跃时 Ruler 滚动通知被忽略', () {
      final c = buildController();
      expect(c.shouldProcessPageScroll(), isTrue);
      expect(c.isPageActive, isTrue);
      expect(c.shouldProcessRulerScroll(), isFalse);
      expect(c.isRulerActive, isFalse);
    });

    test('滚动结束后互斥解除，后续通知可再次处理', () {
      final c = buildController();
      c.shouldProcessPageScroll();
      c.pageScrollEnded();
      expect(c.isPageActive, isFalse);
      expect(c.shouldProcessRulerScroll(), isTrue);

      c.rulerScrollEnded();
      expect(c.isRulerActive, isFalse);
      expect(c.shouldProcessPageScroll(), isTrue);
    });
  });

  group('选中日期', () {
    test('selectDate 归一化到当日零点', () {
      final c = buildController();
      c.selectDate(DateTime(2026, 3, 12, 23, 59, 59));
      expect(c.selectedDate, DateTime(2026, 3, 12));
    });

    test('isSameDay 忽略时间分量', () {
      final c = buildController();
      expect(
        c.isSameDay(DateTime(2026, 3, 12, 1), DateTime(2026, 3, 12, 23)),
        isTrue,
      );
      expect(
        c.isSameDay(DateTime(2026, 3, 12), DateTime(2026, 3, 13)),
        isFalse,
      );
    });
  });

  group('生命周期', () {
    test('dispose 释放 page / ruler 控制器', () {
      final c = buildController();
      c.dispose();
      expect(c.pageController.hasClients, isFalse);
      expect(c.rulerController.hasClients, isFalse);
    });
  });
}
