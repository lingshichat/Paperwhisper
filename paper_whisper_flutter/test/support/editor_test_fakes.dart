import 'dart:io';

import 'package:paper_whisper_flutter/features/sync/application/auto_sync_scheduler.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_run_result.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_config.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_provider.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_secret_store.dart';

import 'sync_test_fakes.dart';

/// EditorPage 行为刻画测试专用 DiaryService 替身。
///
/// DiaryProvider 的加载/保存/删除路径会调用
/// `init / getEntries / saveCache / loadCache / saveEntry / deleteEntry`，
/// 这里全部覆写为可控记录调用，消除真实 IO：
/// - [init] 覆写为空操作，不创建数据目录、不初始化 manifest/回收站
///   （父类 `FakeDiaryService.init` 的真实文件 IO 在 widget 测试的
///   fake async 区不会推进 dart:io 事件，会导致悬挂）；
/// - dataDir 因此保持 null，`DiaryProvider._loadBookMetadata` 会提前返回；
/// - [saveError] / [deleteError] 注入失败路径。
class EditorFakeDiaryService extends FakeDiaryService {
  EditorFakeDiaryService(super.rootDir);

  /// 保存调用次数与最近一次保存的 entry（断言保存编排与字段透传）。
  int saveCallCount = 0;
  DiaryEntry? lastSavedEntry;

  /// 非 null 时 [saveEntry] 抛出该错误（模拟磁盘/权限失败）。
  Object? saveError;

  /// 删除调用次数与最近一次删除的文件名。
  int deleteCallCount = 0;
  String? lastDeletedFilename;

  /// 非 null 时 [deleteEntry] 抛出该错误。
  Object? deleteError;

  @override
  Future<void> init() async {
    // 空实现：避免真实目录创建 / manifest 初始化 IO。
  }

  @override
  Future<String> saveEntry(DiaryEntry entry) async {
    saveCallCount++;
    lastSavedEntry = entry;
    if (saveError != null) {
      throw saveError!;
    }
    return entry.filename;
  }

  @override
  Future<void> deleteEntry(String filename) async {
    deleteCallCount++;
    lastDeletedFilename = filename;
    if (deleteError != null) {
      throw deleteError!;
    }
  }
}

/// EditorPage 保存后同步反馈的 SyncProvider 替身。
///
/// 仅覆写 editor 保存路径用到的公开命令：全部立即完成，不触碰网络、
/// 通知与真实 manifest 计算。行为由 [config] / [snapshot] 参数驱动，
/// 对应 `SyncUiCoordinator.handleSaveAutoSync` 的三个反馈分支。
///
/// 注意：字段使用 `_testConfig` / `_testSnapshot` 命名，避免与父类
/// 私有字段（`_config` / `_trustSnapshot`）同名造成遮蔽混淆。
class EditorTestSyncProvider extends SyncProvider {
  EditorTestSyncProvider({
    SyncConfig? config,
    SyncTrustSnapshot snapshot = const SyncTrustSnapshot(
      state: SyncTrustState.notEnabled,
    ),
    required List<Directory> tempDirs,
  }) : _testConfig = config ?? SyncConfig(),
       _testSnapshot = snapshot,
       super(
         momentService: _createMomentService(tempDirs),
         secretStore: SyncSecretStore.fake(),
         initializeNotifications: false,
       );

  final SyncConfig _testConfig;
  final SyncTrustSnapshot _testSnapshot;

  /// 记录 `refreshTrustSnapshot` 与 `requestAutoSync` 调用（保存后同步
  /// 触发契约的断言对象）。
  int refreshTrustSnapshotCallCount = 0;
  int requestAutoSyncCallCount = 0;

  static MomentService _createMomentService(List<Directory> tempDirs) {
    final rootDir = Directory.systemTemp.createTempSync('editor_page_test');
    tempDirs.add(rootDir);
    // 真实 MomentService（debug 数据目录注入），复用 sync_settings_page_test
    // 已验证的构造模式，避免子类重声明私有字段遮蔽父类实现。
    return MomentService(debugDataDir: rootDir);
  }

  @override
  SyncConfig get config => _testConfig;

  /// 必须同步覆写：父类 [SyncProvider.isConfigured] 直接读取其私有
  /// `_config`（构造期从 store 加载的默认值），不会随上面的 [config]
  /// getter 变化，否则保存后同步反馈的 autoSync 分支永远不可达。
  @override
  bool get isConfigured =>
      _testConfig.enabled && _testConfig.hasRequiredCredentials;

  @override
  SyncTrustSnapshot get trustSnapshot => _testSnapshot;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> waitUntilReady() async {}

  @override
  Future<void> refreshTrustSnapshot({
    SyncTrustState? overrideState,
    String? failureReason,
    bool configurationInvalid = false,
    bool clearFailureReason = false,
    bool notify = true,
    bool awaitInitialization = true,
  }) async {
    refreshTrustSnapshotCallCount++;
  }

  @override
  Future<void> saveConfig(SyncConfig newConfig) async {}

  @override
  Future<bool> connect({
    bool test = true,
    bool awaitInitialization = true,
  }) async {
    return true;
  }

  @override
  Future<SyncRunResult> sync({bool isAuto = false}) async {
    return const SyncRunResult(status: SyncRunStatus.success);
  }

  @override
  Future<AutoSyncDecision?> requestAutoSync({
    bool fromLifecycle = false,
    bool force = false,
  }) async {
    requestAutoSyncCallCount++;
    return null;
  }
}
