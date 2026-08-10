import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/application/save_sync_coordinator.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_config.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_provider.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_test_fakes.dart';

/// SaveSyncCoordinator 行为刻画测试。
///
/// 覆盖 `decideAfterSave` 三分支（自动同步 / 待同步 / 仅保存成功）、
/// enabled=false 时 pending 分支的收敛语义，以及 `shouldAutoSync`
/// 门禁。全部断言不依赖 UI，直接验证 typed decision。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('save_sync_coordinator_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  SyncConfig configuredConfig({bool autoSync = true}) {
    return SyncConfig(
      enabled: true,
      autoSync: autoSync,
      serverUrl: 'https://dav.example.com/',
      username: 'demo',
      password: 'secret',
    );
  }

  group('decideAfterSave', () {
    test('启用自动同步且已配置：返回 SaveSyncAutoSync 并刷新信任快照', () async {
      final provider = _ScriptedSyncProvider(
        tempDir: tempDir,
        config: configuredConfig(),
      );
      final coordinator = const SaveSyncCoordinator();

      final decision = await coordinator.decideAfterSave(provider);

      expect(decision, isA<SaveSyncAutoSync>());
      expect(provider.refreshCalls, 1, reason: '决策前必须刷新信任快照');
    });

    test('未启用自动同步但有 pending：返回 SaveSyncPending 含 pendingCount', () async {
      final provider = _ScriptedSyncProvider(
        tempDir: tempDir,
        config: configuredConfig(autoSync: false),
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.localChangesPending,
          pendingDiaryCount: 3,
        ),
      );
      final coordinator = const SaveSyncCoordinator();

      final decision = await coordinator.decideAfterSave(provider);

      expect(decision, isA<SaveSyncPending>());
      expect((decision as SaveSyncPending).pendingCount, 3);
    });

    test(
      'autoSync=true 但未配置凭据且有 pending：返回 SaveSyncPending（不触发自动同步）',
      () async {
        final provider = _ScriptedSyncProvider(
          tempDir: tempDir,
          config: SyncConfig(enabled: true, autoSync: true),
          snapshot: const SyncTrustSnapshot(
            state: SyncTrustState.localChangesPending,
            pendingDiaryCount: 2,
          ),
        );
        final coordinator = const SaveSyncCoordinator();

        final decision = await coordinator.decideAfterSave(provider);

        expect(decision, isA<SaveSyncPending>());
        expect((decision as SaveSyncPending).pendingCount, 2);
      },
    );

    test('无 pending 且未启用自动同步：返回 SaveSyncSaved', () async {
      final provider = _ScriptedSyncProvider(
        tempDir: tempDir,
        config: configuredConfig(autoSync: false),
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.syncedSuccessfully,
        ),
      );
      final coordinator = const SaveSyncCoordinator();

      final decision = await coordinator.decideAfterSave(provider);

      expect(decision, isA<SaveSyncSaved>());
    });

    test('enabled=false 时即使有 pending 也返回 SaveSyncSaved（原语义收敛）', () async {
      final provider = _ScriptedSyncProvider(
        tempDir: tempDir,
        config: SyncConfig(enabled: false, autoSync: false),
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.localChangesPending,
          pendingDiaryCount: 5,
        ),
      );
      final coordinator = const SaveSyncCoordinator();

      final decision = await coordinator.decideAfterSave(provider);

      expect(decision, isA<SaveSyncSaved>());
    });
  });

  group('shouldAutoSync', () {
    test('autoSync 开启且已配置：返回 true', () {
      final provider = _ScriptedSyncProvider(
        tempDir: tempDir,
        config: configuredConfig(),
      );

      expect(const SaveSyncCoordinator().shouldAutoSync(provider), isTrue);
    });

    test('autoSync 关闭：返回 false', () {
      final provider = _ScriptedSyncProvider(
        tempDir: tempDir,
        config: configuredConfig(autoSync: false),
      );

      expect(const SaveSyncCoordinator().shouldAutoSync(provider), isFalse);
    });

    test('未配置凭据：返回 false', () {
      final provider = _ScriptedSyncProvider(
        tempDir: tempDir,
        config: SyncConfig(enabled: true, autoSync: true),
      );

      expect(const SaveSyncCoordinator().shouldAutoSync(provider), isFalse);
    });
  });
}

/// 覆写公开成员的 SyncProvider 替身：脚本化 config / snapshot，
/// 记录 refreshTrustSnapshot 调用次数。
class _ScriptedSyncProvider extends SyncProvider {
  _ScriptedSyncProvider({
    SyncConfig? config,
    SyncTrustSnapshot? snapshot,
    required Directory tempDir,
  }) : _config = config ?? SyncConfig(),
       _snapshot =
           snapshot ??
           const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
       super(
         momentService: FakeMomentService(tempDir),
         secretStore: SyncSecretStore.fake(),
         initializeNotifications: false,
       );

  final SyncConfig _config;
  final SyncTrustSnapshot _snapshot;
  int refreshCalls = 0;

  @override
  SyncConfig get config => _config;

  @override
  SyncTrustSnapshot get trustSnapshot => _snapshot;

  @override
  bool get isConfigured => _config.enabled && _config.hasRequiredCredentials;

  @override
  Future<void> refreshTrustSnapshot({
    SyncTrustState? overrideState,
    String? failureReason,
    bool configurationInvalid = false,
    bool clearFailureReason = false,
    bool notify = true,
    bool awaitInitialization = true,
  }) async {
    refreshCalls++;
  }
}
