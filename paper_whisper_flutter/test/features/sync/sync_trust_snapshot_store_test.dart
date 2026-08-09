import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot_store.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SyncTrustSnapshotStore 测试。
///
/// 覆盖键名契约（`sync_trust_snapshot`）、JSON 回环、损坏 JSON 返回 null、
/// 无记录返回 null 与 prefs 注入（prefsFactory）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SyncTrustSnapshotStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    store = SyncTrustSnapshotStore(prefsFactory: () async => prefs);
  });

  group('SyncTrustSnapshotStore', () {
    test('键名保持 sync_trust_snapshot（兼容红线）', () {
      expect(SyncTrustSnapshotStore.syncTrustSnapshotKey, 'sync_trust_snapshot');
    });

    test('load 在无记录时返回 null', () async {
      expect(await store.load(), isNull);
    });

    test('load 在损坏 JSON 时返回 null 且不抛异常', () async {
      await prefs.setString(
        SyncTrustSnapshotStore.syncTrustSnapshotKey,
        '{not valid json',
      );

      final loaded = await store.load();

      expect(loaded, isNull);
    });

    test('save/load 全字段 JSON 回环', () async {
      final snapshot = SyncTrustSnapshot(
        state: SyncTrustState.localChangesPending,
        pendingDiaryCount: 3,
        pendingMomentCount: 2,
        pendingImageCount: 1,
        pendingAudioCount: 4,
        lastSuccessfulSyncAt: DateTime(2026, 3, 12, 9, 30, 15),
        lastSuccessfulSyncPlatform: 's3',
        failureReason: '同步失败，内容仍保留在本地',
        configurationInvalid: true,
      );

      await store.save(snapshot);
      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.state, SyncTrustState.localChangesPending);
      expect(loaded.pendingDiaryCount, 3);
      expect(loaded.pendingMomentCount, 2);
      expect(loaded.pendingImageCount, 1);
      expect(loaded.pendingAudioCount, 4);
      expect(loaded.lastSuccessfulSyncAt, DateTime(2026, 3, 12, 9, 30, 15));
      expect(loaded.lastSuccessfulSyncPlatform, 's3');
      expect(loaded.failureReason, '同步失败，内容仍保留在本地');
      expect(loaded.configurationInvalid, isTrue);
      expect(loaded.totalPendingCount, 10);
    });

    test('保存的原始 JSON 结构逐字保留（键名契约）', () async {
      final snapshot = SyncTrustSnapshot(
        state: SyncTrustState.syncedSuccessfully,
        pendingDiaryCount: 0,
        lastSuccessfulSyncAt: DateTime(2026, 3, 12, 9, 30),
        lastSuccessfulSyncPlatform: 'webdav',
        failureReason: null,
        configurationInvalid: false,
      );

      await store.save(snapshot);

      final raw = jsonDecode(
        prefs.getString(SyncTrustSnapshotStore.syncTrustSnapshotKey)!,
      ) as Map<String, dynamic>;
      expect(raw.keys, containsAll(<String>[
        'state',
        'pendingDiaryCount',
        'pendingMomentCount',
        'pendingImageCount',
        'pendingAudioCount',
        'lastSuccessfulSyncAt',
        'lastSuccessfulSyncPlatform',
        'failureReason',
        'configurationInvalid',
      ]));
      expect(raw['state'], 'syncedSuccessfully');
      expect(raw['lastSuccessfulSyncPlatform'], 'webdav');
    });

    test('空字符串记录按损坏处理返回 null', () async {
      await prefs.setString(SyncTrustSnapshotStore.syncTrustSnapshotKey, '');

      expect(await store.load(), isNull);
    });

    test('notEnabled 常量快照可保存并读回', () async {
      await store.save(SyncTrustSnapshot.notEnabled);

      final loaded = await store.load();

      expect(loaded!.state, SyncTrustState.notEnabled);
      expect(loaded.totalPendingCount, 0);
    });
  });
}
