import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_run_result.dart';

/// SyncRunResult 测试。
///
/// 覆盖全部 [SyncRunStatus] 分支的可构造性、默认计数、文案/待同步数
/// 携带与 [SyncRunResult.hasChanges] 语义（页面成功文案区分
/// 「已同步: ...」与「同步完成 (无变更)」的输入）。
void main() {
  group('SyncRunResult', () {
    test('全部状态分支均可构造', () {
      for (final status in SyncRunStatus.values) {
        expect(
          SyncRunResult(status: status).status,
          status,
          reason: 'status $status 应可无参（除 status 外）构造',
        );
      }
    });

    test('默认计数与文案为零/空', () {
      const result = SyncRunResult(status: SyncRunStatus.success);

      expect(result.processedDiaries, 0);
      expect(result.processedMoments, 0);
      expect(result.processedImages, 0);
      expect(result.processedAudio, 0);
      expect(result.pendingCount, 0);
      expect(result.failureMessage, isEmpty);
    });

    test('hasChanges 在全部计数为零时为 false', () {
      const result = SyncRunResult(status: SyncRunStatus.success);

      expect(result.hasChanges, isFalse);
    });

    test('hasChanges 在任一分类计数大于零时为 true', () {
      const diaries = SyncRunResult(
        status: SyncRunStatus.success,
        processedDiaries: 1,
      );
      const moments = SyncRunResult(
        status: SyncRunStatus.success,
        processedMoments: 2,
      );
      const images = SyncRunResult(
        status: SyncRunStatus.success,
        processedImages: 3,
      );
      const audio = SyncRunResult(
        status: SyncRunStatus.success,
        processedAudio: 4,
      );

      expect(diaries.hasChanges, isTrue);
      expect(moments.hasChanges, isTrue);
      expect(images.hasChanges, isTrue);
      expect(audio.hasChanges, isTrue);
    });

    test('pendingCount 与 failureMessage 原样携带', () {
      const result = SyncRunResult(
        status: SyncRunStatus.pending,
        pendingCount: 7,
        failureMessage: '尚有 7 项待同步',
      );

      expect(result.pendingCount, 7);
      expect(result.failureMessage, '尚有 7 项待同步');
    });

    test('失败分支携带面向用户文案', () {
      const result = SyncRunResult(
        status: SyncRunStatus.failed,
        failureMessage: '网络异常，请稍后重试',
      );

      expect(result.failureMessage, '网络异常，请稍后重试');
      expect(result.hasChanges, isFalse);
    });

    test('connectionFailed / alreadySyncing / permissionDenied 分支可区分', () {
      const connection = SyncRunResult(status: SyncRunStatus.connectionFailed);
      const already = SyncRunResult(status: SyncRunStatus.alreadySyncing);
      const denied = SyncRunResult(status: SyncRunStatus.permissionDenied);

      expect(connection.status, SyncRunStatus.connectionFailed);
      expect(already.status, SyncRunStatus.alreadySyncing);
      expect(denied.status, SyncRunStatus.permissionDenied);
    });
  });
}
