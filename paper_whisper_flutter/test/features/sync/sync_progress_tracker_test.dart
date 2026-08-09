import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_progress_tracker.dart';

/// SyncProgressTracker 测试。
///
/// 覆盖 reset / totalProgress 公式与 clamp / markItemProcessed /
/// resetCurrentFile / 500ms 节流 / onChanged 通知等确定性行为。
///
/// 速度与 ETA 通过构造器注入的 `clock` 精确控制时间，无需真实延迟：
/// - 500ms 节流窗口边界（499ms 不通知、恰好 500ms 通知）；
/// - 瞬时速度格式化（B/s / KB/s / MB/s）；
/// - ETA 文案分支（剩余秒 / 剩余分秒 / 即将完成 / 计算中）。
void main() {
  group('SyncProgressTracker 确定性行为', () {
    test('reset 重置统计、设置初始文案并通知', () {
      var changed = 0;
      final tracker = SyncProgressTracker(onChanged: () => changed++);

      tracker.reset(10);

      expect(tracker.totalOps, 10);
      expect(tracker.processedOps, 0);
      expect(tracker.currentFileProgress, 0.0);
      expect(tracker.currentFileSpeed, '');
      expect(tracker.etaMessage, '计算中...');
      expect(changed, 1);
    });

    test('totalProgress 在无操作时返回 0', () {
      final tracker = SyncProgressTracker();
      expect(tracker.totalProgress, 0.0);
    });

    test('totalProgress 公式：(processed + currentFilePart) / total', () {
      final tracker = SyncProgressTracker();
      tracker.reset(4);
      tracker.markItemProcessed(); // processed = 1
      tracker.onFileProgress(50, 100); // filePart = 0.5

      expect(tracker.totalProgress, closeTo((1 + 0.5) / 4, 1e-9));
    });

    test('totalProgress 将 currentFileProgress clamp 到 [0, 1]', () {
      final tracker = SyncProgressTracker();
      tracker.reset(2);
      tracker.onFileProgress(150, 100); // 1.5 -> clamp 1.0

      expect(tracker.totalProgress, closeTo((0 + 1.0) / 2, 1e-9));
    });

    test('markItemProcessed 仅递增计数，不单独通知', () {
      var changed = 0;
      final tracker = SyncProgressTracker(onChanged: () => changed++);
      tracker.reset(3); // changed = 1

      tracker.markItemProcessed();
      tracker.markItemProcessed();

      expect(tracker.processedOps, 2);
      expect(changed, 1, reason: 'markItemProcessed 不应触发通知');
    });

    test('resetCurrentFile 重置当前文件统计并通知', () {
      var changed = 0;
      final tracker = SyncProgressTracker(onChanged: () => changed++);
      tracker.reset(3); // changed = 1
      tracker.onFileProgress(80, 100); // changed = 2
      expect(tracker.currentFileProgress, 0.8);

      tracker.resetCurrentFile(); // changed = 3

      expect(tracker.currentFileProgress, 0.0);
      expect(tracker.currentFileSpeed, '');
      expect(changed, 3);
    });

    test('onFileProgress 首次调用设置初始速度文案并通知', () {
      var changed = 0;
      final tracker = SyncProgressTracker(onChanged: () => changed++);
      tracker.reset(3); // changed = 1

      tracker.onFileProgress(25, 100); // changed = 2

      expect(tracker.currentFileProgress, 0.25);
      expect(tracker.currentFileSpeed, '计算中...');
      expect(tracker.etaMessage, '计算中...', reason: '尚未处理任何项');
      expect(changed, 2);
    });

    test('onFileProgress total 不大于 0 时进度归零', () {
      final tracker = SyncProgressTracker();
      tracker.reset(3);

      tracker.onFileProgress(10, 0);

      expect(tracker.currentFileProgress, 0.0);
    });

    test('无剩余项时 ETA 显示即将完成', () {
      final tracker = SyncProgressTracker();
      tracker.reset(2);
      tracker.markItemProcessed();
      tracker.markItemProcessed(); // processed == total

      tracker.onFileProgress(100, 100);

      expect(tracker.etaMessage, '即将完成');
    });
  });

  group('SyncProgressTracker 节流与速度/ETA（注入时钟）', () {
    test('500ms 节流窗口内重复回调更新进度但不通知', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      var changed = 0;
      final tracker = SyncProgressTracker(
        onChanged: () => changed++,
        clock: () => now,
      );
      tracker.reset(3); // changed = 1
      tracker.onFileProgress(10, 100); // changed = 2，首次刷新，_lastSpeedUpdate = t0

      now = now.add(const Duration(milliseconds: 499));
      tracker.onFileProgress(20, 100); // 节流窗口内（<500ms）

      expect(tracker.currentFileProgress, 0.2, reason: '进度本身仍应更新');
      expect(changed, 2, reason: '节流窗口内不得重复通知');

      now = now.add(const Duration(milliseconds: 1)); // 距 t0 恰好 500ms
      tracker.onFileProgress(30, 100); // 跨过窗口：刷新速度/ETA 并通知

      expect(changed, 3, reason: '恰好 500ms 时应触发节流刷新');
    });

    test('完成项后第二次进度回调计算瞬时速度与剩余秒数', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      var changed = 0;
      final tracker = SyncProgressTracker(
        onChanged: () => changed++,
        clock: () => now,
      );
      tracker.reset(10); // changed = 1，batchStart = t0
      tracker.markItemProcessed(); // processed = 1

      tracker.onFileProgress(50, 100); // changed = 2，首次：speed = '计算中...'
      expect(tracker.currentFileSpeed, '计算中...');

      now = now.add(const Duration(milliseconds: 700));
      tracker.onFileProgress(100, 100); // changed = 3

      // 瞬时速度：bytesDiff=50 / 700ms → 71.4 B/s → '71 B/s'
      expect(tracker.currentFileSpeed, '71 B/s');
      // ETA：700ms/项 × (10 - 1 - 1.0) 剩余 → 5600ms → '剩余 5 秒'
      expect(tracker.etaMessage, '剩余 5 秒');
      expect(changed, 3, reason: 'reset + 首次回调 + 跨窗口回调各通知一次');
    });

    test('速度按 KB/s 与 MB/s 格式化', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final tracker = SyncProgressTracker(clock: () => now);
      tracker.reset(10);
      tracker.markItemProcessed();

      // KB/s：2048 B 增量 / 1000ms → 2048 B/s → 2.0 KB/s
      tracker.onFileProgress(1024, 4096);
      now = now.add(const Duration(seconds: 1));
      tracker.onFileProgress(3072, 4096);
      expect(tracker.currentFileSpeed, '2.0 KB/s');

      // MB/s：2 MiB 增量 / 1000ms → 2.0 MB/s
      now = now.add(const Duration(seconds: 1));
      tracker.onFileProgress(3072 + 2 * 1024 * 1024, 4096 * 1024 * 1024);
      expect(tracker.currentFileSpeed, '2.0 MB/s');
    });

    test('ETA 进入剩余分秒分支', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final tracker = SyncProgressTracker(clock: () => now);
      tracker.reset(10);
      tracker.markItemProcessed();

      tracker.onFileProgress(50, 100);
      now = now.add(const Duration(milliseconds: 61000));
      tracker.onFileProgress(100, 100);

      // 61000ms/项 × (10 - 1 - 1.0) = 488000ms = 8 分 8 秒
      expect(tracker.etaMessage, '剩余 8 分 8 秒');
    });

    test('完成项数不变时速度不重复计算（count 未增长不刷新）', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final tracker = SyncProgressTracker(clock: () => now);
      tracker.reset(10);
      tracker.markItemProcessed();

      tracker.onFileProgress(100, 100); // 首次：speed = '计算中...'
      now = now.add(const Duration(seconds: 1));
      tracker.onFileProgress(100, 100); // count 未增长：不计算速度

      expect(tracker.currentFileSpeed, '计算中...');
    });
  });
}
