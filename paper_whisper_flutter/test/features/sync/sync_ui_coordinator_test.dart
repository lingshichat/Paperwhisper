import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/core/theme/app_theme.dart';
import 'package:paper_whisper_flutter/core/theme/theme_registry.dart';
import 'package:paper_whisper_flutter/features/sync/application/auto_sync_scheduler.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_run_result.dart';
import 'package:paper_whisper_flutter/features/sync/presentation/sync_ui_coordinator.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_config.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/features/settings/application/settings_provider.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_provider.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_secret_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/sync_test_fakes.dart';

/// SyncUiCoordinator widget 测试。
///
/// 覆盖：
/// - 通知权限拒绝/允许对 `runManualSync` 与保存后自动同步的分支影响；
/// - 手动同步 typed result 各分支的 Toast 文案与级别（icon 可观测）；
/// - context 卸载后的安全早退（不调用 sync / 不弹 Toast）；
/// - `handleSaveAutoSync` 各文案/级别（准备中 / 待同步 / 保存成功）；
/// - `requestAutoSyncIfConfigured` 的配置与权限门禁。
///
/// 测试策略：使用公开 fake（覆写公开方法），不锁定私有调用顺序。
/// - [TestableSyncUiCoordinator] 覆写公开的 `checkNotificationPermission`
///   （本机 Windows 平台守卫恒返回 true，权限分支需注入可控结果）；
/// - [ScriptedSyncProvider] 覆写 `sync/requestAutoSync/refreshTrustSnapshot/
///   config/trustSnapshot/isConfigured`，脚本化返回 typed result。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ThemeRegistry.init();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  late List<Directory> tempDirs;

  setUp(() {
    tempDirs = <Directory>[];
  });

  tearDown(() async {
    for (final dir in tempDirs) {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  });

  /// 构建带 SettingsProvider 的 MaterialApp 并暴露一个 mounted context。
  Future<BuildContext> pumpHarness(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.getThemeData(AppTheme.themeDefault),
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  ScriptedSyncProvider buildProvider({
    SyncRunResult result = const SyncRunResult(status: SyncRunStatus.success),
    SyncConfig? config,
    SyncTrustSnapshot? snapshot,
  }) {
    final rootDir = Directory.systemTemp.createTempSync(
      'sync_ui_coordinator_test',
    );
    tempDirs.add(rootDir);
    return ScriptedSyncProvider(
      result: result,
      config: config,
      snapshot: snapshot,
      tempDir: rootDir,
    );
  }

  SyncConfig configuredConfig({bool autoSync = true}) {
    return SyncConfig(
      enabled: true,
      autoSync: autoSync,
      serverUrl: 'https://dav.example.com/',
      username: 'demo',
      password: 'secret',
    );
  }

  group('runManualSync 权限分支', () {
    testWidgets('权限拒绝时返回 permissionDenied 且不调用 sync', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider();
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: false,
      );

      final result = await coordinator.runManualSync(provider);

      expect(result.status, SyncRunStatus.permissionDenied);
      expect(provider.syncCalls, 0);
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing, reason: '拒绝权限不弹 Toast');
    });

    testWidgets('权限允许时执行 sync 并返回其 typed result', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(
        result: const SyncRunResult(status: SyncRunStatus.success),
      );
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      final result = await coordinator.runManualSync(provider);

      expect(result.status, SyncRunStatus.success);
      expect(provider.syncCalls, 1);
    });
  });

  group('runManualSync typed result Toast', () {
    testWidgets('success 显示分类计数文案（success 级别）', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(
        result: const SyncRunResult(
          status: SyncRunStatus.success,
          processedDiaries: 1,
          processedMoments: 2,
          processedImages: 3,
          processedAudio: 4,
        ),
      );
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.runManualSync(provider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('已同步: 1篇日记, 2篇随心记\n3张图片, 4条语音'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('success 无变更显示「同步完成 (无变更)」', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(
        result: const SyncRunResult(status: SyncRunStatus.success),
      );
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.runManualSync(provider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('同步完成 (无变更)'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('failed 显示用户安全文案（error 级别）', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(
        result: const SyncRunResult(
          status: SyncRunStatus.failed,
          failureMessage: '网络异常，请稍后重试',
        ),
      );
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.runManualSync(provider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('网络异常，请稍后重试'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('pending 显示待同步计数（info 级别）', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(
        result: const SyncRunResult(
          status: SyncRunStatus.pending,
          pendingCount: 7,
        ),
      );
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.runManualSync(provider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('尚有 7 项待同步'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('alreadySyncing 显示进行中文案（info 级别）', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(
        result: const SyncRunResult(status: SyncRunStatus.alreadySyncing),
      );
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.runManualSync(provider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('正在同步中，请稍候...'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('connectionFailed 显示失败文案（error 级别）', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(
        result: const SyncRunResult(
          status: SyncRunStatus.connectionFailed,
          failureMessage: '网络异常，请稍后重试',
        ),
      );
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.runManualSync(provider);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('网络异常，请稍后重试'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('notEnabled / proRequired 静默不弹 Toast', (tester) async {
      final ctx = await pumpHarness(tester);
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      final notEnabled = buildProvider(
        result: const SyncRunResult(status: SyncRunStatus.notEnabled),
      );
      await coordinator.runManualSync(notEnabled);
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);

      final proRequired = buildProvider(
        result: const SyncRunResult(status: SyncRunStatus.proRequired),
      );
      await coordinator.runManualSync(proRequired);
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('runManualSync unmounted 安全', () {
    testWidgets('context 卸载后返回 permissionDenied 且不调用 sync', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider();

      // 卸载整个树，使捕获的 context 失效
      await tester.pumpWidget(const SizedBox());

      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );
      final result = await coordinator.runManualSync(provider);

      expect(result.status, SyncRunStatus.permissionDenied);
      expect(provider.syncCalls, 0);
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('handleSaveAutoSync 文案/级别', () {
    testWidgets('启用自动同步：显示准备文案并触发 requestAutoSync', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(config: configuredConfig());
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.handleSaveAutoSync(
        provider: provider,
        savedToast: '日记已保存',
        preparingToast: '正在准备同步...',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('正在准备同步...'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      // 刷新调用至少一次（基类后台 _loadConfig 也会触发一次刷新，精确次数
      // 依赖异步时序，只断言协调器路径必然触发）
      expect(provider.refreshCalls, greaterThanOrEqualTo(1));
      expect(provider.autoSyncRequests, 1);
    });

    testWidgets('启用自动同步且 preparingToastAsInfo：准备文案为 info 级别', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(config: configuredConfig());
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.handleSaveAutoSync(
        provider: provider,
        savedToast: '日记已保存',
        preparingToast: '正在准备同步...',
        preparingToastAsInfo: true,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('正在准备同步...'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('启用自动同步但权限拒绝：显示准备文案但不触发自动同步', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(config: configuredConfig());
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: false,
      );

      await coordinator.handleSaveAutoSync(
        provider: provider,
        savedToast: '日记已保存',
        preparingToast: '正在准备同步...',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('正在准备同步...'), findsOneWidget);
      expect(provider.autoSyncRequests, 0);
    });

    testWidgets('未启用自动同步但有 pending：显示待同步提示（info 级别）', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(
        config: configuredConfig(autoSync: false),
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.localChangesPending,
          pendingDiaryCount: 3,
        ),
      );
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.handleSaveAutoSync(
        provider: provider,
        savedToast: '日记已保存',
        preparingToast: '正在准备同步...',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('已保存，尚有 3 项待同步'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(provider.autoSyncRequests, 0);
    });

    testWidgets('无 pending 且未启用自动同步：显示保存成功文案（success 级别）', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(
        config: configuredConfig(autoSync: false),
        snapshot: const SyncTrustSnapshot(
          state: SyncTrustState.syncedSuccessfully,
        ),
      );
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.handleSaveAutoSync(
        provider: provider,
        savedToast: '记录已保存',
        preparingToast: '正在准备同步...',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('记录已保存'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(provider.autoSyncRequests, 0);
    });

    testWidgets('context 卸载后安全早退：无 Toast 无自动同步', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(config: configuredConfig());

      await tester.pumpWidget(const SizedBox());

      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );
      await coordinator.handleSaveAutoSync(
        provider: provider,
        savedToast: '日记已保存',
        preparingToast: '正在准备同步...',
      );
      await tester.pump();

      expect(provider.autoSyncRequests, 0);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('requestAutoSyncIfConfigured 门禁', () {
    testWidgets('自动同步已配置且权限允许：触发 requestAutoSync', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(config: configuredConfig());
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.requestAutoSyncIfConfigured(provider);

      expect(provider.autoSyncRequests, 1);
    });

    testWidgets('未开启自动同步：不触发', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(config: configuredConfig(autoSync: false));
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: true,
      );

      await coordinator.requestAutoSyncIfConfigured(provider);

      expect(provider.autoSyncRequests, 0);
    });

    testWidgets('权限拒绝：不触发', (tester) async {
      final ctx = await pumpHarness(tester);
      final provider = buildProvider(config: configuredConfig());
      final coordinator = TestableSyncUiCoordinator(
        ctx,
        permissionResult: false,
      );

      await coordinator.requestAutoSyncIfConfigured(provider);

      expect(provider.autoSyncRequests, 0);
    });
  });
}

/// 覆写公开的 `checkNotificationPermission` 注入可控权限结果
/// （本机 Windows 的基类平台守卫恒返回 true，无法驱动拒绝分支）。
class TestableSyncUiCoordinator extends SyncUiCoordinator {
  TestableSyncUiCoordinator(super.context, {required this.permissionResult});

  final bool permissionResult;
  int permissionChecks = 0;

  @override
  Future<bool> checkNotificationPermission() async {
    permissionChecks++;
    return permissionResult;
  }
}

/// 脚本化 SyncProvider 替身：覆写公开成员，返回脚本化 typed result，
/// 记录 sync / requestAutoSync / refreshTrustSnapshot 调用次数。
class ScriptedSyncProvider extends SyncProvider {
  ScriptedSyncProvider({
    required this.result,
    SyncConfig? config,
    SyncTrustSnapshot? snapshot,
    required Directory tempDir,
  }) : _config = config ?? SyncConfig(),
       _snapshot = snapshot ?? SyncTrustSnapshot.notEnabled,
       super(
         momentService: FakeMomentService(tempDir),
         secretStore: SyncSecretStore.fake(),
         initializeNotifications: false,
       );

  final SyncRunResult result;
  final SyncConfig _config;
  final SyncTrustSnapshot _snapshot;
  int syncCalls = 0;
  int autoSyncRequests = 0;
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

  @override
  Future<SyncRunResult> sync({bool isAuto = false}) async {
    syncCalls++;
    return result;
  }

  @override
  Future<AutoSyncDecision?> requestAutoSync({
    bool fromLifecycle = false,
    bool force = false,
  }) async {
    autoSyncRequests++;
    return AutoSyncDecision.scheduled;
  }
}
