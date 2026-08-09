import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/sync/application/auto_sync_scheduler.dart';
import '../features/sync/application/sync_error_classifier.dart';
import '../features/sync/application/sync_pending_calculator.dart';
import '../features/sync/application/sync_progress_tracker.dart';
import '../features/sync/application/sync_run_result.dart';
import '../features/sync/application/sync_runner.dart';
import '../features/sync/application/sync_trust_engine.dart';
import '../features/sync/data/sync_config_store.dart';
import '../features/sync/data/sync_scope_cache_store.dart';
import '../features/sync/data/sync_trust_snapshot_store.dart';
import '../features/sync/presentation/sync_notification_service.dart';
import '../models/sync_config.dart';
import '../models/sync_trust_snapshot.dart';
import '../services/cloud_storage_service.dart';
import '../services/moment_service.dart';
import '../services/payment_service.dart';
import '../services/s3_sync_service.dart';
import '../services/sync_secret_store.dart';
import '../services/webdav_sync_service.dart';
import 'diary_provider.dart';

enum SyncStatus { none, syncing, success, failed }

/// 同步状态门面（ChangeNotifier）。
///
/// 职责收敛为：状态持有与公开 getter、配置/缓存/信任快照的持久化编排、
/// 连接与入口门禁、应用命令编排（同步/自动同步）。
/// 同步算法委托 [SyncRunner]，pending 差值计算委托 [SyncPendingCalculator]，
/// 信任快照持久化委托 [SyncTrustSnapshotStore]。
///
/// 本类为 context-free 状态门面：
/// - 不导入/使用 `dart:io`、SharedPreferences、permission_handler、
///   flutter_local_notifications、任何 Widget/Dialog/Toast；
/// - 不接受/持有 BuildContext；
/// - 通知权限说明、Dialog/Toast 与页面可见反馈由 [SyncUiCoordinator]
///   （features/sync/presentation/sync_ui_coordinator.dart）承担；
/// - `sync` 返回 typed [SyncRunResult]，`requestAutoSync` 返回
///   [AutoSyncDecision]?，由页面/协调器翻译为用户反馈。
///
/// 本批次保留的对外契约（页面/测试访问点不变）：
/// - getter：`config/trustSnapshot/status/lastError/progressMessage/lastSyncTime/
///   isConfigured/currentFileProgress/currentFileSpeed/totalProgress/etaMessage`
/// - 方法：`updateDiaryProvider/ensureInitialized/waitUntilReady/
///   refreshTrustSnapshot/saveConfig/connect/requestAutoSync/sync`
/// - 顶层枚举：`SyncStatus`
class SyncProvider with ChangeNotifier {
  final WebDavSyncService _webDavService;
  final S3SyncService _s3Service;
  final MomentService _momentService;
  final SyncSecretStore _secretStore;

  late final SyncConfigStore _configStore;
  late final SyncScopeCacheStore _scopeCacheStore;
  late final SyncTrustSnapshotStore _trustSnapshotStore;
  late final SyncPendingCalculator _pendingCalculator;
  late final SyncNotificationService _notificationService;
  late final SyncProgressTracker _progressTracker;
  late final AutoSyncScheduler _autoSyncScheduler;
  final SyncErrorClassifier _errorClassifier = const SyncErrorClassifier();
  final SyncTrustEngine _trustEngine = const SyncTrustEngine();

  DiaryProvider? _diaryProvider;

  SyncConfig _config = SyncConfig();
  SyncStatus _status = SyncStatus.none;
  String _lastError = '';
  String _progressMessage = '';
  DateTime? _lastSyncTime;
  DateTime? _currentScopeLastSyncTime;
  String? _lastSuccessfulSyncPlatform;
  SyncTrustSnapshot _trustSnapshot = SyncTrustSnapshot.notEnabled;

  @override
  void dispose() {
    // 释放自动同步调度器（取消防抖定时器），避免全局单例销毁后回调残留
    _autoSyncScheduler.dispose();
    super.dispose();
  }

  // Statistics
  int _statDiaries = 0;
  int _statMoments = 0;
  int _statImages = 0;
  int _statAudio = 0;

  SyncConfig get config => _config;
  SyncTrustSnapshot get trustSnapshot => _trustSnapshot;
  SyncStatus get status => _status;
  String get lastError => _lastError;
  String get progressMessage => _progressMessage;
  DateTime? get lastSyncTime => _currentScopeLastSyncTime;

  // Is Configured Logic
  bool get isConfigured {
    return _config.enabled && _config.hasRequiredCredentials;
  }

  double get currentFileProgress => _progressTracker.currentFileProgress;
  String get currentFileSpeed => _progressTracker.currentFileSpeed;

