import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/sync_manifest.dart';
import '../models/sync_trust_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/sync/application/auto_sync_scheduler.dart';
import '../features/sync/application/sync_error_classifier.dart';
import '../features/sync/application/sync_progress_tracker.dart';
import '../features/sync/application/sync_run_outcome.dart';
import '../features/sync/application/sync_trust_engine.dart';
import '../features/sync/data/sync_config_store.dart';
import '../features/sync/data/sync_scope_cache_store.dart';
import '../features/sync/presentation/sync_notification_service.dart';
import '../models/sync_config.dart';
import '../services/webdav_sync_service.dart';
import '../services/diary_service.dart';
import '../services/moment_service.dart';
import '../services/payment_service.dart';
import '../services/sync_secret_store.dart';
import '../widgets/skeuomorphic_dialog.dart';
import '../widgets/skeuomorphic_toast.dart';
import 'diary_provider.dart';

import '../services/s3_sync_service.dart';
import '../services/cloud_storage_service.dart';

enum SyncStatus { none, syncing, success, failed }

class _PendingCounts {
  final int diaries;
  final int moments;
  final int images;
  final int audio;

  const _PendingCounts({
    this.diaries = 0,
    this.moments = 0,
    this.images = 0,
    this.audio = 0,
  });

  int get total => diaries + moments + images + audio;
}

class SyncProvider with ChangeNotifier {
  static const String _syncTrustSnapshotKey = 'sync_trust_snapshot';

