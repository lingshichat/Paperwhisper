import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_progress_tracker.dart';

/// SyncProgressTracker 测试。
///
/// 覆盖 reset / totalProgress 公式与 clamp / markItemProcessed /
/// resetCurrentFile / 500ms 节流 / onChanged 通知等确定性行为。
///
/// ## API 缺口
/// 当前 API 无 clock seam：速度与 ETA 计算内部使用 `DateTime.now()`，
/// 无法注入可控时钟，因此瞬时速度与 ETA 精确值无法确定性断言。
/// 建议为构造器增加 `DateTime Function()? clock` 注入点（与
/// AutoSyncScheduler 一致），届时可移除下方真实延迟用例并改为
/// FakeAsync + 可控时钟的精确断言。
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

    test('500ms 节流窗口内重复回调更新进度但不通知', () {
      var changed = 0;
      final tracker = SyncProgressTracker(onChanged: () => changed++);
      tracker.reset(3); // changed = 1
      tracker.onFileProgress(10, 100); // changed = 2，首次刷新

      tracker.onFileProgress(20, 100); // 同一毫秒内，节流

      expect(tracker.currentFileProgress, 0.2, reason: '进度本身仍应更新');
      expect(changed, 2, reason: '节流窗口内不得重复通知');
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

  // 速度与 ETA 依赖真实时钟（缺 clock seam，见文件头注释）。
  // 使用一次短延迟验证格式化与更新路径，断言保持宽松以容忍计时抖动。
  group('SyncProgressTracker 速度与 ETA（真实时钟，短延迟）', () {
    test('完成项后第二次进度回调计算瞬时速度并进入剩余文案分支', () async {
      var changed = 0;
      final tracker = SyncProgressTracker(onChanged: () => changed++);
      tracker.reset(10);
      tracker.markItemProcessed(); // processed = 1
      tracker.onFileProgress(50, 100); // 首次：speed = '计算中...'

      await Future<void>.delayed(const Duration(milliseconds: 700));

      tracker.onFileProgress(100, 100); // 第二次：计算速度与 ETA

      expect(tracker.currentFileProgress, 1.0);
      expect(
        tracker.currentFileSpeed,
        endsWith(' B/s'),
        reason: '瞬时速度应格式化为 B/s（约 71 B/s，容忍抖动）',
      );
      expect(tracker.currentFileSpeed, isNot('计算中...'));
      expect(
        tracker.etaMessage,
        startsWith('剩余'),
        reason: '有剩余项时应进入“剩余 X 秒”分支',
      );
      expect(changed, 3, reason: 'reset + 首次回调 + 第二次回调各通知一次');
    });
  });
}
