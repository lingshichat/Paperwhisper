import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../providers/sync_provider.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_dialog.dart';
import 'package:paper_whisper_flutter/shared/widgets/skeuomorphic_toast.dart';
import '../application/save_sync_coordinator.dart';
import '../application/sync_run_result.dart';

/// 同步 UI 协调器（唯一负责通知权限说明、Dialog/Toast、手动同步与
/// 当前页面可见反馈）。
///
/// 职责边界：
/// - 通知权限说明对话框与申请（原 `SyncProvider.checkNotificationPermission`）；
/// - 手动同步命令（context-free）的结果翻译为用户 Toast 反馈；
/// - 保存后自动同步决策的即时 pending 提示与权限前置；
/// - 不持有任何延迟 Timer：context 只在单次动作期间使用，动作完成后
///   立即释放，禁止延迟回调持有页面 context。
///
/// Provider / Runner 不接收 BuildContext；本类位于 presentation 层，
/// 允许依赖 Widget / Toast / Dialog 与 permission_handler。
/// 迁移来源（原 `sync_provider.dart`）：`checkNotificationPermission`
/// （965-1012）与 `sync` 的权限检查、Toast 反馈分支（1014-1200）。
class SyncUiCoordinator {
  SyncUiCoordinator(this._context, {SaveSyncCoordinator? saveSyncCoordinator})
    : _saveSyncCoordinator = saveSyncCoordinator ?? const SaveSyncCoordinator();

  final BuildContext _context;

  /// 保存后同步决策协调器（context-free，可注入替身以便测试决策分支）。
  final SaveSyncCoordinator _saveSyncCoordinator;

  /// 检查并请求通知权限（强制）。
  ///
  /// 返回 true 表示已获得权限或无需权限（非移动平台），false 表示
  /// 用户未授权或取消。迁移来源：原 `SyncProvider.checkNotificationPermission`。
  Future<bool> checkNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    var status = await Permission.notification.status;
    if (status.isGranted) return true;

    // Show Explanation Dialog
    if (_context.mounted) {
      final bool? result = await showDialog<bool>(
        context: _context,
        barrierDismissible: true, // Allow click outside to cancel
        builder: (ctx) => SkeuomorphicDialog(
          title: '需要通知权限',
          headerIcon: Icons.notifications_active,
          content: const Text(
            '为了防止同步过程被系统中断，并让您直观地看到上传进度，我们需要申请通知栏权限。\n\n请授予通知权限以启用同步功能。',
          ),
          // Custom footer for single button
          footer: SizedBox(
            width: double.infinity,
            child: SkeuomorphicDialogButton(
              label: '去授予通知权限',
              onPressed: () async {
                Navigator.pop(ctx, true); // Close dialog first with flag
              },
            ),
          ),
        ),
      );

      if (result == true) {
        // User clicked "Enable"
        final newStatus = await Permission.notification.request();
        if (newStatus.isGranted) {
          return true;
        } else {
          if (_context.mounted) {
            SkeuomorphicToast.info(_context, '同步需要通知权限以保持后台运行');
          }
          return false;
        }
      }
    }

