/// 同步命令执行状态（context-free 命令的 typed result）。
///
/// 由 `SyncProvider.sync` 返回，页面 / `SyncUiCoordinator` 翻译为用户反馈；
/// Provider 不再直接展示 Toast/Dialog，也不接收 BuildContext。
enum SyncRunStatus {
  /// 同步成功完成（无未解决工作）。
  success,

  /// 同步完成但存在失败，信任态进入 `syncFailed`。
  failed,

  /// 同步完成但仍有待同步内容（无失败，如自动同步流量保护跳过）。
  pending,

  /// 未启用同步，命令被跳过（信任态保持/变为 notEnabled）。
  notEnabled,

  /// 配置/凭据缺失，命令被跳过（信任态 needsAttention）。
  needsAttention,

  /// 需要赞助才能使用云同步。
  proRequired,

  /// 已有同步进行中，本次命令被跳过。
  alreadySyncing,

  /// 连接失败，同步未执行。
  connectionFailed,

  /// 手动同步被用户取消（通知权限未授予）。
  permissionDenied,
}

/// 单次同步命令的结果汇总。
///
/// 携带页面反馈所需的统计与文案数据：成功时的分类操作计数、
/// 待同步总数与面向用户的失败文案。持久化与信任快照更新由
/// Provider 在返回结果前完成，本结果只做 UI 翻译输入。
class SyncRunResult {
  const SyncRunResult({
    required this.status,
    this.processedDiaries = 0,
    this.processedMoments = 0,
    this.processedImages = 0,
    this.processedAudio = 0,
    this.pendingCount = 0,
    this.failureMessage = '',
  });

  final SyncRunStatus status;

  /// 成功时各分类已完成的操作计数（原 `_statDiaries` 等，供成功文案）。
  final int processedDiaries;
  final int processedMoments;
  final int processedImages;
  final int processedAudio;

  /// 同步结束后的待同步总数（`trustSnapshot.totalPendingCount`）。
  final int pendingCount;

  /// 面向用户的失败/状态文案（原 `_buildUserSafeFailureReason` 等）。
  final String failureMessage;

  /// 是否存在实际变更（成功文案区分「已同步: ...」与「同步完成 (无变更)」）。
  bool get hasChanges =>
      processedDiaries + processedMoments + processedImages + processedAudio >
      0;
}
