import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/application/auto_sync_scheduler.dart';

/// AutoSyncScheduler 时序测试。
///
/// Timer 使用 flutter_test 的 fake clock（testWidgets + tester.pump）控制，
/// 冷却判断通过构造器注入的 clock 控制，无需真实等待，也不引入额外依赖。
void main() {
  group('AutoSyncScheduler', () {
    testWidgets('force 立即触发并取消已排定的防抖定时器', (tester) async {
      var triggered = 0;
      final scheduler = AutoSyncScheduler(
        onTrigger: () async => triggered++,
        clock: () => DateTime(2026, 1, 1, 12, 0),
      );

      // 先排定一个普通防抖请求
      scheduler.request(
        fromLifecycle: false,
        force: false,
        lastSuccessfulSyncAt: null,
      );
      expect(scheduler.isPending, isTrue);

      final decision = scheduler.request(
        fromLifecycle: false,
        force: true,
        lastSuccessfulSyncAt: null,
      );

      expect(decision, AutoSyncDecision.triggeredNow);
      expect(scheduler.isPending, isFalse, reason: 'force 必须取消已有防抖 timer');
      await tester.pump();
      expect(triggered, 1);
    });

    testWidgets('普通请求排定 30s 防抖并在到期后触发', (tester) async {
      var triggered = 0;
      final scheduler = AutoSyncScheduler(onTrigger: () async => triggered++);

      final decision = scheduler.request(
        fromLifecycle: false,
        force: false,
        lastSuccessfulSyncAt: null,
      );
      expect(decision, AutoSyncDecision.scheduled);
      expect(scheduler.isPending, isTrue);

      await tester.pump(
        AutoSyncScheduler.debounceDuration - const Duration(seconds: 1),
      );
      expect(triggered, 0, reason: '防抖窗口内不得触发');

      await tester.pump(const Duration(seconds: 1));
      expect(triggered, 1);
      expect(scheduler.isPending, isFalse, reason: '触发后不再 pending');
    });

    testWidgets('重复请求取消旧定时器，仅最后一次生效', (tester) async {
      var triggered = 0;
      final scheduler = AutoSyncScheduler(onTrigger: () async => triggered++);

      scheduler.request(
        fromLifecycle: false,
        force: false,
        lastSuccessfulSyncAt: null,
      );
      await tester.pump(const Duration(seconds: 10));

      scheduler.request(
        fromLifecycle: false,
        force: false,
        lastSuccessfulSyncAt: null,
      );
      await tester.pump(const Duration(seconds: 29));
      expect(triggered, 0, reason: '第一次请求的 timer 应已被取消');

      await tester.pump(const Duration(seconds: 1));
      expect(triggered, 1, reason: '只有第二次请求的 timer 到期触发');
    });

    testWidgets('lifecycle 冷却期内被抑制，且不取消已排定的防抖 timer', (tester) async {
      var triggered = 0;
      var now = DateTime(2026, 1, 1, 12, 0);
      final scheduler = AutoSyncScheduler(
        onTrigger: () async => triggered++,
        clock: () => now,
      );

      // 保存触发的普通防抖请求先排定
      scheduler.request(
        fromLifecycle: false,
        force: false,
        lastSuccessfulSyncAt: null,
      );
      expect(scheduler.isPending, isTrue);

      // 2 分钟后 lifecycle 触发 → 处于 5 分钟冷却期
      now = now.add(const Duration(minutes: 2));
      final decision = scheduler.request(
        fromLifecycle: true,
        force: false,
        lastSuccessfulSyncAt: now.subtract(const Duration(minutes: 2)),
      );
      expect(decision, AutoSyncDecision.suppressed);
      expect(
        scheduler.isPending,
        isTrue,
        reason: 'suppressed 不得取消已排定的防抖 timer',
      );

      await tester.pump(const Duration(seconds: 30));
      expect(triggered, 1, reason: '原有 30s 防抖仍应到期触发');
    });

    testWidgets('lifecycle 冷却期外（恰好 5 分钟）正常排定', (tester) async {
      var triggered = 0;
      var now = DateTime(2026, 1, 1, 12, 0);
      final scheduler = AutoSyncScheduler(
        onTrigger: () async => triggered++,
        clock: () => now,
      );

      final decision = scheduler.request(
        fromLifecycle: true,
        force: false,
        lastSuccessfulSyncAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(decision, AutoSyncDecision.scheduled);

      await tester.pump(const Duration(seconds: 30));
      expect(triggered, 1);
    });

    testWidgets('lifecycle 无上次同步时间时跳过冷却并正常排定', (tester) async {
      var triggered = 0;
      final scheduler = AutoSyncScheduler(onTrigger: () async => triggered++);

      final decision = scheduler.request(
        fromLifecycle: true,
        force: false,
        lastSuccessfulSyncAt: null,
      );
      expect(decision, AutoSyncDecision.scheduled);

      await tester.pump(const Duration(seconds: 30));
      expect(triggered, 1);
    });

    testWidgets('cancel 取消待执行 timer', (tester) async {
      var triggered = 0;
      final scheduler = AutoSyncScheduler(onTrigger: () async => triggered++);

      scheduler.request(
        fromLifecycle: false,
        force: false,
        lastSuccessfulSyncAt: null,
      );
      scheduler.cancel();
      expect(scheduler.isPending, isFalse);

      await tester.pump(const Duration(seconds: 30));
      expect(triggered, 0);
    });

    testWidgets('dispose 取消待执行 timer', (tester) async {
      var triggered = 0;
      final scheduler = AutoSyncScheduler(onTrigger: () async => triggered++);

      scheduler.request(
        fromLifecycle: false,
        force: false,
        lastSuccessfulSyncAt: null,
      );
      scheduler.dispose();
      expect(scheduler.isPending, isFalse);

      await tester.pump(const Duration(seconds: 30));
      expect(triggered, 0);
    });

    testWidgets('isPending 反映当前是否存在未触发的防抖定时器', (tester) async {
      final scheduler = AutoSyncScheduler(onTrigger: () async {});
      expect(scheduler.isPending, isFalse);

      scheduler.request(
        fromLifecycle: false,
        force: false,
        lastSuccessfulSyncAt: null,
      );
      expect(scheduler.isPending, isTrue);

      scheduler.cancel();
      expect(scheduler.isPending, isFalse);
    });
  });
}
