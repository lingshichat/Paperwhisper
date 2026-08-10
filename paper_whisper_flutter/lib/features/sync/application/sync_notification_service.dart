import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 通知插件的最小可测试 gateway 抽象。
///
/// 仅定义初始化与展示/取消四个操作；平台守卫（Android/iOS）由
/// [SyncNotificationService] 统一处理（与迁移前一致），gateway 实现
/// 无需重复判断平台。测试可注入记录型 fake，无需真实通知插件。
abstract interface class SyncNotificationGateway {
  Future<void> init();

  Future<void> showProgress(
    int? progress,
    int? max, {
    String? body,
    bool indeterminate,
  });

  Future<void> showCompletion(String message);

  Future<void> cancel();
}

/// 默认 gateway：包装 `FlutterLocalNotificationsPlugin`。
///
/// 通知 ID 888、渠道 `paper_whisper_sync`、标题/文案与 ongoing/progress
/// 语义和迁移前逐字保留。
class FlutterLocalNotificationsGateway implements SyncNotificationGateway {
  FlutterLocalNotificationsGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // Darwin (iOS) settings can be added here
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _plugin.initialize(settings: initializationSettings);
  }

  @override
  Future<void> showProgress(
    int? progress,
    int? max, {
    String? body,
    bool indeterminate = false,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          SyncNotificationService.channelId,
          SyncNotificationService.channelName,
          channelDescription: '显示同步状态和进度',
          importance:
              Importance.low, // Low = no sound/vibrate, good for progress
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: max ?? 100,
          progress: progress ?? 0,
          indeterminate: indeterminate || (progress == null && max == null),
          ongoing: true, // Prevent swipe away
          autoCancel: false,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _plugin.show(
      id: SyncNotificationService.notificationId,
      title: 'PaperWhisper 云同步',
      body: body ?? '正在同步中...',
      notificationDetails: platformChannelSpecifics,
    );
  }

  @override
  Future<void> showCompletion(String message) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          SyncNotificationService.channelId,
          SyncNotificationService.channelName,
          channelDescription: '显示同步状态和进度',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _plugin.show(
      id: SyncNotificationService.notificationId,
      title: '同步完成',
      body: message,
      notificationDetails: platformChannelSpecifics,
    );
  }

  @override
  Future<void> cancel() async {
    await _plugin.cancel(id: SyncNotificationService.notificationId);
  }
}

/// OS 通知服务：封装通知插件的初始化与进度/完成/取消展示。
///
/// 不包含 Dialog/Toast/BuildContext/permission_handler —— 通知权限
/// 申请与用户反馈由同步 UI 协调器（[SyncUiCoordinator]）处理。通知
/// ID 888、渠道 `paper_whisper_sync`、文案与 ongoing/progress 语义
/// 与原实现逐字保留。插件调用经 [SyncNotificationGateway] 转发，
/// 测试可注入记录型 fake 断言参数与平台守卫。
///
/// 平台守卫（Android/iOS）默认 [defaultIsSupportedPlatform]；测试可
/// 通过 [isSupportedPlatform] 谓词注入，无需依赖真实 dart:io 平台。
///
/// 迁移来源（原 `sync_provider.dart`）：
/// - `_initNotifications`            原（727-738）
/// - `_showNotification` 通知部分     原（1926-1964）
/// - `_showCompletionNotification`   原（1966-1987）
/// - `_cancelNotification`           原（1989-1993）
class SyncNotificationService {
  SyncNotificationService({
    SyncNotificationGateway? gateway,
    bool Function()? isSupportedPlatform,
  }) : _gateway = gateway ?? FlutterLocalNotificationsGateway(),
       _isSupportedPlatform = isSupportedPlatform ?? defaultIsSupportedPlatform;

  final SyncNotificationGateway _gateway;
  final bool Function() _isSupportedPlatform;

  static const int notificationId = 888;
  static const String channelId = 'paper_whisper_sync';
  static const String channelName = 'Sync Status';

  /// 默认平台守卫：仅 Android/iOS 支持 OS 通知。
  static bool defaultIsSupportedPlatform() =>
      Platform.isAndroid || Platform.isIOS;

  /// 初始化通知插件（仅受支持平台）。
  Future<void> init() async {
    if (_isSupportedPlatform()) {
      await _gateway.init();
    }
  }

  /// 展示同步进度通知（indeterminate 用于未确定总量阶段）。
  Future<void> showProgress(
    int? progress,
    int? max, {
    String? body,
    bool indeterminate = false,
  }) async {
    if (!_isSupportedPlatform()) return;
    await _gateway.showProgress(
      progress,
      max,
      body: body,
      indeterminate: indeterminate,
    );
  }

  /// 展示同步完成/失败通知。
  Future<void> showCompletion(String message) async {
    if (!_isSupportedPlatform()) return;
    await _gateway.showCompletion(message);
  }

  /// 取消同步通知。
  Future<void> cancel() async {
    if (!_isSupportedPlatform()) return;
    await _gateway.cancel();
  }
}