    return false; // Dialog dismissed or ignored
  }

  /// 手动同步（设置页「立即同步」、日记列表下拉刷新触发）。
  ///
  /// 流程：通知权限前置 → context-free `provider.sync()` → 结果翻译为
  /// Toast 反馈。原 `SyncProvider.sync` 内的权限检查、重入提示、连接
  /// 失败提示与成功/失败/pending 文案在此逐字保留。
  Future<SyncRunResult> runManualSync(SyncProvider provider) async {
    if (!_context.mounted) {
      return const SyncRunResult(status: SyncRunStatus.permissionDenied);
    }

    // Manually triggered sync: Check Permission First
    final hasPermission = await checkNotificationPermission();
    if (!hasPermission) {
      // User cancelled or denied permission. Abort silent.
      return const SyncRunResult(status: SyncRunStatus.permissionDenied);
    }

    if (!_context.mounted) {
      return const SyncRunResult(status: SyncRunStatus.permissionDenied);
    }

    final result = await provider.sync();

    if (!_context.mounted) return result;
    switch (result.status) {
      case SyncRunStatus.success:
        String statMsg =
            "已同步: ${result.processedDiaries}篇日记, ${result.processedMoments}篇随心记\n${result.processedImages}张图片, ${result.processedAudio}条语音";
        if (!result.hasChanges) {
          statMsg = "同步完成 (无变更)";
        }
        SkeuomorphicToast.success(_context, statMsg);
      case SyncRunStatus.failed:
        SkeuomorphicToast.error(_context, result.failureMessage);
      case SyncRunStatus.pending:
        SkeuomorphicToast.info(_context, '尚有 ${result.pendingCount} 项待同步');
      case SyncRunStatus.alreadySyncing:
        SkeuomorphicToast.info(_context, '正在同步中，请稍候...');
      case SyncRunStatus.connectionFailed:
        // 原实现：Toast 提示连接失败文案后抛出 Exception，由页面 catch
        // 展示「同步启动失败，请稍后重试」。现由协调器直接展示失败文案，
        // 页面 catch 仅兜底意外异常（见 sync_settings_page._syncNow）。
        SkeuomorphicToast.error(_context, result.failureMessage);
      case SyncRunStatus.notEnabled:
      case SyncRunStatus.needsAttention:
      case SyncRunStatus.proRequired:
      case SyncRunStatus.permissionDenied:
        // 静默：信任快照已反映状态，页面无需额外提示（与原实现一致）。
        break;
    }
    return result;
  }

  /// 保存后自动同步决策与即时反馈（日记/随心记保存路径共用）。
  ///
  /// 决策（刷新快照 → 配置/待同步计数分支）委托 context-free 的
  /// [SaveSyncCoordinator]；本方法只负责把 typed 决策翻译为
  /// Toast / 通知权限申请 / 自动同步触发，保留原调用点文案与触发时机：
  /// - 启用自动同步：准备同步提示 → 通知权限申请 → 30s 防抖自动同步
  ///   （自动同步由调度器静默执行，不持有 context，完成反馈走 OS 通知
  ///   与信任快照状态）；
  /// - 未启用自动同步但有 pending：即时提示「已保存，尚有 N 项待同步」；
  /// - 无 pending：仅提示保存成功。
  ///
  /// [savedToast] 保存成功文案（如「日记已保存」/「记录已保存」）；
  /// [preparingToast] 准备同步文案；[preparingToastAsInfo] 控制准备
  /// 提示的 Toast 级别（原实现日记为 success、随心记为 info）。
  Future<void> handleSaveAutoSync({
    required SyncProvider provider,
    required String savedToast,
    required String preparingToast,
    bool preparingToastAsInfo = false,
  }) async {
    final decision = await _saveSyncCoordinator.decideAfterSave(provider);
    if (!_context.mounted) return;
    switch (decision) {
      case SaveSyncAutoSync():
        if (preparingToastAsInfo) {
          SkeuomorphicToast.info(_context, preparingToast);
        } else {
          SkeuomorphicToast.success(_context, preparingToast);
        }
        if (!_context.mounted) return;
        final granted = await checkNotificationPermission();
        if (_context.mounted && granted) {
          unawaited(provider.requestAutoSync());
        }
      case SaveSyncPending(:final pendingCount):
        SkeuomorphicToast.info(_context, '已保存，尚有 $pendingCount 项待同步');
      case SaveSyncSaved():
        SkeuomorphicToast.success(_context, savedToast);
    }
  }

  /// 业务动作（如随心记聚合导出）后的自动同步请求。
  ///
  /// 仅在启用自动同步时申请通知权限并触发 30s 防抖同步，不额外展示
  /// Toast（原 `moments_page._handleAggregation` 的同步段语义）。
  /// 配置门禁委托 [SaveSyncCoordinator.shouldAutoSync]。
  Future<void> requestAutoSyncIfConfigured(SyncProvider provider) async {
    if (!_context.mounted) return;
    if (_saveSyncCoordinator.shouldAutoSync(provider)) {
      final granted = await checkNotificationPermission();
      if (_context.mounted && granted) {
        unawaited(provider.requestAutoSync());
      }
    }
  }
}
