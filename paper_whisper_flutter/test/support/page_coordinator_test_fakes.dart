import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_whisper_flutter/features/sync/application/auto_sync_scheduler.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_run_result.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_entry.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_config.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_provider.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_secret_store.dart';

import 'sync_test_fakes.dart';

/// 页面协调器测试（settings / moments）共用的平台 channel mock。
///
/// 背景：settings 的 initState 直接调用 `Permission.*.status`（无 try/catch），
/// moments 的输入/卡片组件在构造期即触发 audioplayers / record 的平台
/// 调用，聚合跳转的 DiaryListPage 会读取 package_info。widget 测试的
/// TestDefaultBinaryMessenger 对未注册 channel 返回 null，导致
/// MissingPluginException 成为未处理异步错误并使测试失败，因此这些
/// channel 必须显式 mock。
///
/// 每个测试的 setUp 调用 [installPageCoordinatorPlatformMocks]，
/// tearDown 调用 [uninstallPageCoordinatorPlatformMocks] 还原。
void installPageCoordinatorPlatformMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // audioplayers：AudioPlayer() 构造即 fire-and-forget 调用
  // global.ensureInitialized + platform.create，MissingPluginException 会
  // 经 creatingCompleter.completeError 成为未处理异步错误。
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async => null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (call) async => null,
  );

  // record：AudioRecorder() 构造即 fire-and-forget 调用 platform.create。
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.record/messages'),
    (call) async => null,
  );

  // permission_handler：settings 的 _checkAllPermissions 无 try/catch；
  // 一律返回 granted（PermissionStatusValue.granted == 1）。
  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return 1; // granted
        case 'requestPermissions':
          return <int, int>{1: 1};
        case 'openAppSettings':
          return true;
        case 'shouldShowRequestPermissionRationale':
          return false;
        default:
          return null;
      }
    },
  );

  // package_info_plus：moments 聚合跳转的 DiaryListPage 在 initState 读取
  // 当前版本（无 try/catch），settings 手动检查更新也读取版本。
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => <String, dynamic>{
      'appName': '纸语 PaperWhisper',
      'packageName': 'com.example.paper_whisper_flutter',
      'version': '1.0.0',
      'buildNumber': '1',
      'buildSignature': '',
      'installerStore': null,
    },
  );

  // 注意：不 mock path_provider 与 flutter/platform。
  // - flutter/platform 是 JSONMethodCodec 的 OptionalMethodChannel，未注册
  //   handler 时 invokeMethod 直接返回 null；若按 StandardMethodCodec 注册
  //   mock，解码 JSON 消息会失败并把异常抛进测试区。
  // - path_provider 一旦返回真实临时路径，会驱动 google_fonts 走 HTTP
  //   运行时取字（测试内 400 响应）并成为未处理异步错误；不 mock 时
  //   MissingPluginException 在 google_fonts 内部被捕获并静默回退。
  //   页面侧 StorageService.getCacheSize 自带 try/catch，getUserDataSize
  //   的真实 IO 在 fake async 下悬挂，均不会产生未处理异常。
}

void uninstallPageCoordinatorPlatformMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in const <String>[
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
    'com.llfbandit.record/messages',
    'flutter.baseflow.com/permissions/methods',
    'dev.fluttercommunity.plus/package_info',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), null);
  }
}

/// Moments 页面行为刻画测试用的内存版 MomentService。
///
/// 真实实现（含 debugDataDir 注入）的 init/getMoments 依赖 dart:io
/// 文件 IO，在 widget 测试的 fake async 区不会推进，会导致数据加载
/// 悬挂；这里覆写全部公开操作，用内存列表承载 moments 状态。
///
/// 预置数据通过 [seedMoments] 注入，保存/删除/导出调用分别记录计数，
/// 供断言发送管线、删除刷新与聚合入口的编排。
class PageCoordinatorFakeMomentService extends MomentService {
  PageCoordinatorFakeMomentService({Directory? dataDir, super.diaryService})
    : _fakeDataDir = dataDir,
      super(debugDataDir: dataDir);

  final Directory? _fakeDataDir;
  final List<Moment> _moments = <Moment>[];

  /// 非 null 时 [saveMoment] 抛出该错误（模拟磁盘失败）。
  Object? saveError;

  /// 非 null 时 [deleteMoment] 抛出该错误。
  Object? deleteError;

  int saveCallCount = 0;
  int deleteCallCount = 0;
  int saveImageCallCount = 0;
  int exportCallCount = 0;
  Moment? lastSavedMoment;
  String? lastDeletedUuid;

  void seedMoments(List<Moment> moments) {
    _moments
      ..clear()
      ..addAll(moments);
  }

  @override
  Directory? get dataDir => _fakeDataDir;

  @override
  Future<void> init() async {}

  @override
  Future<List<Moment>> getMoments() async =>
      List<Moment>.unmodifiable(_moments);