  /// Total Progress (0.0 - 1.0)
  /// Formula: (processed + currentFilePart) / total
  double get totalProgress => _progressTracker.totalProgress;

  String get etaMessage => _progressTracker.etaMessage;

  late Future<void> _initFuture;

  // Service Switcher
  CloudStorageService get _storageService {
    return _config.syncType == SyncType.s3 ? _s3Service : _webDavService;
  }

  SyncProvider({
    WebDavSyncService? webDavService,
    S3SyncService? s3Service,
    MomentService? momentService,
    SyncSecretStore? secretStore,
    SyncNotificationService? notificationService,
    bool initializeNotifications = true,
  }) : _webDavService = webDavService ?? WebDavSyncService(),
       _s3Service = s3Service ?? S3SyncService(),
       _momentService = momentService ?? MomentService(),
       _secretStore = secretStore ?? SyncSecretStore.secure(),
       _notificationService = notificationService ?? SyncNotificationService() {
    _configStore = SyncConfigStore(secretStore: _secretStore);
    _scopeCacheStore = SyncScopeCacheStore();
    _trustSnapshotStore = SyncTrustSnapshotStore();
    _pendingCalculator = SyncPendingCalculator(
      scopeCacheStore: _scopeCacheStore,
      momentService: _momentService,
    );
    _progressTracker = SyncProgressTracker(onChanged: notifyListeners);
    _autoSyncScheduler = AutoSyncScheduler(
      onTrigger: () async {
        try {
          await sync(isAuto: true);
        } catch (e) {
          debugPrint('AutoSync caught error: $e');
        }
      },
    );
    _initFuture = _loadConfig();
    if (initializeNotifications) {
      unawaited(_notificationService.init());
    }
  }

  void updateDiaryProvider(DiaryProvider dp) {
    _diaryProvider = dp;
  }

  @visibleForTesting
  Future<void> ensureInitialized() => _initFuture;

  Future<void> waitUntilReady() => _initFuture;

  // Helper to update progress message and notify UI
  void _updateProgress(String message) {
    _progressMessage = message;
    notifyListeners();
  }

  SyncStatus _syncStatusFromTrustState(SyncTrustState state) {
    switch (state) {
      case SyncTrustState.syncing:
        return SyncStatus.syncing;
      case SyncTrustState.syncedSuccessfully:
        return SyncStatus.success;
      case SyncTrustState.syncFailed:
      case SyncTrustState.needsAttention:
        return SyncStatus.failed;
      case SyncTrustState.notEnabled:
      case SyncTrustState.localChangesPending:
        return SyncStatus.none;
    }
  }

  Future<void> _persistTrustSnapshot() async {
    await _trustSnapshotStore.save(_trustSnapshot);
  }

  Future<void> _updateTrustSnapshot(
    SyncTrustSnapshot snapshot, {
    bool notify = true,
  }) async {
    _trustSnapshot = snapshot;
    _status = _syncStatusFromTrustState(snapshot.state);
    _lastSyncTime = snapshot.lastSuccessfulSyncAt;
    _lastSuccessfulSyncPlatform = snapshot.lastSuccessfulSyncPlatform;
    if (snapshot.failureReason != null) {
      _lastError = snapshot.failureReason!;
    } else if (snapshot.state != SyncTrustState.syncFailed &&
        snapshot.state != SyncTrustState.needsAttention) {
      _lastError = '';
    }
    await _persistTrustSnapshot();
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> refreshTrustSnapshot({
    SyncTrustState? overrideState,
    String? failureReason,
    bool configurationInvalid = false,
    bool clearFailureReason = false,
    bool notify = true,
    bool awaitInitialization = true,
  }) async {
    if (awaitInitialization) {
      await _initFuture;
    }

    // pending 差值计算委托 SyncPendingCalculator（含本地/远端 manifest
    // 与名称集合的差集，按当前作用域缓存基线计算）
    final pendingCounts = await _pendingCalculator.calculate(
      _config,
      diaryService: _diaryProvider?.service,
    );
    final hasPendingChanges = pendingCounts.total > 0;

    final resolution = _trustEngine.resolve(
      enabled: _config.enabled,
      hasRequiredCredentials: _config.hasRequiredCredentials,
      hasPendingChanges: hasPendingChanges,
      hasLastSyncTime: _currentScopeLastSyncTime != null,
      currentState: _trustSnapshot.state,
      configIssueMessage: _errorClassifier.configurationIssueMessage(
        enabled: _config.enabled,
      ),
      overrideState: overrideState,
      failureReason: failureReason,
      configurationInvalid: configurationInvalid,
      clearFailureReason: clearFailureReason,
    );

    await _updateTrustSnapshot(
      _trustSnapshot.copyWith(
        state: resolution.state,
        pendingDiaryCount: pendingCounts.diaries,
        pendingMomentCount: pendingCounts.moments,
        pendingImageCount: pendingCounts.images,
        pendingAudioCount: pendingCounts.audio,
        lastSuccessfulSyncAt: _lastSyncTime,
        lastSuccessfulSyncPlatform: _lastSuccessfulSyncPlatform,
        failureReason: resolution.failureReason,
        configurationInvalid: resolution.configurationInvalid,
        clearFailureReason:
            clearFailureReason && resolution.failureReason == null,
      ),
      notify: notify,
    );
  }

  Future<void> _persistSuccessfulSyncCaches() async {
    if (_diaryProvider != null) {
      final diaryManifest = _diaryProvider!.service.manifestService.manifest
          .clone();
      await _scopeCacheStore.saveCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        _config,
        diaryManifest,
      );
    }

    await _scopeCacheStore.saveCachedManifest(
      SyncScopeCacheStore.lastKnownMomentsManifestKey,
      _config,
      _momentService.manifestService.manifest.clone(),
    );
    await _scopeCacheStore.saveCachedNameSet(
      SyncScopeCacheStore.lastKnownMomentImagesKey,
      _config,
      await _momentService.getAllReferencedImages(),
    );
    await _scopeCacheStore.saveCachedNameSet(
      SyncScopeCacheStore.lastKnownMomentAudioKey,
      _config,
      await _pendingCalculator.getLocalAudioNames(),
    );
  }

