import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_notification_service.dart';

/// 记录型 [SyncNotificationGateway] 替身：记录每次调用及其参数。
class RecordingGateway implements SyncNotificationGateway {
  final List<String> calls = <String>[];

  @override
  Future<void> init() async {
    calls.add('init');
  }

  @override
  Future<void> showProgress(
    int? progress,
    int? max, {
    String? body,
    bool indeterminate = false,
  }) async {
    calls.add('showProgress:$progress:$max:$body:$indeterminate');
  }

  @override
  Future<void> showCompletion(String message) async {
    calls.add('showCompletion:$message');
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
  }
}

/// SyncNotificationService 测试。
///
/// 覆盖常量契约（ID 888 / 渠道 paper_whisper_sync）与确定性平台守卫：
/// 非 Android/iOS 平台（本机 Windows VM）上所有操作直接短路返回，
/// 不触碰注入的 gateway。
///
/// ## 可测试性边界（seam 报告）
/// `SyncNotificationService` 的平台守卫是硬编码的 `dart:io Platform`
/// 检查（`Platform.isAndroid || Platform.isIOS`），本机（Windows）恒为
/// false，因此「移动平台上 gateway 收到 showProgress/showCompletion/
/// cancel 参数」的调用链在当前平台无法被驱动；断言其等价的可观测行为：
/// ① 非移动平台 gateway 零调用（守卫短路有效）；
/// ② 服务可注入记录型 gateway 而不触碰真实通知插件。
/// 若需在任意平台断言移动路径，需要 lib 增加可注入 `platformPredicate`
/// seam（超出本测试 lane 的 lib 修改权限）。
void main() {
  group('SyncNotificationService 常量契约', () {
    test('通知 ID 保持 888', () {
      expect(SyncNotificationService.notificationId, 888);
    });

    test('渠道 ID 与名称保持 paper_whisper_sync', () {
      expect(SyncNotificationService.channelId, 'paper_whisper_sync');
      expect(SyncNotificationService.channelName, 'Sync Status');
    });
  });

  group('SyncNotificationService 平台守卫（非移动平台）', () {
    // flutter test 在 Dart VM 上运行，本机（Windows）Platform.isAndroid/
    // isIOS 均为 false；守卫短路是当前平台唯一可观测的移动路径行为。
    final bool runsOnNonMobile = !Platform.isAndroid && !Platform.isIOS;

    test('init 在非移动平台短路，不触碰 gateway', () async {
      if (!runsOnNonMobile) return;
      final gateway = RecordingGateway();
      final service = SyncNotificationService(gateway: gateway);

      await service.init();

      expect(gateway.calls, isEmpty, reason: '非移动平台不应初始化通知插件');
    });

    test('showProgress 在非移动平台短路，不触碰 gateway', () async {
      if (!runsOnNonMobile) return;
      final gateway = RecordingGateway();
      final service = SyncNotificationService(gateway: gateway);

      await service.showProgress(50, 100);
      await service.showProgress(null, null, indeterminate: true);

      expect(gateway.calls, isEmpty);
    });

    test('showCompletion 在非移动平台短路，不触碰 gateway', () async {
      if (!runsOnNonMobile) return;
      final gateway = RecordingGateway();
      final service = SyncNotificationService(gateway: gateway);

      await service.showCompletion('同步完成');

      expect(gateway.calls, isEmpty);
    });

    test('cancel 在非移动平台短路，不触碰 gateway', () async {
      if (!runsOnNonMobile) return;
      final gateway = RecordingGateway();
      final service = SyncNotificationService(gateway: gateway);

      await service.cancel();

      expect(gateway.calls, isEmpty);
    });

    test('注入 gateway 后所有操作安全返回，无插件副作用', () async {
      if (!runsOnNonMobile) return;
      final gateway = RecordingGateway();
      final service = SyncNotificationService(gateway: gateway);

      await service.init();
      await service.showProgress(1, 10, body: '正在同步...');
      await service.showCompletion('同步成功');
      await service.cancel();

      expect(gateway.calls, isEmpty);
    });
  });
}
