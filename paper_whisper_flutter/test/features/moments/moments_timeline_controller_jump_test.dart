import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/moments/application/moments_timeline_controller.dart';

/// jumpToDate 有界 PageView + ListWheel 对齐 harness。
///
/// 不传 scheduleEndJump（走真实 binding）；断言 page / selectedItem，
/// 不断言 initialPage / initialItem。
void main() {
  final DateTime fixedNow = DateTime(2026, 3, 10, 15, 30);

  testWidgets('jumpToDate 一帧后 page 与尺子 selectedItem 对齐昨天', (tester) async {
    final c = MomentsTimelineController(clock: () => fixedNow);
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: c.pageController,
                  itemCount: MomentsTimelineController.dayRange,
                  itemBuilder: (_, i) => const SizedBox.expand(),
                ),
              ),
              SizedBox(
                height: 70,
                child: ListWheelScrollView.useDelegate(
                  controller: c.rulerController,
                  itemExtent: 70,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: MomentsTimelineController.dayRange,
                    builder: (_, i) => const SizedBox(height: 70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final yesterday = DateTime(2026, 3, 9);
    final index = c.indexForDate(yesterday);
    c.jumpToDate(yesterday);
    await tester.pump();

    expect(c.pageController.page!.round(), index);
    expect(c.rulerController.selectedItem, index);
    expect(c.selectedDate, yesterday);
  });

  testWidgets('跨度 ≥90 天：一帧后 page 已等于目标 index', (tester) async {
    final c = MomentsTimelineController(clock: () => fixedNow);
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: c.pageController,
                  itemCount: MomentsTimelineController.dayRange,
                  itemBuilder: (_, i) => const SizedBox.expand(),
                ),
              ),
              SizedBox(
                height: 70,
                child: ListWheelScrollView.useDelegate(
                  controller: c.rulerController,
                  itemExtent: 70,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: MomentsTimelineController.dayRange,
                    builder: (_, i) => const SizedBox(height: 70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final target = DateTime(2026, 3, 10).subtract(const Duration(days: 90));
    final index = c.indexForDate(target);
    c.jumpToDate(target);
    await tester.pump();

    expect(c.pageController.page!.round(), index);
    expect(c.rulerController.selectedItem, index);
  });
}