  Future<void> _loadConfig() async {
    _config = await _configStore.load();

    final loadedSnapshot = await _trustSnapshotStore.load();
    if (loadedSnapshot != null) {
      _trustSnapshot = loadedSnapshot;
    }

    _lastSuccessfulSyncPlatform = _trustSnapshot.lastSuccessfulSyncPlatform;
    _lastSyncTime = await _scopeCacheStore.readGlobalLastSyncTime();

    await _scopeCacheStore.migrateLegacyScopeCacheIfNeeded(_config);
    _currentScopeLastSyncTime = await _scopeCacheStore
        .loadCurrentScopeLastSyncTime(_config);

    if (_lastSyncTime != null && _trustSnapshot.lastSuccessfulSyncAt == null) {
      _trustSnapshot = _trustSnapshot.copyWith(
        lastSuccessfulSyncAt: _lastSyncTime,
        lastSuccessfulSyncPlatform:
            _lastSuccessfulSyncPlatform ?? _config.syncType.name,
      );
    }

    await refreshTrustSnapshot(
      clearFailureReason: _trustSnapshot.state != SyncTrustState.syncFailed,
      notify: false,
      awaitInitialization: false,
    );

    if (_config.enabled) {
      // 尝试自动连接
      unawaited(connect(test: false, awaitInitialization: false));
    }
    notifyListeners();
  }

  Future<void> saveConfig(SyncConfig newConfig) async {
    await _initFuture;

    await _configStore.save(newConfig);
    _config = newConfig;
    _currentScopeLastSyncTime = await _scopeCacheStore
        .loadCurrentScopeLastSyncTime(_config);
    await refreshTrustSnapshot(
      clearFailureReason: true,
      configurationInvalid: !_config.hasRequiredCredentials && _config.enabled,
    );

    // 如果启用，尝试连接
    if (_config.enabled && _config.hasRequiredCredentials) {
      unawaited(connect());
    }
  }

  Future<bool> connect({
    bool test = true,
    bool awaitInitialization = true,
  }) async {
    if (awaitInitialization) {
      await _initFuture;
    }
    if (!PaymentService().canUseProFeatures) {
      _lastError = '需要赞助才能使用云同步'; // Changed from "WebDAV" to generic
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.needsAttention,
        failureReason: _lastError,
        configurationInvalid: true,
      );
      return false;
    }

    if (!_config.enabled) {
      return false;
    }

