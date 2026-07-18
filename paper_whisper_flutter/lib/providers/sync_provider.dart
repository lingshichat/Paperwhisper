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

class SyncRunOutcome {
  int failedUploads = 0;
  int failedDownloads = 0;
  int failedDeletes = 0;
  int skippedOperations = 0;
  final List<String> errors = <String>[];

  bool get hasFailures =>
      failedUploads > 0 || failedDownloads > 0 || failedDeletes > 0;

  bool get hasUnresolvedWork => hasFailures || skippedOperations > 0;

  void addUploadFailure(String message) {
    failedUploads++;
    errors.add(message);
  }

  void addDownloadFailure(String message) {
    failedDownloads++;
    errors.add(message);
  }

  void addDeleteFailure(String message) {
    failedDeletes++;
    errors.add(message);
  }
}

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
  static const String _syncConfigKey = 'sync_config';
  static const String _syncTrustSnapshotKey = 'sync_trust_snapshot';
  static const String _lastSyncTimeKey = 'last_sync_time';
  static const String _currentScopeLastSyncTimeKey = 'last_sync_time_scope';
  static const String _lastKnownRemoteManifestKey =
      'last_known_remote_manifest';
  static const String _lastKnownMomentsManifestKey =
      'last_known_moments_manifest';
  static const String _lastKnownMomentImagesKey =
      'last_known_remote_moment_images';
  static const String _lastKnownMomentAudioKey =
      'last_known_remote_moment_audio';

  final WebDavSyncService _webDavService;
  final S3SyncService _s3Service;
  final MomentService _momentService;
  final SyncSecretStore _secretStore;
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  DiaryProvider? _diaryProvider;

  SyncConfig _config = SyncConfig();
  SyncStatus _status = SyncStatus.none;
  String _lastError = '';
  String _progressMessage = '';
  DateTime? _lastSyncTime;
  DateTime? _currentScopeLastSyncTime;
  String? _lastSuccessfulSyncPlatform;
  SyncTrustSnapshot _trustSnapshot = SyncTrustSnapshot.notEnabled;

  // Progress & Speed State
  double _currentFileProgress = 0.0;
  String _currentFileSpeed = '';
  int _lastBytesCount = 0;
  DateTime? _lastSpeedUpdate;

  // Total Progress & ETA State
  int _totalOps = 0;
  int _processedOps = 0;
  DateTime? _batchStartTime;
  String _etaMessage = '';

  Timer? _autoSyncTimer;
  static const int _notificationId = 888;
  static const String _channelId = 'paper_whisper_sync';
  static const String _channelName = 'Sync Status';

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

  double get currentFileProgress => _currentFileProgress;
  String get currentFileSpeed => _currentFileSpeed;

  /// Total Progress (0.0 - 1.0)
  /// Formula: (processed + currentFilePart) / total
  double get totalProgress {
    if (_totalOps == 0) return 0.0;
    // Cap currentFileProgress to 1.0 just in case
    double filePart = _currentFileProgress.clamp(0.0, 1.0);
    return (_processedOps + filePart) / _totalOps;
  }

  String get etaMessage => _etaMessage;

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
    _initFuture = _loadConfig();
    if (initializeNotifications) {
      _initNotifications();
    }
  }

  void updateDiaryProvider(DiaryProvider dp) {
    _diaryProvider = dp;
  }

  @visibleForTesting
  Future<void> ensureInitialized() => _initFuture;

  Future<void> waitUntilReady() => _initFuture;

  // Helper to reset transfer stats
  void _resetTransferStats(int totalOperations) {
    _currentFileProgress = 0.0;
    _currentFileSpeed = '';
    _lastBytesCount = 0;
    _lastSpeedUpdate = null;

    _totalOps = totalOperations;
    _processedOps = 0;
    _batchStartTime = DateTime.now();
    _etaMessage = '计算中...';
    notifyListeners();
  }

  void _onTransferProgress(int count, int total) {
    // debugPrint('SyncProgress: $count / $total'); // Reduce log noise

    final now = DateTime.now();

    // Calculate Progress
    if (total > 0) {
      _currentFileProgress = count / total;
    } else {
      _currentFileProgress = 0.0;
    }

    // Initial speed display
    if (_currentFileSpeed.isEmpty) {
      _currentFileSpeed = "计算中...";
    }

    // Update Speed & ETA every 500ms
    if (_lastSpeedUpdate == null ||
        now.difference(_lastSpeedUpdate!).inMilliseconds >= 500) {
      _updateSpeedAndETA(now, count);
      _lastSpeedUpdate = now;
      _lastBytesCount = count;
      notifyListeners();
    }
  }

  void _updateSpeedAndETA(DateTime now, int count) {
    // 1. Calculate Instant Speed
    if (_lastSpeedUpdate != null && count > _lastBytesCount) {
      final diffMs = now.difference(_lastSpeedUpdate!).inMilliseconds;
      if (diffMs > 0) {
        final bytesDiff = count - _lastBytesCount;
        final speedBytesPerSec = (bytesDiff / diffMs) * 1000;
        _currentFileSpeed = _formatSpeed(speedBytesPerSec);
      }
    }

    // 2. Calculate ETA based on Item Count
    // (Since we don't know total bytes size for downloads)
    if (_batchStartTime != null &&
        _processedOps > 0 &&
        _totalOps > _processedOps) {
      final elapsedMs = now.difference(_batchStartTime!).inMilliseconds;
      // Time per item = elapsed / processed
      final msPerItem = elapsedMs / _processedOps; // Simple average
      final remainingItems = _totalOps - _processedOps;

      // Deduct current item progress from remaining time?
      // Let's keep it simple: ETA based on full completed items is more stable.
      // Refined: time = avg * (remaining - currentPart)
      final estimatedRemainingMs =
          msPerItem * (remainingItems - _currentFileProgress);

      if (estimatedRemainingMs > 0) {
        final duration = Duration(milliseconds: estimatedRemainingMs.toInt());
        if (duration.inHours > 0) {
          _etaMessage =
              '剩余 ${duration.inHours} 小时 ${duration.inMinutes % 60} 分';
        } else if (duration.inMinutes > 0) {
          _etaMessage =
              '剩余 ${duration.inMinutes} 分 ${duration.inSeconds % 60} 秒';
        } else {
          _etaMessage = '剩余 ${duration.inSeconds} 秒';
        }
      }
    } else if (_processedOps == 0) {
      _etaMessage = '计算中...';
    } else {
      _etaMessage = '即将完成';
    }
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return "${bytesPerSec.toStringAsFixed(0)} B/s";
    if (bytesPerSec < 1024 * 1024)
      return "${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s";
    return "${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s";
  }

  // Helper to update progress message and notify UI
  void _updateProgress(String message) {
    _progressMessage = message;
    notifyListeners();
  }

  // Helper to reset just the current file stats (for loop iteration)
  void _resetCurrentFileStats() {
    _currentFileProgress = 0.0;
    _currentFileSpeed = '';
    _lastBytesCount = 0;
    _lastSpeedUpdate = null;
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

  String _configurationIssueMessage() {
    if (!_config.enabled) {
      return '同步未启用';
    }
    return '配置异常，请检查账号或服务器地址';
  }

  bool _isLikelyConfigurationFailure(String? errorText) {
    final normalized = (errorText ?? '').toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('unauthorized') ||
        normalized.contains('forbidden') ||
        normalized.contains('invalidaccesskey') ||
        normalized.contains('invalidaccesskeyid') ||
        normalized.contains('signature') ||
        normalized.contains('access denied') ||
        normalized.contains('missing credentials') ||
        normalized.contains('bucket does not exist') ||
        normalized.contains('nosuchbucket');
  }

  String _buildConnectionFailureMessage(String? errorText) {
    final normalized = (errorText ?? '').toLowerCase();
    if (_isLikelyConfigurationFailure(normalized)) {
      return _configurationIssueMessage();
    }
    if (normalized.contains('socketexception') ||
        normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('network') ||
        normalized.contains('failed host lookup') ||
        normalized.contains('connection refused') ||
        normalized.contains('connection reset')) {
      return '网络异常，请稍后重试';
    }
    return '连接失败，请稍后重试';
  }

  bool _isRemoteSourceAlreadyMissing(Object error) {
    final text = error.toString();
    return text.contains('404') ||
        text.contains('Not Found') ||
        text.contains('NoSuchKey') ||
        text.contains('Copy Source must exist') ||
        text.contains('source bucket and key');
  }

  String _buildSyncScopeId([SyncConfig? config]) {
    final activeConfig = config ?? _config;
    final rawScope =
        activeConfig.syncType == SyncType.webdav
            ? 'webdav|${activeConfig.serverUrl.trim().toLowerCase()}|${activeConfig.username.trim().toLowerCase()}'
            : 's3|${activeConfig.s3EndPoint.trim().toLowerCase()}|${activeConfig.s3BucketName.trim().toLowerCase()}|${activeConfig.s3AccessKey.trim().toLowerCase()}|${(activeConfig.s3Region ?? '').trim().toLowerCase()}';

    return base64UrlEncode(utf8.encode(rawScope)).replaceAll('=', '');
  }

  String _scopeStorageKey(String baseKey, [SyncConfig? config]) {
    return '${baseKey}_${_buildSyncScopeId(config)}';
  }

  SyncManifest _decodeManifest(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) {
      return SyncManifest(lastSyncTimestamp: 0, items: {});
    }

    try {
      return SyncManifest.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Sync manifest cache decode failed: $e');
      return SyncManifest(lastSyncTimestamp: 0, items: {});
    }
  }

  Future<SyncManifest> _loadCachedManifest(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeManifest(prefs.getString(_scopeStorageKey(key)));
  }

  Future<void> _saveCachedManifest(String key, SyncManifest manifest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopeStorageKey(key), jsonEncode(manifest.toJson()));
  }

  Future<Set<String>> _loadCachedNameSet(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_scopeStorageKey(key)) ?? <String>[]).toSet();
  }

  Future<void> _saveCachedNameSet(String key, Set<String> values) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scopeStorageKey(key),
      values.toList()..sort(),
    );
  }

  Future<void> _loadCurrentScopeLastSyncTime(SharedPreferences prefs) async {
    final timeStr = prefs.getString(_scopeStorageKey(_currentScopeLastSyncTimeKey));
    _currentScopeLastSyncTime =
        timeStr == null ? null : DateTime.tryParse(timeStr);
  }

  Future<void> _persistCurrentScopeLastSyncTime(
    SharedPreferences prefs,
    DateTime value,
  ) async {
    await prefs.setString(
      _scopeStorageKey(_currentScopeLastSyncTimeKey),
      value.toIso8601String(),
    );
  }

  Future<void> _migrateLegacyScopeCacheIfNeeded(
    SharedPreferences prefs,
  ) async {
    final scopedDiaryKey = _scopeStorageKey(_lastKnownRemoteManifestKey);
    final scopedMomentKey = _scopeStorageKey(_lastKnownMomentsManifestKey);
    final scopedImageKey = _scopeStorageKey(_lastKnownMomentImagesKey);
    final scopedAudioKey = _scopeStorageKey(_lastKnownMomentAudioKey);
    final scopedTimeKey = _scopeStorageKey(_currentScopeLastSyncTimeKey);

    final legacyDiary = prefs.getString(_lastKnownRemoteManifestKey);
    if (!prefs.containsKey(scopedDiaryKey) && legacyDiary != null) {
      await prefs.setString(scopedDiaryKey, legacyDiary);
    }

    final legacyMoments = prefs.getString(_lastKnownMomentsManifestKey);
    if (!prefs.containsKey(scopedMomentKey) && legacyMoments != null) {
      await prefs.setString(scopedMomentKey, legacyMoments);
    }

    final legacyImages = prefs.getStringList(_lastKnownMomentImagesKey);
    if (!prefs.containsKey(scopedImageKey) && legacyImages != null) {
      await prefs.setStringList(scopedImageKey, legacyImages);
    }

    final legacyAudio = prefs.getStringList(_lastKnownMomentAudioKey);
    if (!prefs.containsKey(scopedAudioKey) && legacyAudio != null) {
      await prefs.setStringList(scopedAudioKey, legacyAudio);
    }

    final legacyTime = prefs.getString(_lastSyncTimeKey);
    if (!prefs.containsKey(scopedTimeKey) && legacyTime != null) {
      await prefs.setString(scopedTimeKey, legacyTime);
    }

    await prefs.remove(_lastKnownRemoteManifestKey);
    await prefs.remove(_lastKnownMomentsManifestKey);
    await prefs.remove(_lastKnownMomentImagesKey);
    await prefs.remove(_lastKnownMomentAudioKey);
  }

  Future<void> _persistSecrets(SyncConfig config) async {
    await _secretStore.writeWebDavPassword(config.password);
    await _secretStore.writeS3SecretKey(config.s3SecretKey);
  }

  Future<SyncConfig> _hydrateConfigSecrets(SyncConfig config) async {
    try {
      final webDavPassword = await _secretStore.readWebDavPassword();
      final s3SecretKey = await _secretStore.readS3SecretKey();
      return config.copyWith(
        password: webDavPassword ?? config.password,
        s3SecretKey: s3SecretKey ?? config.s3SecretKey,
      );
    } catch (e) {
      debugPrint('Error loading sync secrets: $e');
      return config;
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
      final cachedDiaryManifest = await _loadCachedManifest(
        _lastKnownRemoteManifestKey,
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

    final cachedMomentManifest = await _loadCachedManifest(
      _lastKnownMomentsManifestKey,
    );
    final pendingMomentCount = _countPendingManifestItems(
      _momentService.manifestService.manifest,
      cachedMomentManifest,
    );

    final localImages = await _momentService.getAllReferencedImages();
    final cachedImages = await _loadCachedNameSet(_lastKnownMomentImagesKey);
    final pendingImageCount = _countPendingAssetNames(
      localImages,
      cachedImages,
    );

    final localAudio = await _getLocalAudioNames();
    final cachedAudio = await _loadCachedNameSet(_lastKnownMomentAudioKey);
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

    SyncTrustState nextState = overrideState ?? _trustSnapshot.state;
    bool nextConfigurationInvalid = configurationInvalid;
    String? nextFailureReason = failureReason;

    if (!_config.enabled) {
      nextState = SyncTrustState.notEnabled;
      nextConfigurationInvalid = false;
      if (clearFailureReason && nextFailureReason == null) {
        nextFailureReason = null;
      }
    } else if (!_config.hasRequiredCredentials) {
      nextState = SyncTrustState.needsAttention;
      nextConfigurationInvalid = true;
      nextFailureReason ??= _configurationIssueMessage();
    } else if (overrideState == SyncTrustState.needsAttention) {
      nextState = SyncTrustState.needsAttention;
      nextConfigurationInvalid = configurationInvalid;
    } else if (overrideState == SyncTrustState.syncing) {
      nextState = SyncTrustState.syncing;
      nextConfigurationInvalid = false;
    } else if (failureReason != null) {
      nextState = SyncTrustState.syncFailed;
      nextConfigurationInvalid = configurationInvalid;
    } else if (hasPendingChanges) {
      nextState = SyncTrustState.localChangesPending;
      nextConfigurationInvalid = false;
      if (clearFailureReason) {
        nextFailureReason = null;
      }
    } else if (_currentScopeLastSyncTime != null) {
      nextState = SyncTrustState.syncedSuccessfully;
      nextConfigurationInvalid = false;
      if (clearFailureReason) {
        nextFailureReason = null;
      }
    } else {
      nextState = SyncTrustState.needsAttention;
      nextConfigurationInvalid = false;
      nextFailureReason = clearFailureReason ? null : nextFailureReason;
    }

    await _updateTrustSnapshot(
      _trustSnapshot.copyWith(
        state: nextState,
        pendingDiaryCount: pendingCounts.diaries,
        pendingMomentCount: pendingCounts.moments,
        pendingImageCount: pendingCounts.images,
        pendingAudioCount: pendingCounts.audio,
        lastSuccessfulSyncAt: _lastSyncTime,
        lastSuccessfulSyncPlatform: _lastSuccessfulSyncPlatform,
        failureReason: nextFailureReason,
        configurationInvalid: nextConfigurationInvalid,
        clearFailureReason: clearFailureReason && nextFailureReason == null,
      ),
      notify: notify,
    );
  }

  Future<void> _persistSuccessfulSyncCaches() async {
    if (_diaryProvider != null) {
      final diaryManifest =
          _diaryProvider!.service.manifestService.manifest.clone();
      await _saveCachedManifest(_lastKnownRemoteManifestKey, diaryManifest);
    }

    await _saveCachedManifest(
      _lastKnownMomentsManifestKey,
      _momentService.manifestService.manifest.clone(),
    );
    await _saveCachedNameSet(
      _lastKnownMomentImagesKey,
      await _momentService.getAllReferencedImages(),
    );
    await _saveCachedNameSet(
      _lastKnownMomentAudioKey,
      await _getLocalAudioNames(),
    );
  }

  String _buildUserSafeFailureReason(SyncRunOutcome outcome) {
    if (_trustSnapshot.configurationInvalid ||
        !_config.hasRequiredCredentials) {
      return '配置异常，请检查账号或服务器地址';
    }

    final errorText = outcome.errors.join(' ');
    if (errorText.contains('401') || errorText.contains('Unauthorized')) {
      return '配置异常，请检查账号或服务器地址';
    }
    if (errorText.contains('403') || errorText.contains('Forbidden')) {
      return '同步失败，内容仍保留在本地';
    }
    if (errorText.contains('SocketException') ||
        errorText.contains('Network') ||
        errorText.contains('Timeout')) {
      return '网络异常，请稍后重试';
    }
    if (outcome.skippedOperations > 0) {
      return '尚有内容待同步';
    }
    return '同步失败，内容仍保留在本地';
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // Darwin (iOS) settings can be added here
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    if (Platform.isAndroid || Platform.isIOS) {
      await _notificationsPlugin.initialize(settings: initializationSettings);
    }
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await migrateLegacySyncSecrets(prefs, _secretStore);
    final jsonStr = prefs.getString(_syncConfigKey);
    if (jsonStr != null) {
      try {
        _config = SyncConfig.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        debugPrint('Error loading sync config: $e');
      }
    }
    _config = await _hydrateConfigSecrets(_config);

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
    final timeStr = prefs.getString(_lastSyncTimeKey);
    if (timeStr != null) {
      _lastSyncTime = DateTime.tryParse(timeStr);
    }

    await _migrateLegacyScopeCacheIfNeeded(prefs);
    await _loadCurrentScopeLastSyncTime(prefs);

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
    final prefs = await SharedPreferences.getInstance();

    await _persistSecrets(newConfig);
    _config = newConfig;
    await prefs.setString(_syncConfigKey, jsonEncode(_config.toJson()));
    await _loadCurrentScopeLastSyncTime(prefs);
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
      final message = _configurationIssueMessage();
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
      final message = _buildConnectionFailureMessage(errorText);
      _lastError = message;
      await refreshTrustSnapshot(
        overrideState:
            _isLikelyConfigurationFailure(errorText)
                ? SyncTrustState.needsAttention
                : SyncTrustState.syncFailed,
        failureReason: message,
        configurationInvalid: _isLikelyConfigurationFailure(errorText),
      );
      return false;
    }

    if (success && test) {
      _updateProgress('正在验证连接...');
      final tested = await _storageService.testConnection();
      if (!tested) {
        final errorText = _storageService.lastConnectionError;
        final message = _buildConnectionFailureMessage(errorText);
        _lastError = message;
        await refreshTrustSnapshot(
          overrideState:
              _isLikelyConfigurationFailure(errorText)
                  ? SyncTrustState.needsAttention
                  : SyncTrustState.syncFailed,
          failureReason: message,
          configurationInvalid: _isLikelyConfigurationFailure(errorText),
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
    // 等待初始化完成，避免冷启动时 _lastSyncTime 尚未加载导致冷却失效
    await _initFuture;

    if (!_config.enabled) return;
    if (!_config.autoSync && !force) return;
    if (!_config.hasRequiredCredentials) {
      await refreshTrustSnapshot(
        overrideState: SyncTrustState.needsAttention,
        failureReason: _configurationIssueMessage(),
        configurationInvalid: true,
      );
      return;
    }

    // Force Sync: Skip checks, run immediately
    if (force) {
      debugPrint('Force Sync requested. Skipping debounce and cooldown.');
      if (_autoSyncTimer?.isActive ?? false) _autoSyncTimer!.cancel();
      // Pass context for feedback
      sync(isAuto: true, context: context).catchError((e) {
        debugPrint('Force Sync caught error: $e');
      });
      return;
    }

    // Cooldown verification for lifecycle events
    if (fromLifecycle && _currentScopeLastSyncTime != null) {
      final diff = DateTime.now().difference(_currentScopeLastSyncTime!);
      if (diff.inMinutes < 5) {
        debugPrint(
          'AutoSync suppressed (Cooldown: ${5 - diff.inMinutes}m remaining)',
        );
        return;
      }
    }

    debugPrint('AutoSync requested. Debouncing...');
    if (_autoSyncTimer?.isActive ?? false) _autoSyncTimer!.cancel();

    _autoSyncTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('AutoSync triggered!');
      // Context might be stale here if widget disposed, so usually we don't pass context
      // from a delayed timer unless we are sure.
      // Safe to pass null for pure auto sync.
      sync(isAuto: true).catchError((e) {
        debugPrint('AutoSync caught error: $e');
      });
    });
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
        builder:
            (ctx) => SkeuomorphicDialog(
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
        failureReason: _configurationIssueMessage(),
        configurationInvalid: true,
      );
      return;
    }

    // Manually triggered sync: Check Permission First
    if (!isAuto && context != null) {
      final hasPermission = await checkNotificationPermission(context);
      if (!hasPermission) {
        // User cancelled or denied permission. Abort silent.
        return;
      }
    }

    if (_status == SyncStatus.syncing) {
      if (context != null && !isAuto) {
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
        final failureMessage =
            _lastError.isEmpty ? '网络异常，请稍后重试' : _lastError;
        await refreshTrustSnapshot(
          overrideState: failureState,
          failureReason: failureMessage,
          configurationInvalid:
              failureState == SyncTrustState.needsAttention,
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
    final failureReason = _buildUserSafeFailureReason(outcome);

    if (isSuccess) {
      await _persistSuccessfulSyncCaches();
      _lastSyncTime = DateTime.now();
      _currentScopeLastSyncTime = _lastSyncTime;
      _lastSuccessfulSyncPlatform = _config.syncType.name;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncTimeKey, _lastSyncTime!.toIso8601String());
      await _persistCurrentScopeLastSyncTime(prefs, _lastSyncTime!);
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
      overrideState:
          outcome.hasFailures
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
      WebDavSyncService.rootPath + 'manifest.json',
    );
    final remoteManifest = _decodeManifest(remoteManifestJsonStr);
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
    _resetTransferStats(totalOps);

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
        _processedOps++;
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
        _processedOps++;
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
        _processedOps++;
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
        _processedOps++;
      } catch (e) {
        if (_isRemoteSourceAlreadyMissing(e)) {
          nextRemoteManifest.updateItem(
            mergedItems[filename]!.copyWith(isDeleted: true),
          );
          processed++;
          _processedOps++;
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
        WebDavSyncService.rootPath + 'manifest.json',
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
      WebDavSyncService.rootPath + 'moments_manifest.json',
    );
    final remoteManifest = _decodeManifest(remoteManifestJsonStr);
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
    _resetTransferStats(totalOps);

    if (!isAuto && totalOps > 0) {
      _showNotification(processed, totalOps, body: "同步随心记 ($totalOps)...");
    }

    await _processBatch(toDownload, (filename) async {
      _resetCurrentFileStats();
      try {
        await _storageService.downloadFile(
          WebDavSyncService.momentsBasePath + filename,
          path.join(service.dataDir!.path, filename),
          onProgress: _onTransferProgress,
        );
        service.manifestService.updateItem(
          filename,
          timestamp: mergedItems[filename]!.versionTimestamp,
          isDeleted: false,
        );
        processed++;
        _processedOps++;
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

      _resetCurrentFileStats();
      try {
        await _storageService.uploadFile(
          file.path,
          WebDavSyncService.momentsBasePath + filename,
          onProgress: _onTransferProgress,
        );
        nextRemoteManifest.updateItem(mergedItems[filename]!);
        processed++;
        _processedOps++;
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
        _processedOps++;
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
        _processedOps++;
      } catch (e) {
        if (_isRemoteSourceAlreadyMissing(e)) {
          nextRemoteManifest.updateItem(
            mergedItems[filename]!.copyWith(isDeleted: true),
          );
          processed++;
          _processedOps++;
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
        WebDavSyncService.rootPath + 'moments_manifest.json',
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
          if (!isAuto)
            _showNotification(processed, total, body: "清理云端无效图片: $name");
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
            if (!isAuto)
              _showNotification(
                processed,
                total,
                body: "清理本地无效图片: ${path.basename(f.path)}",
              );
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
  // 通知管理
  // ==========================================
  Future<void> _showNotification(
    int? progress,
    int? max, {
    String? body,
    bool indeterminate = false,
  }) async {
    // Update local UI state
    if (body != null) _updateProgress(body);

    if (!Platform.isAndroid && !Platform.isIOS) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '显示同步状态和进度',
          importance:
              Importance.low, // Low = no sound/vibrate, good for progress
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: max ?? 100,
          progress: progress ?? 0,
          indeterminate: indeterminate || (progress == null && max == null),
          ongoing: true, // Prevent swipe away
          autoCancel: false,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: _notificationId,
      title: 'PaperWhisper 云同步',
      body: body ?? '正在同步中...',
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> _showCompletionNotification(String message) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '显示同步状态和进度',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
        );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: _notificationId,
      title: '同步完成',
      body: message,
      notificationDetails: platformChannelSpecifics,
    );
  }

  Future<void> _cancelNotification() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await _notificationsPlugin.cancel(id: _notificationId);
  }
}
