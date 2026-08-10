import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot.dart';

/// 信任状态机单次判定结果。
class SyncTrustResolution {
  const SyncTrustResolution({
    required this.state,
    required this.configurationInvalid,
    this.failureReason,
  });

  final SyncTrustState state;
  final bool configurationInvalid;
  final String? failureReason;
}

/// 同步信任状态机（纯计算，无 IO/持久化依赖，可独立单测）。
///
/// 从 `SyncProvider.refreshTrustSnapshot`（原 609-681）逐字迁移
/// 八分支优先级判定，输入由调用方（Provider/Store）准备，输出
/// 决定下一个 `SyncTrustSnapshot`。持久化编排仍由调用方负责。
///
/// 分支优先级（与原实现一致）：
/// 1. 未启用 → notEnabled
/// 2. 凭据缺失 → needsAttention + configurationInvalid
/// 3. override needsAttention
/// 4. override syncing
/// 5. 有失败原因 → syncFailed
/// 6. 有 pending 变更 → localChangesPending
/// 7. 当前作用域有上次同步时间 → syncedSuccessfully
/// 8. 兜底 → needsAttention
class SyncTrustEngine {
  const SyncTrustEngine();

  /// 计算下一个信任状态。
  ///
  /// [enabled]/[hasRequiredCredentials] 由当前 `SyncConfig` 派生；
  /// [hasPendingChanges] 由 pending 计数派生；
  /// [hasLastSyncTime] 表示当前作用域是否存在上次成功同步时间；
  /// [currentState] 为当前 snapshot 状态（override 为空时兜底沿用）；
  /// [configIssueMessage] 由 `SyncErrorClassifier.configurationIssueMessage`
  /// 提供（凭据缺失分支的默认失败文案）。
  SyncTrustResolution resolve({
    required bool enabled,
    required bool hasRequiredCredentials,
    required bool hasPendingChanges,
    required bool hasLastSyncTime,
    required SyncTrustState currentState,
    required String? configIssueMessage,
    SyncTrustState? overrideState,
    String? failureReason,
    bool configurationInvalid = false,
    bool clearFailureReason = false,
  }) {
    SyncTrustState nextState = overrideState ?? currentState;
    bool nextConfigurationInvalid = configurationInvalid;
    String? nextFailureReason = failureReason;

    if (!enabled) {
      nextState = SyncTrustState.notEnabled;
      nextConfigurationInvalid = false;
      // 原实现此处为 `clearFailureReason && nextFailureReason == null`
      // 的自反判断（恒不生效），语义上不修改失败原因，故省略。
    } else if (!hasRequiredCredentials) {
      nextState = SyncTrustState.needsAttention;
      nextConfigurationInvalid = true;
      nextFailureReason ??= configIssueMessage;
    } else if (overrideState == SyncTrustState.needsAttention) {
      nextState = SyncTrustState.needsAttention;
      nextConfigurationInvalid = configurationInvalid;
    } else if (overrideState == SyncTrustState.syncing) {
      nextState = SyncTrustState.syncing;
      nextConfigurationInvalid = false;
    } else if (failureReason != null) {
      nextState = SyncTrustState.syncFailed;
      nextConfigurationInvalid = configurationInvalid;
    } else if (hasPendingChanges) {
      nextState = SyncTrustState.localChangesPending;
      nextConfigurationInvalid = false;
      if (clearFailureReason) {
        nextFailureReason = null;
      }
    } else if (hasLastSyncTime) {
      nextState = SyncTrustState.syncedSuccessfully;
      nextConfigurationInvalid = false;
      if (clearFailureReason) {
        nextFailureReason = null;
      }
    } else {
      nextState = SyncTrustState.needsAttention;
      nextConfigurationInvalid = false;
      nextFailureReason = clearFailureReason ? null : nextFailureReason;
    }

    return SyncTrustResolution(
      state: nextState,
      configurationInvalid: nextConfigurationInvalid,
      failureReason: nextFailureReason,
    );
  }
}
