import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_notification_service.dart';

/// SyncNotificationService 测试。
///
/// 覆盖常量契约（ID 888 / 渠道 paper_whisper_sync）与确定性平台守卫
/// （非 Android/iOS 平台直接返回，不触碰插件）。
///
/// ## Adapter seam 建议
/// `FlutterLocalNotificationsPlugin` 为具体类且无可替换接口，构造器
/// 虽接受 plugin 参数但无法注入记录型 fake（禁止引入 mock 库），因此
/// 移动平台上的 `init`/`show`/`cancel` 参数（ID、渠道、标题、文案、
/// ongoing/progress 语义）无法独立断言。建议后续引入最小 adapter seam：
///
/// ```dart
/// abstract interface class SyncNotificationGateway {
///   Future<void> init();
///   Future<void> showProgress(int? progress, int? max, {String? body, bool indeterminate});
///   Future<void> showCompletion(String message);
///   Future<void> cancel();
/// }
/// ```
///
/// `SyncNotificationService` 改为依赖该接口，测试注入记录型 fake 即可
/// 断言 ID/渠道/标题/文案与平台守卫，无需真实通知插件。
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
    // isIOS 均为 false；移动平台下插件调用无法注入 fake，此处跳过。
    final bool runsOnNonMobile = !Platform.isAndroid && !Platform.isIOS;

    test('init 在非移动平台安全返回', () async {
      if (!runsOnNonMobile) return;
      final service = SyncNotificationService();
      await service.init();
    });

    test('showProgress 在非移动平台安全返回', () async {
      if (!runsOnNonMobile) return;
      final service = SyncNotificationService();
      await service.showProgress(50, 100);
      await service.showProgress(null, null, indeterminate: true);
    });

    test('showCompletion 在非移动平台安全返回', () async {
      if (!runsOnNonMobile) return;
      final service = SyncNotificationService();
      await service.showCompletion('同步完成');
    });

    test('cancel 在非移动平台安全返回', () async {
      if (!runsOnNonMobile) return;
      final service = SyncNotificationService();
      await service.cancel();
    });
  });
}
