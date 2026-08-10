import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot.dart';

/// 同步状态卡 typed presentation data（不含 Widget / Icon / Color）。
///
/// 对应 `sync_settings_page._buildTrustStatusCard` 的文案部分：
/// [title] 为状态标题，[lines] 为状态卡行文案。
class SyncStatusCardText {
  const SyncStatusCardText({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

/// 同步信任快照 → 展示文案格式化器（纯函数，无 I/O、无 BuildContext）。
///
/// 职责边界：
/// - 时间、平台、紧凑状态文案与状态卡文案全部为纯字符串转换；
/// - 不持有 Provider、不读取配置、不构建 Widget / Icon / Color；
/// - 逐字保持 settings 与 sync_settings 两处既有文案与分支语义。
///
/// 迁移来源：
/// - `settings_page._getSyncStatusText` / `_formatSyncPlatform` / `_formatTime`
/// - `sync_settings_page._buildTrustStatusCard` / `_formatSyncTime` / `_formatSyncPlatform`
class SyncStatusFormatter {
  const SyncStatusFormatter();

  /// 平台标签：'webdav' → 'WebDAV'，'s3' → 'S3'，其余返回 null。
  String? formatPlatform(String? platform) {
    switch (platform) {
      case 'webdav':
        return 'WebDAV';
      case 's3':
        return 'S3';
      default:
        return null;
    }
  }

  /// settings 风格时间：`yyyy-M-d H:mm`（分钟不补零）。
  String formatTime(DateTime time) {
    return '${time.year}-${time.month}-${time.day} ${time.hour}:${time.minute}';
  }

  /// sync_settings 风格时间：`yyyy-M-d H:mm`（分钟补零）。
  String formatTimePadded(DateTime time) {
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.year}-${time.month}-${time.day} ${time.hour}:$minute';
  }

  /// 最近一次成功同步行：`最近一次成功同步：{time}（{platform}）`，
  /// platform 为 null 时省略括号。
  String formatLastSyncLine(
    DateTime at,
    String? platform, {
    required bool padMinutes,
  }) {
    final time = padMinutes ? formatTimePadded(at) : formatTime(at);
    final p = formatPlatform(platform);
    return '最近一次成功同步：$time${p == null ? '' : '（$p）'}';
  }

  /// settings 紧凑状态文案（7 状态，逐字保持 `_getSyncStatusText` 行为）。
  String formatCompactStatus(SyncTrustSnapshot snapshot) {
    if (snapshot.state == SyncTrustState.notEnabled) return '未启用';
    if (snapshot.state == SyncTrustState.syncing) return '同步中...';
    if (snapshot.state == SyncTrustState.localChangesPending) {
      return '尚有 ${snapshot.totalPendingCount} 项待同步';
    }
    if (snapshot.state == SyncTrustState.syncFailed) {
      return snapshot.failureReason ?? '同步失败，内容仍保留在本地';
    }
    if (snapshot.state == SyncTrustState.needsAttention) {
      return snapshot.failureReason ?? '需要检查同步配置';
    }
    if (snapshot.lastSuccessfulSyncAt != null) {
      return formatLastSyncLine(
        snapshot.lastSuccessfulSyncAt!,
        snapshot.lastSuccessfulSyncPlatform,
        padMinutes: false,
      );
    }
    return '已启用';
  }

  /// sync_settings 状态卡 typed data（title + lines，不含 Icon / Color）。
  SyncStatusCardText buildStatusCard(SyncTrustSnapshot snapshot) {
    final String title;
    switch (snapshot.state) {
      case SyncTrustState.notEnabled:
        title = '同步未启用';
        break;
      case SyncTrustState.localChangesPending:
        title = '本地仍有内容待同步';
        break;
      case SyncTrustState.syncing:
        title = '正在同步';
        break;
      case SyncTrustState.syncedSuccessfully:
        title = '同步状态正常';
        break;
      case SyncTrustState.syncFailed:
        title = '同步失败';
        break;
      case SyncTrustState.needsAttention:
        title = '需要检查同步配置';
        break;
    }

    final lines = <String>[
      if (snapshot.totalPendingCount > 0)
        '尚有 ${snapshot.totalPendingCount} 项待同步',
      if (snapshot.lastSuccessfulSyncAt != null)
        formatLastSyncLine(
          snapshot.lastSuccessfulSyncAt!,
          snapshot.lastSuccessfulSyncPlatform,
          padMinutes: true,
        ),
      if (snapshot.failureReason != null && snapshot.failureReason!.isNotEmpty)
        snapshot.failureReason!,
      if (snapshot.state == SyncTrustState.syncFailed) '可使用下方“立即同步”重试',
      if (snapshot.state == SyncTrustState.notEnabled) '启用后即可把本地内容同步到云端',
    ];

    return SyncStatusCardText(title: title, lines: lines);
  }
}
