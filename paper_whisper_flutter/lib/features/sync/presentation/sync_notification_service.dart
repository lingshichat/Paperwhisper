import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// OS 通知服务：只封装 flutter_local_notifications 的初始化与
/// 进度/完成/取消展示。
///
/// 不包含 Dialog/Toast/BuildContext/permission_handler —— 通知权限
/// 申请与用户反馈由同步 UI 协调器处理。通知 ID 888、渠道
/// `paper_whisper_sync`、文案与 ongoing/progress 语义与原实现逐字保留。
///
/// 迁移来源（原 `sync_provider.dart`）：
/// - `_initNotifications`            原（727-738）
/// - `_showNotification` 通知部分     原（1926-1964）
/// - `_showCompletionNotification`   原（1966-1987）
/// - `_cancelNotification`           原（1989-1993）
class SyncNotificationService {
  SyncNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const int notificationId = 888;
  static const String channelId = 'paper_whisper_sync';
  static const String channelName = 'Sync Status';

  /// 初始化通知插件（仅 Android/iOS）。
  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // Darwin (iOS) settings can be added here
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    if (Platform.isAndroid || Platform.isIOS) {
      await _plugin.initialize(settings: initializationSettings);
    }
  }

  /// 展示同步进度通知（indeterminate 用于未确定总量阶段）。
  Future<void> showProgress(
    int? progress,
    int? max, {
    String? body,
    bool indeterminate = false,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          channelId,
          channelName,
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
      id: notificationId,
      title: 'PaperWhisper 云同步',
      body: body ?? '正在同步中...',
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// 展示同步完成/失败通知。
  Future<void> showCompletion(String message) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          channelId,
          channelName,
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
      id: notificationId,
      title: '同步完成',
      body: message,
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// 取消同步通知。
  Future<void> cancel() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await _plugin.cancel(id: notificationId);
  }
}
