import 'package:paper_whisper_flutter/features/sync/application/sync_provider.dart';

/// 保存后同步决策（sealed typed outcome，context-free）。
///
/// 由 [SyncUiCoordinator] 消费并翻译为 Toast / 权限 / 自动同步动作；
/// 本类型不携带任何 UI 依赖。
sealed class SaveSyncDecision {
  const SaveSyncDecision();
}

/// 启用自动同步：应展示准备文案、申请通知权限并触发防抖自动同步。
class SaveSyncAutoSync extends SaveSyncDecision {
  const SaveSyncAutoSync();
}

/// 未启用自动同步但有待同步内容：提示待同步计数。
class SaveSyncPending extends SaveSyncDecision {
  const SaveSyncPending({required this.pendingCount});

  final int pendingCount;
}

/// 无待同步内容：仅提示保存成功。
class SaveSyncSaved extends SaveSyncDecision {
  const SaveSyncSaved();
}

/// 保存后自动同步决策协调器（context-free）。
///
/// 职责边界：
/// - 刷新信任快照并按配置/待同步计数返回 typed 决策；
/// - 不持有 BuildContext、不弹 Toast/Dialog、不申请权限；
/// - 触发自动同步一律走 provider 的 context-free `requestAutoSync` 命令；
/// - 权限前置、Toast/Dialog 反馈由 presentation 层 [SyncUiCoordinator] 负责。
///
/// 迁移来源：原 `SyncUiCoordinator.handleSaveAutoSync` 的决策分支
/// （refreshTrustSnapshot → 配置判断 → pending 计数 → 三分支），
/// 逐字保持分支语义：
/// - 启用自动同步（enabled && autoSync && isConfigured）→ 自动同步；
/// - 未启用自动同步但 enabled 且 pendingCount > 0 → 待同步提示；
/// - 其余 → 仅保存成功。
class SaveSyncCoordinator {
  const SaveSyncCoordinator();

  /// 保存后决策：先刷新信任快照，再按原语义三分支。
  Future<SaveSyncDecision> decideAfterSave(SyncProvider provider) async {
    await provider.refreshTrustSnapshot();
    final pendingCount = provider.trustSnapshot.totalPendingCount;

    if (provider.config.enabled &&
        provider.config.autoSync &&
        provider.isConfigured) {
      return const SaveSyncAutoSync();
    }
    if (provider.config.enabled && pendingCount > 0) {
      return SaveSyncPending(pendingCount: pendingCount);
    }
    return const SaveSyncSaved();
  }

  /// 聚合导出等业务动作后的自动同步门禁（原
  /// `SyncUiCoordinator.requestAutoSyncIfConfigured` 的条件语义）。
  bool shouldAutoSync(SyncProvider provider) =>
      provider.config.autoSync && provider.isConfigured;
}
