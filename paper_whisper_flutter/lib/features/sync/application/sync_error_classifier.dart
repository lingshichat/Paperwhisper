import 'sync_run_outcome.dart';

/// 同步错误分类（纯函数，无 Flutter/UI 依赖，可独立单测）。
///
/// 所有判定逻辑与用户文案均从 `SyncProvider` 原实现逐字迁移：
/// - `configurationIssueMessage`      原 `_configurationIssueMessage`（348-353）
/// - `isLikelyConfigurationFailure`   原 `_isLikelyConfigurationFailure`（355-372）
/// - `buildConnectionFailureMessage`  原 `_buildConnectionFailureMessage`（374-389）
/// - `isRemoteSourceAlreadyMissing`   原 `_isRemoteSourceAlreadyMissing`（391-398）
/// - `buildUserSafeFailureReason`     原 `_buildUserSafeFailureReason`（710-731）
class SyncErrorClassifier {
  const SyncErrorClassifier();

  /// 配置异常的用户安全文案。
  /// [enabled] 对应原实现的 `_config.enabled`：未启用时返回「同步未启用」。
  String configurationIssueMessage({required bool enabled}) {
    if (!enabled) {
      return '同步未启用';
    }
    return '配置异常，请检查账号或服务器地址';
  }

  /// 判定错误文本是否属于配置/凭据类失败（401/403/签名/桶不存在等）。
  bool isLikelyConfigurationFailure(String? errorText) {
    final normalized = (errorText ?? '').toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('unauthorized') ||
        normalized.contains('forbidden') ||
        normalized.contains('invalidaccesskey') ||
        normalized.contains('invalidaccesskeyid') ||
        normalized.contains('signature') ||
        normalized.contains('access denied') ||
        normalized.contains('missing credentials') ||
        normalized.contains('bucket does not exist') ||
        normalized.contains('nosuchbucket');
  }

  /// 连接失败文案分类：配置异常 → 网络异常 → 通用连接失败。
  String buildConnectionFailureMessage(
    String? errorText, {
    required bool enabled,
  }) {
    final normalized = (errorText ?? '').toLowerCase();
    if (isLikelyConfigurationFailure(normalized)) {
      return configurationIssueMessage(enabled: enabled);
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('network') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('connection reset')) {
      return '网络异常，请稍后重试';
    }
    return '连接失败，请稍后重试';
  }

  /// 判定远端源是否已缺失（404/NoSuchKey/Copy Source must exist 等），
  /// 用于归档等场景容忍「源已不存在」。
  bool isRemoteSourceAlreadyMissing(Object error) {
    final text = error.toString();
    return text.contains('404') ||
        text.contains('Not Found') ||
        text.contains('NoSuchKey') ||
        text.contains('Copy Source must exist') ||
        text.contains('source bucket and key');
  }

  /// 面向用户的失败原因文案。
  /// [configurationInvalid] 对应原实现的 `_trustSnapshot.configurationInvalid`，
  /// [hasRequiredCredentials] 对应原实现的 `_config.hasRequiredCredentials`。
  String buildUserSafeFailureReason(
    SyncRunOutcome outcome, {
    required bool configurationInvalid,
    required bool hasRequiredCredentials,
  }) {
    if (configurationInvalid || !hasRequiredCredentials) {
      return '配置异常，请检查账号或服务器地址';
    }

    final errorText = outcome.errors.join(' ');
    if (errorText.contains('401') || errorText.contains('Unauthorized')) {
      return '配置异常，请检查账号或服务器地址';
    }
    if (errorText.contains('403') || errorText.contains('Forbidden')) {
      return '同步失败，内容仍保留在本地';
    }
    if (errorText.contains('SocketException') ||
        errorText.contains('Network') ||
        errorText.contains('Timeout')) {
      return '网络异常，请稍后重试';
    }
    if (outcome.skippedOperations > 0) {
      return '尚有内容待同步';
    }
    return '同步失败，内容仍保留在本地';
  }
}