  @override
  Future<void> saveMoment(Moment moment) async {
    saveCallCount++;
    lastSavedMoment = moment;
    if (saveError != null) {
      throw saveError!;
    }
    _moments.removeWhere((m) => m.uuid == moment.uuid);
    _moments.add(moment);
  }

  @override
  Future<void> deleteMoment(String uuid) async {
    deleteCallCount++;
    lastDeletedUuid = uuid;
    if (deleteError != null) {
      throw deleteError!;
    }
    _moments.removeWhere((m) => m.uuid == uuid);
  }

  @override
  Future<String> saveImage(File sourceFile) async {
    saveImageCallCount++;
    return 'images/fake_${sourceFile.hashCode}.jpg';
  }

  @override
  Future<String> saveAudio(String sourcePath) async {
    return 'audio/fake_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  @override
  Future<String?> exportDailySummary(
    DateTime date, {
    String customTitle = '',
  }) async {
    exportCallCount++;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}_moments_summary.txt';
  }
}

/// DiaryListPage 行为刻画测试用的内存版 DiaryService。
///
/// 真实实现（含 FakeDiaryService 的 debugDataDir 注入）的 init/getEntries
/// 依赖 dart:io 文件 IO，在 widget 测试的 fake async 区不会推进，会导致
/// 数据加载悬挂；这里覆写为纯内存实现：
/// - [init] 空操作、[dataDir] 恒为 null（`DiaryProvider._loadBookMetadata`
///   会因 dataDir == null 提前返回，避免 book_metadata.json 文件 IO）；
/// - [getEntries] 返回 [seedEntries] 注入的条目并按日期降序（与真实
///   DiaryService 排序一致，供 provider 构建 MonthHeader 扁平列表）；
/// - 保存/删除记录调用计数，供「打开编辑器」等导航链测试断言入口。
class PageCoordinatorFakeDiaryService extends FakeDiaryService {
  PageCoordinatorFakeDiaryService(super.rootDir);

  final List<DiaryEntry> _entries = <DiaryEntry>[];

  int saveCallCount = 0;
  int deleteCallCount = 0;
  DiaryEntry? lastSavedEntry;
  String? lastDeletedFilename;

  void seedEntries(List<DiaryEntry> entries) {
    _entries
      ..clear()
      ..addAll(entries);
  }

  @override
  Directory? get dataDir => null;

  @override
  String get currentDataPath => 'test';

  @override
  Future<void> init() async {
    // 空实现：避免真实目录创建 / manifest 初始化 IO。
  }

  @override
  void reset() {
    // 空实现：不清理任何状态。
  }

  @override
  Future<List<DiaryEntry>> getEntries() async {
    final sorted = List<DiaryEntry>.of(_entries)
      ..sort((a, b) => b.dateString.compareTo(a.dateString));
    return sorted;
  }

  @override
  Future<String> saveEntry(DiaryEntry entry) async {
    saveCallCount++;
    lastSavedEntry = entry;
    return entry.filename;
  }

  @override
  Future<void> deleteEntry(String filename) async {
    deleteCallCount++;
    lastDeletedFilename = filename;
  }
}

/// Settings / Moments 保存后同步与信任快照展示用的 SyncProvider 替身。
///
/// 仅覆写页面链路用到的公开命令：全部立即完成，不触碰网络、通知与
/// 真实 manifest 计算。行为由 [config] / [snapshot] 参数驱动，对应
/// `SyncUiCoordinator.handleSaveAutoSync` 的三个反馈分支与
/// settings 的 `_getSyncStatusText` 各状态分支。
class PageCoordinatorSyncProvider extends SyncProvider {
  PageCoordinatorSyncProvider({
    SyncConfig? config,
    SyncTrustSnapshot? snapshot,
    required super.momentService,
  }) : _config = config ?? SyncConfig(),
       _snapshot =
           snapshot ??
           const SyncTrustSnapshot(state: SyncTrustState.notEnabled),
       super(
         secretStore: SyncSecretStore.fake(),
         initializeNotifications: false,
       );

  SyncConfig _config;
  final SyncTrustSnapshot _snapshot;

  int refreshTrustSnapshotCallCount = 0;
  int requestAutoSyncCallCount = 0;
  int syncCallCount = 0;
  int saveConfigCallCount = 0;

  @override
  SyncConfig get config => _config;

  @override
  bool get isConfigured => _config.enabled && _config.hasRequiredCredentials;

  @override
  SyncTrustSnapshot get trustSnapshot => _snapshot;

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
  Future<void> saveConfig(SyncConfig newConfig) async {
    _config = newConfig;
    saveConfigCallCount++;
    notifyListeners();
  }

  @override
  Future<bool> connect({
    bool test = true,
    bool awaitInitialization = true,
  }) async {
    return true;
  }

  @override
  Future<SyncRunResult> sync({bool isAuto = false}) async {
    syncCallCount++;
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
