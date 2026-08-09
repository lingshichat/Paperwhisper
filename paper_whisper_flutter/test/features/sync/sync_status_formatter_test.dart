import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_status_formatter.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';

/// SyncStatusFormatter 单元测试（阶段 4 L0 第二批）。
///
/// 契约覆盖（逐字文案断言）：
/// - formatPlatform：webdav/s3 标签，大小写未知与 null 返回 null；
/// - formatTime（分钟不补零）与 formatTimePadded（仅分钟补零）；
/// - formatLastSyncLine：补零开关、平台括号、null/未知平台省略括号；
/// - formatCompactStatus：SyncTrustSnapshot 全部状态、pending 各计数累加、
///   空/非空 failureReason、成功有无 platform；
/// - buildStatusCard：6 状态标题、行顺序（pending → 最近成功 → reason →
///   重试/启用引导）、空 reason 过滤、成功平台括号、空卡无行。
///
/// 纯函数测试，无 I/O、无 BuildContext、无插件。
void main() {
  const formatter = SyncStatusFormatter();

  group('formatPlatform', () {
    test('webdav → WebDAV，s3 → S3', () {
      expect(formatter.formatPlatform('webdav'), 'WebDAV');
      expect(formatter.formatPlatform('s3'), 'S3');
    });

    test('大小写未知、空串与 null 均返回 null', () {
      expect(formatter.formatPlatform('WebDAV'), isNull);
      expect(formatter.formatPlatform('WebDav'), isNull);
      expect(formatter.formatPlatform('S3'), isNull);
      expect(formatter.formatPlatform(''), isNull);
      expect(formatter.formatPlatform('dropbox'), isNull);
      expect(formatter.formatPlatform(null), isNull);
    });
  });

  group('formatTime / formatTimePadded', () {
    test('formatTime 分钟不补零，其余字段也不补零', () {
      expect(formatter.formatTime(DateTime(2026, 3, 5, 9, 7)), '2026-3-5 9:7');
      expect(
        formatter.formatTime(DateTime(2026, 12, 25, 23, 59)),
        '2026-12-25 23:59',
      );
    });

    test('formatTimePadded 仅分钟补零', () {
      expect(
        formatter.formatTimePadded(DateTime(2026, 3, 5, 9, 7)),
        '2026-3-5 9:07',
      );
      expect(
        formatter.formatTimePadded(DateTime(2026, 3, 5, 9, 0)),
        '2026-3-5 9:00',
      );
      expect(
        formatter.formatTimePadded(DateTime(2026, 12, 25, 23, 59)),
        '2026-12-25 23:59',
      );
    });
  });

  group('formatLastSyncLine', () {
    final at = DateTime(2026, 3, 5, 9, 7);

    test('padMinutes 控制补零', () {
      expect(
        formatter.formatLastSyncLine(at, 'webdav', padMinutes: true),
        '最近一次成功同步：2026-3-5 9:07（WebDAV）',
      );
      expect(
        formatter.formatLastSyncLine(at, 'webdav', padMinutes: false),
        '最近一次成功同步：2026-3-5 9:7（WebDAV）',
      );
    });

    test('s3 平台带（S3）', () {
      expect(
        formatter.formatLastSyncLine(
          DateTime(2026, 3, 5, 9, 7),
          's3',
          padMinutes: true,
        ),
        '最近一次成功同步：2026-3-5 9:07（S3）',
      );
    });

    test('null 与未知平台省略括号', () {
      expect(
        formatter.formatLastSyncLine(at, null, padMinutes: true),
        '最近一次成功同步：2026-3-5 9:07',
      );
      expect(
        formatter.formatLastSyncLine(at, 'unknown', padMinutes: true),
        '最近一次成功同步：2026-3-5 9:07',
      );
    });
  });

  group('formatCompactStatus（逐状态文案）', () {
    test('notEnabled → 未启用', () {
      expect(
        formatter.formatCompactStatus(
          const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
        ),
        '未启用',
      );
    });

    test('syncing → 同步中...', () {
      expect(
        formatter.formatCompactStatus(
          const SyncTrustSnapshot(state: SyncTrustState.syncing),
        ),
        '同步中...',
      );
    });

    test('localChangesPending → 尚有 N 项待同步（各计数累加）', () {
      const snapshot = SyncTrustSnapshot(
        state: SyncTrustState.localChangesPending,
        pendingDiaryCount: 2,
        pendingMomentCount: 1,
        pendingImageCount: 4,
        pendingAudioCount: 3,
      );
      expect(formatter.formatCompactStatus(snapshot), '尚有 10 项待同步');
    });

    test('syncFailed：非空 failureReason 用之，空则默认文案', () {
      expect(
        formatter.formatCompactStatus(
          const SyncTrustSnapshot(
            state: SyncTrustState.syncFailed,
            failureReason: '网络异常，请稍后重试',
          ),
        ),
        '网络异常，请稍后重试',
      );
      expect(
        formatter.formatCompactStatus(
          const SyncTrustSnapshot(state: SyncTrustState.syncFailed),
        ),
        '同步失败，内容仍保留在本地',
      );
    });

    test('needsAttention：非空 failureReason 用之，空则默认文案', () {
      expect(
        formatter.formatCompactStatus(
          const SyncTrustSnapshot(
            state: SyncTrustState.needsAttention,
            failureReason: '配置异常，请检查账号或服务器地址',
          ),
        ),
        '配置异常，请检查账号或服务器地址',
      );
      expect(
        formatter.formatCompactStatus(
          const SyncTrustSnapshot(state: SyncTrustState.needsAttention),
        ),
        '需要检查同步配置',
      );
    });

    test('syncedSuccessfully：有最近成功时间 → 不补零 last line', () {
      final snapshot = SyncTrustSnapshot(
        state: SyncTrustState.syncedSuccessfully,
        lastSuccessfulSyncAt: DateTime(2026, 3, 5, 9, 7),
        lastSuccessfulSyncPlatform: 'webdav',
      );
      expect(
        formatter.formatCompactStatus(snapshot),
        '最近一次成功同步：2026-3-5 9:7（WebDAV）',
      );
    });

    test('syncedSuccessfully：无最近成功时间 → 已启用', () {
      expect(
        formatter.formatCompactStatus(
          const SyncTrustSnapshot(state: SyncTrustState.syncedSuccessfully),
        ),
        '已启用',
      );
    });

    test('状态优先级：syncFailed 的 failureReason 优先于最近成功时间', () {
      final snapshot = SyncTrustSnapshot(
        state: SyncTrustState.syncFailed,
        failureReason: '某失败原因',
        lastSuccessfulSyncAt: DateTime(2026, 3, 5, 9, 7),
      );
      expect(formatter.formatCompactStatus(snapshot), '某失败原因');
    });
  });

  group('buildStatusCard', () {
    test('6 状态标题逐一', () {
      expect(
        formatter
            .buildStatusCard(
              const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
            )
            .title,
        '同步未启用',
      );
      expect(
        formatter
            .buildStatusCard(
              const SyncTrustSnapshot(
                state: SyncTrustState.localChangesPending,
              ),
            )
            .title,
        '本地仍有内容待同步',
      );
      expect(
        formatter
            .buildStatusCard(
              const SyncTrustSnapshot(state: SyncTrustState.syncing),
            )
            .title,
        '正在同步',
      );
      expect(
        formatter
            .buildStatusCard(
              const SyncTrustSnapshot(state: SyncTrustState.syncedSuccessfully),
            )
            .title,
        '同步状态正常',
      );
      expect(
        formatter
            .buildStatusCard(
              const SyncTrustSnapshot(state: SyncTrustState.syncFailed),
            )
            .title,
        '同步失败',
      );
      expect(
        formatter
            .buildStatusCard(
              const SyncTrustSnapshot(state: SyncTrustState.needsAttention),
            )
            .title,
        '需要检查同步配置',
      );
    });

    test('行顺序：pending → 最近成功 → failureReason → 重试行', () {
      final snapshot = SyncTrustSnapshot(
        state: SyncTrustState.syncFailed,
        pendingDiaryCount: 1,
        lastSuccessfulSyncAt: DateTime(2026, 3, 5, 9, 7),
        lastSuccessfulSyncPlatform: 's3',
        failureReason: '网络异常，请稍后重试',
      );
      final card = formatter.buildStatusCard(snapshot);
      expect(card.title, '同步失败');
      expect(card.lines, [
        '尚有 1 项待同步',
        '最近一次成功同步：2026-3-5 9:07（S3）',
        '网络异常，请稍后重试',
        '可使用下方“立即同步”重试',
      ]);
    });

    test('pending 行各计数累加', () {
      final snapshot = SyncTrustSnapshot(
        state: SyncTrustState.localChangesPending,
        pendingDiaryCount: 2,
        pendingMomentCount: 1,
        pendingImageCount: 4,
        pendingAudioCount: 3,
      );
      final card = formatter.buildStatusCard(snapshot);
      expect(card.lines, ['尚有 10 项待同步']);
    });

    test('空 failureReason 被过滤，非空保留', () {
      final withEmpty = formatter.buildStatusCard(
        const SyncTrustSnapshot(
          state: SyncTrustState.syncFailed,
          failureReason: '',
        ),
      );
      expect(withEmpty.lines, ['可使用下方“立即同步”重试']);

      final withReason = formatter.buildStatusCard(
        const SyncTrustSnapshot(
          state: SyncTrustState.syncFailed,
          failureReason: '某原因',
        ),
      );
      expect(withReason.lines, ['某原因', '可使用下方“立即同步”重试']);
    });

    test('notEnabled：启用引导行；有 pending 时 pending 行在前', () {
      final card = formatter.buildStatusCard(
        const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
      );
      expect(card.lines, ['启用后即可把本地内容同步到云端']);

      final withPending = formatter.buildStatusCard(
        const SyncTrustSnapshot(
          state: SyncTrustState.notEnabled,
          pendingDiaryCount: 3,
        ),
      );
      expect(withPending.lines, ['尚有 3 项待同步', '启用后即可把本地内容同步到云端']);
    });

    test('成功：platform 非空带括号，null 省略', () {
      final withPlatform = formatter.buildStatusCard(
        SyncTrustSnapshot(
          state: SyncTrustState.syncedSuccessfully,
          lastSuccessfulSyncAt: DateTime(2026, 3, 5, 9, 7),
          lastSuccessfulSyncPlatform: 'webdav',
        ),
      );
      expect(withPlatform.lines, ['最近一次成功同步：2026-3-5 9:07（WebDAV）']);

      final noPlatform = formatter.buildStatusCard(
        SyncTrustSnapshot(
          state: SyncTrustState.syncedSuccessfully,
          lastSuccessfulSyncAt: DateTime(2026, 3, 5, 9, 7),
        ),
      );
      expect(noPlatform.lines, ['最近一次成功同步：2026-3-5 9:07']);
    });

    test('空卡：syncedSuccessfully 无时间无 pending 无 reason → 仅标题无行', () {
      final card = formatter.buildStatusCard(
        const SyncTrustSnapshot(state: SyncTrustState.syncedSuccessfully),
      );
      expect(card.title, '同步状态正常');
      expect(card.lines, isEmpty);
    });

    test('syncing 空行；needsAttention 仅 reason 行', () {
      final syncing = formatter.buildStatusCard(
        const SyncTrustSnapshot(state: SyncTrustState.syncing),
      );
      expect(syncing.lines, isEmpty);

      final attention = formatter.buildStatusCard(
        const SyncTrustSnapshot(
          state: SyncTrustState.needsAttention,
          failureReason: '配置异常，请检查账号或服务器地址',
        ),
      );
      expect(attention.lines, ['配置异常，请检查账号或服务器地址']);
    });
  });
}