  final WebDavSyncService _webDavService;
  final S3SyncService _s3Service;
  final MomentService _momentService;
  final SyncSecretStore _secretStore;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  late final SyncConfigStore _configStore;
  late final SyncScopeCacheStore _scopeCacheStore;
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
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    bool initializeNotifications = true,
  }) : _webDavService = webDavService ?? WebDavSyncService(),
       _s3Service = s3Service ?? S3SyncService(),
       _momentService = momentService ?? MomentService(),
       _secretStore = secretStore ?? SyncSecretStore.secure(),
       _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin() {
    _configStore = SyncConfigStore(secretStore: _secretStore);
    _scopeCacheStore = SyncScopeCacheStore();
    _notificationService = SyncNotificationService(
      plugin: _notificationsPlugin,
    );
    _progressTracker = SyncProgressTracker(onChanged: notifyListeners);
    _autoSyncScheduler = AutoSyncScheduler(
      onTrigger: () => sync(isAuto: true).catchError((e) {
        debugPrint('AutoSync caught error: $e');
      }),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _syncTrustSnapshotKey,
      jsonEncode(_trustSnapshot.toJson()),
    );
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

  int _countPendingManifestItems(SyncManifest local, SyncManifest remote) {
    final localKeys = local.items.keys.toSet();
    int pendingCount = 0;

    for (final key in localKeys) {
      final localItem = local.items[key];
      if (localItem == null) {
        continue;
      }

      final remoteItem = remote.items[key];
      if (remoteItem == null || !localItem.sameAs(remoteItem)) {
        pendingCount++;
      }
    }

    return pendingCount;
  }

  Future<Set<String>> _getLocalAudioNames() async {
    await _momentService.init();
    final audioDir = _momentService.audioDir;
    if (audioDir == null || !await audioDir.exists()) {
      return <String>{};
    }

    return audioDir
        .listSync()
        .whereType<File>()
        .map((file) => path.basename(file.path))
        .toSet();
  }

  int _countPendingAssetNames(Set<String> localNames, Set<String> remoteNames) {
    final localOnly = localNames.difference(remoteNames).length;
    final remoteOnly = remoteNames.difference(localNames).length;
    return localOnly + remoteOnly;
  }

  Future<_PendingCounts> _calculatePendingCounts() async {
    int pendingDiaryCount = 0;

    if (_diaryProvider != null) {
      final diaryService = _diaryProvider!.service;
      await diaryService.init();
      if (diaryService.dataDir != null) {
        await diaryService.manifestService.ensureConsistency(
          diaryService.dataDir!,
        );
      }
      final cachedDiaryManifest = await _scopeCacheStore.loadCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        _config,
      );
      pendingDiaryCount = _countPendingManifestItems(
        diaryService.manifestService.manifest,
        cachedDiaryManifest,
      );
    }

    await _momentService.init();
    if (_momentService.dataDir != null) {
      await _momentService.manifestService.ensureConsistency(
        _momentService.dataDir!,
        fileExtension: '.json',
      );
    }

    final cachedMomentManifest = await _scopeCacheStore.loadCachedManifest(
      SyncScopeCacheStore.lastKnownMomentsManifestKey,
      _config,
    );
    final pendingMomentCount = _countPendingManifestItems(
      _momentService.manifestService.manifest,
      cachedMomentManifest,
    );

    final localImages = await _momentService.getAllReferencedImages();
    final cachedImages = await _scopeCacheStore.loadCachedNameSet(
      SyncScopeCacheStore.lastKnownMomentImagesKey,
      _config,
    );
    final pendingImageCount = _countPendingAssetNames(
      localImages,
      cachedImages,
    );

    final localAudio = await _getLocalAudioNames();
    final cachedAudio = await _scopeCacheStore.loadCachedNameSet(
      SyncScopeCacheStore.lastKnownMomentAudioKey,
      _config,
    );
    final pendingAudioCount = _countPendingAssetNames(localAudio, cachedAudio);

    return _PendingCounts(
      diaries: pendingDiaryCount,
      moments: pendingMomentCount,
      images: pendingImageCount,
      audio: pendingAudioCount,
    );
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

    final pendingCounts = await _calculatePendingCounts();
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
      await _getLocalAudioNames(),
    );
  }

  Future<void> _loadConfig() async {
    _config = await _configStore.load();

    final prefs = await SharedPreferences.getInstance();
    final snapshotJson = prefs.getString(_syncTrustSnapshotKey);
    if (snapshotJson != null) {
      try {
        _trustSnapshot = SyncTrustSnapshot.fromJson(
          jsonDecode(snapshotJson) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('Error loading sync trust snapshot: $e');
      }
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

  /// 请求自动同步（防抖 30秒）
  /// 请求自动同步（防抖 30秒）
  /// [fromLifecycle]: 是否由生命周期(如切前台)触发。如果是，则受 5分钟 冷却限制。
  /// 请求自动同步（防抖 30秒）
  /// [fromLifecycle]: 是否由生命周期(如切前台)触发。如果是，则受 5分钟 冷却限制。
  /// [force]: 是否强制立即同步（忽略防抖和冷却）。适用于用户手动触发或重要保存操作。
  Future<void> requestAutoSync({
    bool fromLifecycle = false,
    bool force = false,
    BuildContext? context,
  }) async {
    // 在异步等待前捕获 context，供异步后仅作 UI 反馈使用
    final syncContext = context;
    // 等待初始化完成，避免冷启动时 _lastSyncTime 尚未加载导致冷却失效
    await _initFuture;

    if (!_config.enabled) return;
    if (!_config.autoSync && !force) return;
    if (!_config.hasRequiredCredentials) {
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.needsAttention,
        failureReason: _errorClassifier.configurationIssueMessage(
          enabled: _config.enabled,
        ),
        configurationInvalid: true,
      );
      return;
    }

    // Force Sync: Skip checks, run immediately
    if (force) {
      if (syncContext != null && syncContext.mounted) {
        // context 可用：保留 UI 反馈路径（兼容编排），取消待执行防抖后直接同步
        debugPrint('Force Sync requested. Skipping debounce and cooldown.');
        _autoSyncScheduler.cancel();
        sync(isAuto: true, context: syncContext).catchError((e) {
          debugPrint('Force Sync caught error: $e');
        });
        return;
      }
      // context 为 null 或页面已销毁：仅保留静默同步，由调度器立即触发
      _autoSyncScheduler.request(fromLifecycle: false, force: true);
      return;
    }

    // 非 force：冷却判断与 30s 防抖决策由调度器统一处理
    _autoSyncScheduler.request(
      fromLifecycle: fromLifecycle,
      force: false,
      lastSuccessfulSyncAt: _currentScopeLastSyncTime,
    );
  }

  /// 检查并请求通知权限（强制）
  /// 返回 true 表示已获得权限或无需权限，false 表示用户未授权或取消
  Future<bool> checkNotificationPermission(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    var status = await Permission.notification.status;
    if (status.isGranted) return true;

    // Show Explanation Dialog
    if (context.mounted) {
      final bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: true, // Allow click outside to cancel
        builder: (ctx) => SkeuomorphicDialog(
          title: '需要通知权限',
          headerIcon: Icons.notifications_active,
          content: const Text(
            '为了防止同步过程被系统中断，并让您直观地看到上传进度，我们需要申请通知栏权限。\n\n请授予通知权限以启用同步功能。',
          ),
          // Custom footer for single button
          footer: SizedBox(
            width: double.infinity,
            child: SkeuomorphicDialogButton(
              label: '去授予通知权限',
              onPressed: () async {
                Navigator.pop(ctx, true); // Close dialog first with flag
              },
            ),
          ),
        ),
      );

      if (result == true) {
        // User clicked "Enable"
        final newStatus = await Permission.notification.request();
        if (newStatus.isGranted) {
          return true;
        } else {
          if (context.mounted) {
            SkeuomorphicToast.info(context, '同步需要通知权限以保持后台运行');
          }
          return false;
        }
      }
    }

    return false; // Dialog dismissed or ignored
  }

  /// 执行完整同步
  Future<void> sync({bool isAuto = false, BuildContext? context}) async {
    await _initFuture;

    if (!PaymentService().canUseProFeatures) {
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.needsAttention,
        failureReason: '需要赞助才能使用云同步',
        configurationInvalid: true,
      );
      return;
    }

    if (!_config.enabled) return;

    if (!_config.hasRequiredCredentials) {
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.needsAttention,
        failureReason: _errorClassifier.configurationIssueMessage(
          enabled: _config.enabled,
        ),
        configurationInvalid: true,
      );
      return;
    }

    // Manually triggered sync: Check Permission First
    if (!isAuto && context != null) {
      if (!context.mounted) return;
      final hasPermission = await checkNotificationPermission(context);
      if (!hasPermission) {
        // User cancelled or denied permission. Abort silent.
        return;
      }
    }

    if (_status == SyncStatus.syncing) {
      if (context != null && !isAuto && context.mounted) {
        SkeuomorphicToast.info(context, '正在同步中，请稍候...');
      }
      return;
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
        if (context != null && context.mounted) {
          SkeuomorphicToast.error(context, failureMessage);
        }
        throw Exception(failureMessage);
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

    final outcome = SyncRunOutcome();

    try {
      if (_diaryProvider == null) {
        outcome.addDeleteFailure('DiaryProvider not initialized');
      } else {
        // 1. 同步日记 (Txt)
        await _syncDiaries(isAuto, outcome);
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
      outcome.addUploadFailure(e.toString());
    }

    // 2. 同步随心记 (Moments JSON & Images)
    await _syncMoments(isAuto, outcome);

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

      if (context != null && context.mounted) {
        String statMsg =
            "已同步: $_statDiaries篇日记, $_statMoments篇随心记\n$_statImages张图片, $_statAudio条语音";
        if (_statDiaries == 0 &&
            _statMoments == 0 &&
            _statImages == 0 &&
            _statAudio == 0) {
          statMsg = "同步完成 (无变更)";
        }
        SkeuomorphicToast.success(context, statMsg);
      }

      if (!isAuto) {
        _showCompletionNotification('同步成功');
        Future.delayed(const Duration(seconds: 2), () => _cancelNotification());
      }
      return;
    }

    await refreshTrustSnapshot(
      overrideState: outcome.hasFailures
          ? SyncTrustState.syncFailed
          : SyncTrustState.localChangesPending,
      failureReason: outcome.hasFailures ? failureReason : null,
      clearFailureReason: !outcome.hasFailures,
    );

    if (context != null && context.mounted) {
      final pendingMessage = '尚有 ${trustSnapshot.totalPendingCount} 项待同步';
      if (outcome.hasFailures) {
        SkeuomorphicToast.error(context, failureReason);
      } else {
        SkeuomorphicToast.info(context, pendingMessage);
      }
    }

    if (!isAuto) {
      _showCompletionNotification(
        outcome.hasFailures
            ? failureReason
            : '尚有 ${trustSnapshot.totalPendingCount} 项待同步',
      );
    }
  }

  // ==========================================
  // 并发处理辅助
  // ==========================================
  Future<void> _processBatch<T>(
    List<T> items,
    Future<void> Function(T) action,
  ) async {
    // 坚果云等 WebDAV 服务对并发请求有严格限制 (部分触发 403 Forbidden)
    // 降级为串行处理 (Batch Size = 1) 并增加间隔
    const int batchSize = 1;

    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);

      await Future.wait(batch.map((item) => action(item)));

      // 增加 1000ms 间隔，避免触发 API 速率限制 (坚果云极其敏感)
      if (i + batchSize < items.length) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  // ==========================================
  // 日记同步逻辑 (Manifest Based)
  // ==========================================
  Future<void> _syncDiaries(bool isAuto, SyncRunOutcome outcome) async {
    final service = _diaryProvider!.service;
    await service.init();

    final localManifest = service.manifestService.manifest;

    if (!isAuto) {
      _showNotification(null, null, body: "正在获取云端索引...");
    }

    final remoteManifestJsonStr = await _storageService.readRemoteFile(
      '${WebDavSyncService.rootPath}manifest.json',
    );
    final remoteManifest = _scopeCacheStore.decodeManifest(
      remoteManifestJsonStr,
    );
    final nextRemoteManifest = remoteManifest.clone();
    final mergedItems = _mergeManifests(localManifest, remoteManifest);

    int processed = 0;
    final List<String> toDownload = <String>[];
    final List<String> toUpload = <String>[];
    final List<String> toDeleteLocal = <String>[];
    final List<String> toTrashRemote = <String>[];
    final Set<String> ghostItems = <String>{};

    for (final filename in mergedItems.keys) {
      final item = mergedItems[filename]!;
      final localFile = File(path.join(service.dataDir!.path, filename));
      final localExists = await localFile.exists();

      final localItem = localManifest.items[filename];
      final remoteItem = remoteManifest.items[filename];

      if (item.isDeleted) {
        if (localExists) {
          toDeleteLocal.add(filename);
        }
        if (remoteItem == null || !remoteItem.isDeleted) {
          toTrashRemote.add(filename);
        }
        continue;
      }

      if (!localExists) {
        toDownload.add(filename);
        continue;
      }

      final fromRemote =
          remoteItem != null &&
          remoteItem.versionTimestamp == item.versionTimestamp &&
          remoteItem.versionTimestamp != (localItem?.versionTimestamp ?? -1);

      final fromLocal =
          localItem != null &&
          localItem.versionTimestamp == item.versionTimestamp &&
          localItem.versionTimestamp != (remoteItem?.versionTimestamp ?? -1);

      if (fromRemote) {
        toDownload.add(filename);
      } else if (fromLocal) {
        toUpload.add(filename);
      }
    }

    final totalOps =
        toDownload.length +
        toUpload.length +
        toDeleteLocal.length +
        toTrashRemote.length;
    _progressTracker.reset(totalOps);

    if (!isAuto && totalOps > 0) {
      _showNotification(processed, totalOps, body: "开始同步 $totalOps 个变更...");
    }

    await _processBatch(toDownload, (filename) async {
      try {
        await _storageService.downloadFile(
          WebDavSyncService.diaryBasePath + filename,
          path.join(service.dataDir!.path, filename),
        );
        service.manifestService.updateItem(
          filename,
          timestamp: mergedItems[filename]!.versionTimestamp,
          isDeleted: false,
        );
        processed++;
        _progressTracker.markItemProcessed();
        if (!isAuto) {
          _showNotification(processed, totalOps, body: "下载: $filename");
        }
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains("404") ||
            errStr.contains("Not Found") ||
            errStr.contains("NoSuchKey")) {
          ghostItems.add(filename);
          return;
        }
        outcome.addDownloadFailure('diary download $filename: $e');
      }
    });

    await _processBatch(toUpload, (filename) async {
      final file = File(path.join(service.dataDir!.path, filename));
      if (!await file.exists()) {
        return;
      }

      try {
        await _storageService.uploadFile(
          file.path,
          WebDavSyncService.diaryBasePath + filename,
        );
        nextRemoteManifest.updateItem(mergedItems[filename]!);
        processed++;
        _progressTracker.markItemProcessed();
        if (!isAuto) {
          _showNotification(processed, totalOps, body: "上传: $filename");
        }
      } catch (e) {
        outcome.addUploadFailure('diary upload $filename: $e');
      }
    });

    await _processBatch(toDeleteLocal, (filename) async {
      final file = File(path.join(service.dataDir!.path, filename));
      if (!await file.exists()) {
        return;
      }

      try {
        await service.trashService.moveToTrash(file);
        service.manifestService.updateItem(
          filename,
          timestamp: mergedItems[filename]!.versionTimestamp,
          isDeleted: true,
        );
        processed++;
        _progressTracker.markItemProcessed();
      } catch (e) {
        outcome.addDeleteFailure('diary local archive $filename: $e');
      }
    });

    await _processBatch(toTrashRemote, (filename) async {
      final srcPath = WebDavSyncService.diaryBasePath + filename;
      final trashPath = WebDavSyncService.trashBasePath + filename;

      try {
        await _storageService.ensureDirectoryExists(
          WebDavSyncService.trashBasePath,
        );
        await _storageService.moveFile(srcPath, trashPath);
        nextRemoteManifest.updateItem(
          mergedItems[filename]!.copyWith(isDeleted: true),
        );
        processed++;
        _progressTracker.markItemProcessed();
      } catch (e) {
        if (_errorClassifier.isRemoteSourceAlreadyMissing(e)) {
          nextRemoteManifest.updateItem(
            mergedItems[filename]!.copyWith(isDeleted: true),
          );
          processed++;
          _progressTracker.markItemProcessed();
          return;
        }
        outcome.addDeleteFailure('diary remote archive $filename: $e');
      }
    });

    for (final name in ghostItems) {
      service.manifestService.removeItem(name);
      nextRemoteManifest.items.remove(name);
    }

    final manifestToWrite = SyncManifest(
      lastSyncTimestamp: DateTime.now().millisecondsSinceEpoch,
      items: nextRemoteManifest.items.map(
        (key, value) => MapEntry(key, value.copyWith()),
      ),
    );

    try {
      await _storageService.writeRemoteFile(
        '${WebDavSyncService.rootPath}manifest.json',
        jsonEncode(manifestToWrite.toJson()),
      );
    } catch (e) {
      outcome.addUploadFailure('diary manifest write: $e');
    }

    _statDiaries = processed;
    await _syncTrash(service, isAuto, outcome);
  }

  Map<String, SyncItem> _mergeManifests(
    SyncManifest local,
    SyncManifest remote,
  ) {
    Set<String> allKeys = {};
    allKeys.addAll(local.items.keys);
    allKeys.addAll(remote.items.keys);

    Map<String, SyncItem> merged = {};

    for (var key in allKeys) {
      final localItem = local.items[key];
      final remoteItem = remote.items[key];

      if (localItem == null && remoteItem == null) continue;

      if (localItem == null) {
        merged[key] = remoteItem!;
      } else if (remoteItem == null) {
        merged[key] = localItem;
      } else {
        if (localItem.versionTimestamp >= remoteItem.versionTimestamp) {
          merged[key] = localItem;
        } else {
          merged[key] = remoteItem;
        }
      }
    }
    return merged;
  }

  Future<void> _syncTrash(
    DiaryService service,
    bool isAuto,
    SyncRunOutcome outcome,
  ) async {
    final trashFiles = await service.trashService.listValidTrashFiles();
    if (trashFiles.isEmpty) return;

    if (!isAuto) _showNotification(null, null, body: "正在归档回收站...");

    try {
      // 检查云端 Trash 目录是否存在
      await _storageService.ensureDirectoryExists(
        WebDavSyncService.trashBasePath,
      );

      final remoteTrashList = await _storageService.listFiles(
        WebDavSyncService.trashBasePath,
      );
      final remoteNames = remoteTrashList.map((f) => f.name).toSet();

      await _processBatch(trashFiles, (file) async {
        final name = path.basename(file.path);
        if (!remoteNames.contains(name)) {
          try {
            await _storageService.uploadFile(
              file.path,
              WebDavSyncService.trashBasePath + name,
            );
          } catch (e) {
            outcome.addUploadFailure('trash upload $name: $e');
          }
        }
      });
    } catch (e) {
      outcome.addUploadFailure('trash sync: $e');
    }
  }

  // ==========================================
  // 随心记同步逻辑 (Manifest Based)
  // ==========================================
  Future<void> _syncMoments(bool isAuto, SyncRunOutcome outcome) async {
    try {
      await _momentService.init();
      _momentService.reset();
      await _momentService.init();
      final localDir = _momentService.dataDir;
      if (localDir == null) return;

      await _syncMomentJsonFiles(isAuto, outcome);

      final service = _momentService;
      final validImages = await service.getAllReferencedImages();

      if (service.imagesDir != null) {
        await _syncMomentImages(
          service.imagesDir!,
          isAuto,
          validImages,
          outcome,
        );
      }

      if (service.audioDir != null) {
        await _syncMomentAudio(service.audioDir!, isAuto, outcome);
      }
    } catch (e) {
      outcome.addUploadFailure('moment sync: $e');
    }
  }

  Future<void> _syncMomentJsonFiles(bool isAuto, SyncRunOutcome outcome) async {
    final service = _momentService;
    await service.init();

    final localManifest = service.manifestService.manifest;

    if (!isAuto) {
      _showNotification(null, null, body: "正在获取随心记索引...");
    }

    final remoteManifestJsonStr = await _storageService.readRemoteFile(
      '${WebDavSyncService.rootPath}moments_manifest.json',
    );
    final remoteManifest = _scopeCacheStore.decodeManifest(
      remoteManifestJsonStr,
    );
    final nextRemoteManifest = remoteManifest.clone();
    final mergedItems = _mergeManifests(localManifest, remoteManifest);

    int processed = 0;
    final List<String> toDownload = <String>[];
    final List<String> toUpload = <String>[];
    final List<String> toDeleteLocal = <String>[];
    final List<String> toTrashRemote = <String>[];
    final Set<String> ghostItems = <String>{};

    for (final filename in mergedItems.keys) {
      final item = mergedItems[filename]!;
      final localFile = File(path.join(service.dataDir!.path, filename));
      final localExists = await localFile.exists();

      final localItem = localManifest.items[filename];
      final remoteItem = remoteManifest.items[filename];

      if (item.isDeleted) {
        if (localExists) {
          toDeleteLocal.add(filename);
        }
        if (remoteItem == null || !remoteItem.isDeleted) {
          toTrashRemote.add(filename);
        }
        continue;
      }

      if (!localExists) {
        toDownload.add(filename);
        continue;
      }

      final fromRemote =
          remoteItem != null &&
          remoteItem.versionTimestamp == item.versionTimestamp &&
          remoteItem.versionTimestamp != (localItem?.versionTimestamp ?? -1);

      final fromLocal =
          localItem != null &&
          localItem.versionTimestamp == item.versionTimestamp &&
          localItem.versionTimestamp != (remoteItem?.versionTimestamp ?? -1);

      if (fromRemote) {
        toDownload.add(filename);
      } else if (fromLocal) {
        toUpload.add(filename);
      }
    }

    final totalOps =
        toDownload.length +
        toUpload.length +
        toDeleteLocal.length +
        toTrashRemote.length;
    _progressTracker.reset(totalOps);

    if (!isAuto && totalOps > 0) {
      _showNotification(processed, totalOps, body: "同步随心记 ($totalOps)...");
    }

    await _processBatch(toDownload, (filename) async {
      _progressTracker.resetCurrentFile();
      try {
        await _storageService.downloadFile(
          WebDavSyncService.momentsBasePath + filename,
          path.join(service.dataDir!.path, filename),
          onProgress: _progressTracker.onFileProgress,
        );
        service.manifestService.updateItem(
          filename,
          timestamp: mergedItems[filename]!.versionTimestamp,
          isDeleted: false,
        );
        processed++;
        _progressTracker.markItemProcessed();
        if (!isAuto) {
          _showNotification(processed, totalOps, body: "随心记下载: $filename");
        }
      } catch (e) {
        final errStr = e.toString();
        if (errStr.contains("404") ||
            errStr.contains("Not Found") ||
            errStr.contains("NoSuchKey")) {
          ghostItems.add(filename);
          return;
        }
        outcome.addDownloadFailure('moment download $filename: $e');
      }
    });

    await _processBatch(toUpload, (filename) async {
      final file = File(path.join(service.dataDir!.path, filename));
      if (!await file.exists()) {
        return;
      }

      _progressTracker.resetCurrentFile();
      try {
        await _storageService.uploadFile(
          file.path,
          WebDavSyncService.momentsBasePath + filename,
          onProgress: _progressTracker.onFileProgress,
        );
        nextRemoteManifest.updateItem(mergedItems[filename]!);
        processed++;
        _progressTracker.markItemProcessed();
        if (!isAuto) {
          _showNotification(processed, totalOps, body: "随心记上传: $filename");
        }
      } catch (e) {
        outcome.addUploadFailure('moment upload $filename: $e');
      }
    });

    await _processBatch(toDeleteLocal, (filename) async {
      try {
        await service.archiveMomentByFilename(
          filename,
          manifestTimestamp: mergedItems[filename]!.versionTimestamp,
        );
        processed++;
        _progressTracker.markItemProcessed();
        if (!isAuto) {
          _showNotification(processed, totalOps, body: "随心记归档: $filename");
        }
      } catch (e) {
        outcome.addDeleteFailure('moment local archive $filename: $e');
      }
    });

    await _processBatch(toTrashRemote, (filename) async {
      final srcPath = '${WebDavSyncService.momentsBasePath}$filename';
      final trashPath = '${WebDavSyncService.trashBasePath}moments_$filename';

      try {
        await _storageService.ensureDirectoryExists(
          WebDavSyncService.trashBasePath,
        );
        await _storageService.moveFile(srcPath, trashPath);
        nextRemoteManifest.updateItem(
          mergedItems[filename]!.copyWith(isDeleted: true),
        );
        processed++;
        _progressTracker.markItemProcessed();
      } catch (e) {
        if (_errorClassifier.isRemoteSourceAlreadyMissing(e)) {
          nextRemoteManifest.updateItem(
            mergedItems[filename]!.copyWith(isDeleted: true),
          );
          processed++;
          _progressTracker.markItemProcessed();
          return;
        }
        outcome.addDeleteFailure('moment remote archive $filename: $e');
      }
    });

    for (final name in ghostItems) {
      service.manifestService.removeItem(name);
      nextRemoteManifest.items.remove(name);
    }

    final manifestToWrite = SyncManifest(
      lastSyncTimestamp: DateTime.now().millisecondsSinceEpoch,
      items: nextRemoteManifest.items.map(
        (key, value) => MapEntry(key, value.copyWith()),
      ),
    );

    try {
      await _storageService.writeRemoteFile(
        '${WebDavSyncService.rootPath}moments_manifest.json',
        jsonEncode(manifestToWrite.toJson()),
      );
    } catch (e) {
      outcome.addUploadFailure('moment manifest write: $e');
    }

    _statMoments = processed;
  }

  Future<void> _syncMomentImages(
    Directory localImagesDir,
    bool isAuto,
    Set<String> validImageNames,
    SyncRunOutcome outcome,
  ) async {
    if (!isAuto) _showNotification(null, null, body: "正在同步图片...");

    // 1. Get Remote List
    List<RemoteFile> remoteImagesRaw = await _storageService.listFiles(
      WebDavSyncService.momentsImagesPath,
    );
    Set<String> remoteImageNames = remoteImagesRaw.map((f) => f.name).toSet();

    // 2. Get Local List
    List<FileSystemEntity> localImages = localImagesDir.listSync();

    // 3. Collect Uploads
    List<FileSystemEntity> toUpload = [];
    List<FileSystemEntity> toDeleteLocal = [];

    for (var file in localImages) {
      if (file is! File) continue;

      String name = path.basename(file.path);
      // Local Orphan Check
      if (!validImageNames.contains(name)) {
        toDeleteLocal.add(file);
        continue;
      }

      if (!remoteImageNames.contains(name)) {
        toUpload.add(file);
      }
    }

    // Safety Check: 如果自动同步时发现大量文件需要上传，可能是因为误判或新设备迁移
    // 为了防止流量偷跑，跳过本次自动同步
    if (isAuto && toUpload.length > 20) {
      debugPrint(
        'AutoSync Safety: Skipping upload of ${toUpload.length} images to prevent high data usage.',
      );
      outcome.skippedOperations += toUpload.length;
      return;
    }

    List<String> toDeleteRemote = [];
    List<String> toDownload = [];

    for (var remoteFile in remoteImagesRaw) {
      String name = remoteFile.name;

      // ORPHAN CHECK: If not in validImageNames, it's trash!
      if (!validImageNames.contains(name)) {
        toDeleteRemote.add(name);
        continue; // Skip download check
      }

      File localFile = File(path.join(localImagesDir.path, name));
      bool exists = localFile.existsSync();
      if (!exists) {
        toDownload.add(name);
      }
    }

    int total =
        toUpload.length +
        toDownload.length +
        toDeleteRemote.length +
        toDeleteLocal.length;
    int processed = 0;

    // Cleanup Remote Orphans First
    if (toDeleteRemote.isNotEmpty) {
      debugPrint("Cleaning up ${toDeleteRemote.length} orphan images...");
      await _processBatch(toDeleteRemote, (name) async {
        try {
          await _storageService.deleteFile(
            WebDavSyncService.momentsImagesPath + name,
          );
          processed++;
          if (!isAuto) {
            _showNotification(processed, total, body: "清理云端无效图片: $name");
          }
        } catch (e) {
          outcome.addDeleteFailure('image remote cleanup $name: $e');
        }
      });
    }

    // Cleanup Local Orphans
    if (toDeleteLocal.isNotEmpty) {
      debugPrint("Cleaning up ${toDeleteLocal.length} local orphan images...");
      for (var f in toDeleteLocal) {
        try {
          if (f.existsSync()) {
            f.deleteSync();
            processed++;
            if (!isAuto) {
              _showNotification(
                processed,
                total,
                body: "清理本地无效图片: ${path.basename(f.path)}",
              );
            }
          }
        } catch (e) {
          outcome.addDeleteFailure(
            'image local cleanup ${path.basename(f.path)}: $e',
          );
        }
      }
    }

    // Parallel Upload
    await _processBatch(toUpload, (f) async {
      String name = path.basename(f.path);
      try {
        await _storageService.uploadFile(
          f.path,
          WebDavSyncService.momentsImagesPath + name,
        );
        processed++;
        if (!isAuto) _showNotification(processed, total, body: "图片上传: $name");
      } catch (e) {
        outcome.addUploadFailure('image upload $name: $e');
      }
    });

    // Parallel Download
    await _processBatch(toDownload, (name) async {
      File localFile = File(path.join(localImagesDir.path, name));
      try {
        await _storageService
            .downloadFile(
              WebDavSyncService.momentsImagesPath + name,
              localFile.path,
            )
            .timeout(const Duration(seconds: 15));
        processed++;
        if (!isAuto) _showNotification(processed, total, body: "图片下载: $name");
      } catch (e) {
        outcome.addDownloadFailure('image download $name: $e');
      }
    });
    _statImages = processed;
  }

  Future<void> _syncMomentAudio(
    Directory localAudioDir,
    bool isAuto,
    SyncRunOutcome outcome,
  ) async {
    if (!isAuto) _showNotification(null, null, body: "正在同步语音...");

    // 1. Get Remote List
    List<RemoteFile> remoteAudioRaw = await _storageService.listFiles(
      WebDavSyncService.momentsAudioPath,
    );
    Set<String> remoteAudioNames = remoteAudioRaw.map((f) => f.name).toSet();

    // 2. Get Local List
    List<FileSystemEntity> localAudioFiles = localAudioDir.listSync();

    // 3. Collect Uploads
    List<File> toUpload = [];
    for (var f in localAudioFiles) {
      if (f is File) {
        String name = path.basename(f.path);
        if (!remoteAudioNames.contains(name)) {
          toUpload.add(f);
        }
      }
    }

    // Safety Check
    if (isAuto && toUpload.length > 20) {
      debugPrint(
        'AutoSync Safety: Skipping upload of ${toUpload.length} audio files.',
      );
      outcome.skippedOperations += toUpload.length;
      return;
    }

    // 4. Collect Downloads
    List<String> toDownload = [];
    for (var remoteFile in remoteAudioRaw) {
      String name = remoteFile.name;
      File localFile = File(path.join(localAudioDir.path, name));
      if (!localFile.existsSync()) {
        toDownload.add(name);
      }
    }

    int total = toUpload.length + toDownload.length;
    int processed = 0;

    // Parallel Upload
    await _processBatch(toUpload, (f) async {
      String name = path.basename(f.path);
      try {
        await _storageService.uploadFile(
          f.path,
          WebDavSyncService.momentsAudioPath + name,
        );
        processed++;
        if (!isAuto) _showNotification(processed, total, body: "语音上传: $name");
      } catch (e) {
        outcome.addUploadFailure('audio upload $name: $e');
      }
    });

    // Parallel Download
    await _processBatch(toDownload, (name) async {
      File localFile = File(path.join(localAudioDir.path, name));
      try {
        await _storageService.downloadFile(
          WebDavSyncService.momentsAudioPath + name,
          localFile.path,
        );
        processed++;
        if (!isAuto) _showNotification(processed, total, body: "语音下载: $name");
      } catch (e) {
        outcome.addDownloadFailure('audio download $name: $e');
      }
    });
    _statAudio = processed;
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