    if (!_config.hasRequiredCredentials) {
      final message = _errorClassifier.configurationIssueMessage(
        enabled: _config.enabled,
      );
      _lastError = message;
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.needsAttention,
        failureReason: message,
        configurationInvalid: true,
      );
      return false;
    }

    _updateProgress('正在连接服务器...');

    // Init Config based on type
    if (_config.syncType == SyncType.webdav) {
      _webDavService.initConfig(
        _config.serverUrl,
        _config.username,
        _config.password,
      );
    } else {
      _s3Service.initConfig(
        endPoint: _config.s3EndPoint,
        accessKey: _config.s3AccessKey,
        secretKey: _config.s3SecretKey,
        bucketName: _config.s3BucketName,
        region: _config.s3Region,
      );
    }

    final success = await _storageService.connect();

    if (!success) {
      final errorText = _storageService.lastConnectionError;
      final message = _errorClassifier.buildConnectionFailureMessage(
        errorText,
        enabled: _config.enabled,
      );
      _lastError = message;
      await refreshTrustSnapshot(
        overrideState: _errorClassifier.isLikelyConfigurationFailure(errorText)
            ? SyncTrustState.needsAttention
            : SyncTrustState.syncFailed,
        failureReason: message,
        configurationInvalid: _errorClassifier.isLikelyConfigurationFailure(
          errorText,
        ),
      );
      return false;
    }

    if (success && test) {
      _updateProgress('正在验证连接...');
      final tested = await _storageService.testConnection();
      if (!tested) {
        final errorText = _storageService.lastConnectionError;
        final message = _errorClassifier.buildConnectionFailureMessage(
          errorText,
          enabled: _config.enabled,
        );
        _lastError = message;
        await refreshTrustSnapshot(
          overrideState:
              _errorClassifier.isLikelyConfigurationFailure(errorText)
              ? SyncTrustState.needsAttention
              : SyncTrustState.syncFailed,
          failureReason: message,
          configurationInvalid: _errorClassifier.isLikelyConfigurationFailure(
            errorText,
          ),
        );
      }
      return tested;
    }
    return success;
  }

  /// 请求自动同步（防抖 30秒，context-free）。
  ///
  /// [fromLifecycle]: 是否由生命周期(如切前台)触发。如果是，则受 5分钟 冷却限制。
  /// [force]: 是否强制立即同步（忽略防抖和冷却）。适用于用户手动触发或重要保存操作。
  ///
  /// 返回 null 表示命令被跳过（未启用/未配置自动同步/凭据缺失），
  /// 否则返回调度决策（立即触发/已排定防抖/冷却抑制）。
  /// 本方法不接收/持有 BuildContext：自动同步执行完全静默，完成反馈
  /// 走 OS 通知与信任快照状态，由页面/协调器读取。
  Future<AutoSyncDecision?> requestAutoSync({
    bool fromLifecycle = false,
    bool force = false,
  }) async {
    // 等待初始化完成，避免冷启动时 _lastSyncTime 尚未加载导致冷却失效
    await _initFuture;

    if (!_config.enabled) return null;
    if (!_config.autoSync && !force) return null;
    if (!_config.hasRequiredCredentials) {
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.needsAttention,
        failureReason: _errorClassifier.configurationIssueMessage(
          enabled: _config.enabled,
        ),
        configurationInvalid: true,
      );
      return null;
    }

    // 冷却判断与 30s 防抖决策由调度器统一处理；
    // force 分支由调度器立即触发（跳过防抖与冷却）。
    return _autoSyncScheduler.request(
      fromLifecycle: fromLifecycle,
      force: force,
      lastSuccessfulSyncAt: _currentScopeLastSyncTime,
    );
  }

  /// 执行完整同步（context-free typed command）。
  ///
  /// 本方法保留入口门禁（赞助/启用/凭据/重入/连接）、状态与通知
  /// 编排、成功后缓存/时间/信任快照/日记列表刷新；同步算法（日记
  /// manifest、随心记 JSON/图片/语音差集）委托 [SyncRunner]。
  ///
  /// 返回 [SyncRunResult]（typed result），由页面/[SyncUiCoordinator]
  /// 翻译为用户反馈。通知权限申请不再在此进行（手动同步由协调器前置）。
  Future<SyncRunResult> sync({bool isAuto = false}) async {
    await _initFuture;

    if (!PaymentService().canUseProFeatures) {
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.needsAttention,
        failureReason: '需要赞助才能使用云同步',
        configurationInvalid: true,
      );
      return const SyncRunResult(
        status: SyncRunStatus.proRequired,
        failureMessage: '需要赞助才能使用云同步',
      );
    }

    if (!_config.enabled) {
      return const SyncRunResult(status: SyncRunStatus.notEnabled);
    }

    if (!_config.hasRequiredCredentials) {
      final message = _errorClassifier.configurationIssueMessage(
        enabled: _config.enabled,
      );
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.needsAttention,
        failureReason: message,
        configurationInvalid: true,
      );
      return SyncRunResult(
        status: SyncRunStatus.needsAttention,
        failureMessage: message,
      );
    }

    if (_status == SyncStatus.syncing) {
      return const SyncRunResult(status: SyncRunStatus.alreadySyncing);
    }

    // 确保连接
    if (!_storageService.isConnected) {
      _updateProgress('正在连接服务器...');
      bool connected = await connect(test: false);
      if (!connected) {
        final failureState =
            trustSnapshot.state == SyncTrustState.needsAttention
            ? SyncTrustState.needsAttention
            : SyncTrustState.syncFailed;
        final failureMessage = _lastError.isEmpty ? '网络异常，请稍后重试' : _lastError;
        await refreshTrustSnapshot(
          overrideState: failureState,
          failureReason: failureMessage,
          configurationInvalid: failureState == SyncTrustState.needsAttention,
        );
        return SyncRunResult(
          status: SyncRunStatus.connectionFailed,
          failureMessage: failureMessage,
        );
      }
    }

    await refreshTrustSnapshot(
      overrideState: SyncTrustState.syncing,
      clearFailureReason: true,
    );
    _updateProgress('准备开始同步...');
    if (!isAuto) _showNotification(0, 0, indeterminate: true);

    // Reset stats
    _statDiaries = 0;
    _statMoments = 0;
    _statImages = 0;
    _statAudio = 0;

    // 同步算法委托 SyncRunner（存储服务随配置切换，故按次组装；
    // 日记阶段失败仅记入 outcome，随心记阶段由 Runner 内部 try 包裹，
    // 与原实现顺序一致）。
    final outcome = await SyncRunner(
      storage: _storageService,
      momentService: _momentService,
      scopeCacheStore: _scopeCacheStore,
      progressTracker: _progressTracker,
      errorClassifier: _errorClassifier,
      onNotify: _showNotification,
    ).run(isAuto: isAuto, diaryService: _diaryProvider?.service);

    // 汇总各分类已完成操作计数（原 _statDiaries 等）
    _statDiaries = outcome.processedDiaries;
    _statMoments = outcome.processedMoments;
    _statImages = outcome.processedImages;
    _statAudio = outcome.processedAudio;

    final isSuccess = !outcome.hasUnresolvedWork;
    final failureReason = _errorClassifier.buildUserSafeFailureReason(
      outcome,
      configurationInvalid: _trustSnapshot.configurationInvalid,
      hasRequiredCredentials: _config.hasRequiredCredentials,
    );

    if (isSuccess) {
      await _persistSuccessfulSyncCaches();
      _lastSyncTime = DateTime.now();
      _currentScopeLastSyncTime = _lastSyncTime;
      _lastSuccessfulSyncPlatform = _config.syncType.name;
      await _scopeCacheStore.writeGlobalLastSyncTime(_lastSyncTime!);
      await _scopeCacheStore.persistCurrentScopeLastSyncTime(
        _config,
        _lastSyncTime!,
      );
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.syncedSuccessfully,
        clearFailureReason: true,
      );

      if (_diaryProvider != null) {
        await _diaryProvider!.loadEntries();
      }

      if (!isAuto) {
        _showCompletionNotification('同步成功');
        Future.delayed(const Duration(seconds: 2), () => _cancelNotification());
      }
      return SyncRunResult(
        status: SyncRunStatus.success,
        processedDiaries: _statDiaries,
        processedMoments: _statMoments,
        processedImages: _statImages,
        processedAudio: _statAudio,
      );
    }

    await refreshTrustSnapshot(
      overrideState: outcome.hasFailures
          ? SyncTrustState.syncFailed
          : SyncTrustState.localChangesPending,
      failureReason: outcome.hasFailures ? failureReason : null,
      clearFailureReason: !outcome.hasFailures,
    );

    final pendingCount = trustSnapshot.totalPendingCount;
    if (!isAuto) {
      _showCompletionNotification(
        outcome.hasFailures ? failureReason : '尚有 $pendingCount 项待同步',
      );
    }
    return SyncRunResult(
      status: outcome.hasFailures
          ? SyncRunStatus.failed
          : SyncRunStatus.pending,
      failureMessage: failureReason,
      pendingCount: pendingCount,
    );
  }

  // ==========================================
  // 通知管理（薄包装：进度文案更新留在本类，插件调用委托给 SyncNotificationService）
  // ==========================================
  Future<void> _showNotification(
    int? progress,
    int? max, {
    String? body,
    bool indeterminate = false,
  }) async {
    // Update local UI state
    if (body != null) _updateProgress(body);

    await _notificationService.showProgress(
      progress,
      max,
      body: body,
      indeterminate: indeterminate,
    );
  }

  Future<void> _showCompletionNotification(String message) {
    return _notificationService.showCompletion(message);
  }

  Future<void> _cancelNotification() {
    return _notificationService.cancel();
  }
}
