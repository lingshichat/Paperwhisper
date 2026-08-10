import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_trust_engine.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot.dart';

/// SyncTrustEngine 八分支优先级与 configurationInvalid / failureReason
/// 清理矩阵测试（迁移自 `SyncProvider.refreshTrustSnapshot` 原判定链）。
void main() {
  const engine = SyncTrustEngine();
  const configIssueMessage = '配置异常，请检查账号或服务器地址';

  SyncTrustResolution resolve({
    bool enabled = true,
    bool hasRequiredCredentials = true,
    bool hasPendingChanges = false,
    bool hasLastSyncTime = false,
    SyncTrustState currentState = SyncTrustState.syncedSuccessfully,
    SyncTrustState? overrideState,
    String? failureReason,
    bool configurationInvalid = false,
    bool clearFailureReason = false,
  }) {
    return engine.resolve(
      enabled: enabled,
      hasRequiredCredentials: hasRequiredCredentials,
      hasPendingChanges: hasPendingChanges,
      hasLastSyncTime: hasLastSyncTime,
      currentState: currentState,
      configIssueMessage: configIssueMessage,
      overrideState: overrideState,
      failureReason: failureReason,
      configurationInvalid: configurationInvalid,
      clearFailureReason: clearFailureReason,
    );
  }

  group('八分支优先级', () {
    test('分支1：未启用 -> notEnabled（最高优先级，清除配置异常标记）', () {
      final r = resolve(
        enabled: false,
        hasRequiredCredentials: true,
        hasPendingChanges: true,
        hasLastSyncTime: true,
        currentState: SyncTrustState.syncing,
        overrideState: SyncTrustState.syncing,
        failureReason: '旧错误',
        configurationInvalid: true,
      );
      expect(r.state, SyncTrustState.notEnabled);
      expect(r.configurationInvalid, isFalse, reason: '未启用必须清除配置异常');
      expect(r.failureReason, '旧错误', reason: '原实现不清除失败原因');
    });

    test('分支2：凭据缺失 -> needsAttention + configurationInvalid + 默认文案', () {
      final r = resolve(
        hasRequiredCredentials: false,
        hasPendingChanges: true,
        hasLastSyncTime: true,
        currentState: SyncTrustState.syncedSuccessfully,
      );
      expect(r.state, SyncTrustState.needsAttention);
      expect(r.configurationInvalid, isTrue);
      expect(r.failureReason, configIssueMessage);
    });

    test('分支2：已有失败原因时不被默认文案覆盖', () {
      final r = resolve(hasRequiredCredentials: false, failureReason: '自定义原因');
      expect(r.state, SyncTrustState.needsAttention);
      expect(r.failureReason, '自定义原因', reason: '??= 语义不得覆盖既有原因');
    });

    test('分支3：override needsAttention 优先于失败原因与 pending', () {
      final r = resolve(
        hasPendingChanges: true,
        hasLastSyncTime: true,
        overrideState: SyncTrustState.needsAttention,
        failureReason: '网络错误',
        configurationInvalid: true,
      );
      expect(r.state, SyncTrustState.needsAttention);
      expect(r.configurationInvalid, isTrue, reason: 'override 分支保持传入标记');
      expect(r.failureReason, '网络错误');
    });

    test('分支4：override syncing 清除配置异常标记', () {
      final r = resolve(
        hasPendingChanges: true,
        overrideState: SyncTrustState.syncing,
        failureReason: '旧错误',
        configurationInvalid: true,
      );
      expect(r.state, SyncTrustState.syncing);
      expect(r.configurationInvalid, isFalse);
    });

    test('分支5：failureReason 优先于 pending 与 lastSyncTime', () {
      final r = resolve(
        hasPendingChanges: true,
        hasLastSyncTime: true,
        failureReason: '连接失败',
        configurationInvalid: true,
      );
      expect(r.state, SyncTrustState.syncFailed);
      expect(r.configurationInvalid, isTrue, reason: '失败分支保持配置标记');
      expect(r.failureReason, '连接失败');
    });

    test('分支6：无失败原因且有 pending -> localChangesPending', () {
      final r = resolve(hasPendingChanges: true, hasLastSyncTime: true);
      expect(r.state, SyncTrustState.localChangesPending);
      expect(r.configurationInvalid, isFalse);
    });

    test('分支7：无 pending 且有上次同步时间 -> syncedSuccessfully', () {
      final r = resolve(
        hasPendingChanges: false,
        hasLastSyncTime: true,
        currentState: SyncTrustState.needsAttention,
      );
      expect(r.state, SyncTrustState.syncedSuccessfully);
      expect(r.configurationInvalid, isFalse);
    });

    test('分支8：兜底 -> needsAttention', () {
      final r = resolve(
        hasPendingChanges: false,
        hasLastSyncTime: false,
        currentState: SyncTrustState.syncedSuccessfully,
      );
      expect(r.state, SyncTrustState.needsAttention);
      expect(r.configurationInvalid, isFalse);
    });
  });

  group('failureReason 优先级与清理契约', () {
    test('failureReason 非空时永远 syncFailed，pending/lastSyncTime 无法拉出失败态', () {
      // 即使同时存在 pending 与历史同步记录，失败原因也不被静默清除
      final r = resolve(
        hasPendingChanges: true,
        hasLastSyncTime: true,
        failureReason: '连接失败',
      );
      expect(r.state, SyncTrustState.syncFailed);
      expect(r.failureReason, '连接失败');
    });

    test('failureReason 非空时 clearFailureReason 不改变 syncFailed 结果', () {
      final r = resolve(
        hasPendingChanges: true,
        failureReason: '连接失败',
        clearFailureReason: true,
      );
      expect(r.state, SyncTrustState.syncFailed);
      expect(r.failureReason, '连接失败');
    });

    test('failureReason 为空且有 pending -> localChangesPending 且返回 null 失败原因', () {
      final r = resolve(hasPendingChanges: true);
      expect(r.state, SyncTrustState.localChangesPending);
      expect(r.failureReason, isNull);
    });

    test(
      'failureReason 为空且有 lastSyncTime -> syncedSuccessfully 且返回 null 失败原因',
      () {
        final r = resolve(hasLastSyncTime: true);
        expect(r.state, SyncTrustState.syncedSuccessfully);
        expect(r.failureReason, isNull);
      },
    );

    test('failureReason 为空且兜底 -> needsAttention 且返回 null 失败原因', () {
      final r = resolve();
      expect(r.state, SyncTrustState.needsAttention);
      expect(r.failureReason, isNull);
    });

    test('clearFailureReason 参数不影响引擎输出（真正清理在 Provider copyWith 层）', () {
      // 引擎仅在 failureReason == null 时才能到达非失败分支，此时
      // nextFailureReason 本就为 null；clearFailureReason 的生效点在
      // Provider `_updateTrustSnapshot(copyWith(clearFailureReason: ...))`。
      final r1 = resolve(hasPendingChanges: true, clearFailureReason: false);
      final r2 = resolve(hasPendingChanges: true, clearFailureReason: true);
      expect(r1.state, r2.state);
      expect(r1.failureReason, r2.failureReason);
      expect(r1.configurationInvalid, r2.configurationInvalid);
    });

    test('未启用分支清除 configurationInvalid 但保留失败原因', () {
      final r = resolve(
        enabled: false,
        hasRequiredCredentials: false,
        failureReason: '旧错误',
        configurationInvalid: true,
      );
      expect(r.state, SyncTrustState.notEnabled);
      expect(r.configurationInvalid, isFalse);
      expect(r.failureReason, '旧错误');
    });

    test('凭据缺失分支失败原因为空时使用默认文案，配置标记恒为 true', () {
      final r = resolve(
        hasRequiredCredentials: false,
        hasPendingChanges: true,
        hasLastSyncTime: true,
        failureReason: null,
        configurationInvalid: false,
      );
      expect(r.state, SyncTrustState.needsAttention);
      expect(r.configurationInvalid, isTrue);
      expect(r.failureReason, configIssueMessage);
    });
  });
}
