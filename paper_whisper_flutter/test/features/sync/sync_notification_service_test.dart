import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  group('SyncNotificationService 移动路径（isSupportedPlatform=true）', () {
    test('init 转发到 gateway', () async {
      final gateway = RecordingGateway();
      final service = SyncNotificationService(
        gateway: gateway,
        isSupportedPlatform: () => true,
      );

      await service.init();

      expect(gateway.calls, <String>['init']);
    });

    test('showProgress 原样转发 progress/max/body/indeterminate', () async {
      final gateway = RecordingGateway();
      final service = SyncNotificationService(
        gateway: gateway,
        isSupportedPlatform: () => true,
      );

      await service.showProgress(50, 100, body: '正在同步...');
      await service.showProgress(null, null, indeterminate: true);

      expect(gateway.calls, <String>[
        'showProgress:50:100:正在同步...:false',
        'showProgress:null:null:null:true',
      ]);
    });

    test('showCompletion 转发 message', () async {
      final gateway = RecordingGateway();
      final service = SyncNotificationService(
        gateway: gateway,
        isSupportedPlatform: () => true,
      );

      await service.showCompletion('同步完成');

      expect(gateway.calls, <String>['showCompletion:同步完成']);
    });

    test('cancel 转发', () async {
      final gateway = RecordingGateway();
      final service = SyncNotificationService(
        gateway: gateway,
        isSupportedPlatform: () => true,
      );

      await service.cancel();

      expect(gateway.calls, <String>['cancel']);
    });
  });

  group('SyncNotificationService 真实网关参数（method channel 捕获）', () {
    const MethodChannel channel = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    late List<MethodCall> calls;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      // 强制 Android 目标平台，驱动插件走 Android 实现（method channel）
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            // initialize 需要返回 bool；show/cancel 返回 null 即可
            return call.method == 'initialize' ? true : null;
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Map<dynamic, dynamic> showArguments(MethodCall call) {
      return call.arguments as Map<dynamic, dynamic>;
    }

    Map<dynamic, dynamic> platformSpecifics(MethodCall call) {
      return showArguments(call)['platformSpecifics'] as Map<dynamic, dynamic>;
    }

    test('init 触发插件 initialize 调用', () async {
      final service = SyncNotificationService(isSupportedPlatform: () => true);

      await service.init();

      expect(calls.map((MethodCall c) => c.method), contains('initialize'));
    });

    test(
      'showProgress 发送 ID 888 / 标题 / body / 渠道 / ongoing / progress',
      () async {
        final service = SyncNotificationService(
          isSupportedPlatform: () => true,
        );

        await service.showProgress(50, 100, body: '正在同步...');

        final show = calls.singleWhere((MethodCall c) => c.method == 'show');
        final args = showArguments(show);
        expect(args['id'], SyncNotificationService.notificationId);
        expect(args['title'], 'PaperWhisper 云同步');
        expect(args['body'], '正在同步...');

        final specifics = platformSpecifics(show);
        expect(specifics['channelId'], SyncNotificationService.channelId);
        expect(specifics['channelName'], SyncNotificationService.channelName);
        expect(specifics['channelDescription'], '显示同步状态和进度');
        expect(specifics['ongoing'], isTrue);
        expect(specifics['autoCancel'], isFalse);
        expect(specifics['showProgress'], isTrue);
        expect(specifics['progress'], 50);
        expect(specifics['maxProgress'], 100);
        expect(specifics['indeterminate'], isFalse);
      },
    );

    test('showProgress 无确定总量时 indeterminate/progress 语义正确', () async {
      final service = SyncNotificationService(isSupportedPlatform: () => true);

      await service.showProgress(null, null, indeterminate: true);

      final show = calls.singleWhere((MethodCall c) => c.method == 'show');
      final specifics = platformSpecifics(show);
      expect(specifics['indeterminate'], isTrue);
      expect(specifics['showProgress'], isTrue);
      expect(specifics['progress'], 0);
      expect(specifics['maxProgress'], 100);
    });

    test('showCompletion 发送完成标题与非 ongoing 通知', () async {
      final service = SyncNotificationService(isSupportedPlatform: () => true);

      await service.showCompletion('同步完成');

      final show = calls.singleWhere((MethodCall c) => c.method == 'show');
      final args = showArguments(show);
      expect(args['id'], SyncNotificationService.notificationId);
      expect(args['title'], '同步完成');
      expect(args['body'], '同步完成');

      final specifics = platformSpecifics(show);
      expect(specifics['channelId'], SyncNotificationService.channelId);
      expect(specifics['ongoing'], isFalse);
      expect(specifics['autoCancel'], isTrue);
    });

    test('cancel 发送 ID 888', () async {
      final service = SyncNotificationService(isSupportedPlatform: () => true);

      await service.cancel();

      final cancel = calls.singleWhere((MethodCall c) => c.method == 'cancel');
      expect(cancel.arguments, <String, Object?>{
        'id': SyncNotificationService.notificationId,
        'tag': null,
      });
    });

    test('默认非移动守卫仍短路：真实 gateway 零 channel 调用', () async {
      // 本机（Windows）默认守卫 false：即使真实 gateway 也不触碰插件
      if (Platform.isAndroid || Platform.isIOS) return;

      final service = SyncNotificationService();

      await service.init();
      await service.showProgress(1, 10, body: '正在同步...');
      await service.showCompletion('同步完成');
      await service.cancel();

      expect(calls, isEmpty, reason: '非移动平台不应产生任何插件调用');
    });
  });
}
