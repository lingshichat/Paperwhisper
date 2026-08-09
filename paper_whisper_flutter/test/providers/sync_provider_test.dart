import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:paper_whisper_flutter/features/sync/application/auto_sync_scheduler.dart';
import 'package:paper_whisper_flutter/features/sync/application/sync_run_result.dart';
import 'package:paper_whisper_flutter/models/diary_entry.dart';
import 'package:paper_whisper_flutter/models/moment.dart';
import 'package:paper_whisper_flutter/models/sync_config.dart';
import 'package:paper_whisper_flutter/models/sync_trust_snapshot.dart';
import 'package:paper_whisper_flutter/providers/diary_provider.dart';
import 'package:paper_whisper_flutter/providers/sync_provider.dart';
import 'package:paper_whisper_flutter/services/cloud_storage_service.dart';
import 'package:paper_whisper_flutter/services/diary_service.dart';
import 'package:paper_whisper_flutter/services/manifest_service.dart';
import 'package:paper_whisper_flutter/services/moment_service.dart';
import 'package:paper_whisper_flutter/services/s3_sync_service.dart';
import 'package:paper_whisper_flutter/services/sync_secret_store.dart';
import 'package:paper_whisper_flutter/services/trash_service.dart';
import 'package:paper_whisper_flutter/services/webdav_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncProvider', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tempDir = await Directory.systemTemp.createTemp('sync_provider_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('requestAutoSync returns early when auto sync is disabled', () async {
      final provider = TestableSyncProvider(
        webDavService: FakeWebDavSyncService(),
        momentService: FakeMomentService(tempDir),
        secretStore: SyncSecretStore.fake(),
        initializeNotifications: false,
      );

      await provider.saveConfig(
        SyncConfig(
          enabled: true,
          autoSync: false,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );

      final decision = await provider.requestAutoSync(fromLifecycle: true);

      expect(decision, isNull, reason: '未启用自动同步时命令被跳过');
      expect(provider.syncCallCount, 0);
    });

    test(
      'saveConfig persists config, notifies listeners, and never triggers sync',
      () async {
        final secretStore = SyncSecretStore.fake();
        final provider = TestableSyncProvider(
          webDavService: FakeWebDavSyncService(),
          momentService: FakeMomentService(tempDir),
          secretStore: secretStore,
          initializeNotifications: false,
        );
        await provider.ensureInitialized();

        var notifyCount = 0;
        provider.addListener(() => notifyCount++);

        final config = SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        );
        await provider.saveConfig(config);

        // 内存中配置已更新
        expect(provider.config.enabled, isTrue);
        expect(provider.config.autoSync, isTrue);
        expect(provider.config.serverUrl, 'https://dav.example.com/');
        expect(provider.config.username, 'demo');
        // 保存配置本身不触发同步，只做连接/状态刷新
        expect(provider.syncCallCount, 0);
        // 监听器收到通知（trust snapshot 刷新）
        expect(notifyCount, greaterThan(0));

        // 持久化：新实例（共享同一 secret store）能读回同一份配置
        final reloaded = TestableSyncProvider(
          webDavService: FakeWebDavSyncService(),
          momentService: FakeMomentService(tempDir),
          secretStore: secretStore,
          initializeNotifications: false,
        );
        await reloaded.ensureInitialized();
        expect(reloaded.config.enabled, isTrue);
        expect(reloaded.config.autoSync, isTrue);
        expect(reloaded.config.serverUrl, 'https://dav.example.com/');
        expect(reloaded.config.username, 'demo');
        // 密码不落 SharedPreferences，经 secret store 回填
        expect(reloaded.config.password, 'secret');
      },
    );

    test(
      'sync returns early without connecting when sync is disabled',
      () async {
        final webDav = FakeWebDavSyncService();
        final provider = SyncProvider(
          webDavService: webDav,
          momentService: FakeMomentService(tempDir),
          secretStore: SyncSecretStore.fake(),
          initializeNotifications: false,
        );
        await provider.ensureInitialized();

        // 默认配置未启用：sync 应安全早退，不连接、不改变信任状态
        final result = await provider.sync();

        expect(result.status, SyncRunStatus.notEnabled);
        expect(provider.trustSnapshot.state, SyncTrustState.notEnabled);
        expect(provider.lastError, isEmpty);
        expect(webDav.isConnected, isFalse);
      },
    );

    test(
      'sync marks needs attention when enabled but credentials are missing',
      () async {
        final webDav = FakeWebDavSyncService();
        final provider = SyncProvider(
          webDavService: webDav,
          momentService: FakeMomentService(tempDir),
          secretStore: SyncSecretStore.fake(),
          initializeNotifications: false,
        );
        await provider.ensureInitialized();

        // 启用同步但未填写账号/密码
        await provider.saveConfig(
          SyncConfig(
            enabled: true,
            autoSync: true,
            serverUrl: 'https://dav.example.com/',
            username: '',
            password: '',
          ),
        );

        final result = await provider.sync();

        expect(result.status, SyncRunStatus.needsAttention);
        expect(result.failureMessage, '配置异常，请检查账号或服务器地址');
        expect(provider.trustSnapshot.state, SyncTrustState.needsAttention);
        expect(provider.lastError, '配置异常，请检查账号或服务器地址');
        expect(webDav.isConnected, isFalse);
      },
    );

    test(
      'partial upload failure leaves sync in failed state with pending items',
      () async {
        const filename = '2026-03-12_a.txt';
        final diaryService = FakeDiaryService(tempDir);
        await diaryService.init();
        final diaryFile = File(path.join(diaryService.dataDir!.path, filename));
        await diaryFile.writeAsString(
          DiaryEntry(
            filename: filename,
            dateString: '2026-03-12',
            title: '测试日记',
            content: 'pending content',
          ).toFileContent(),
        );
        diaryService.manifestService.updateItem(
          filename,
          isDeleted: false,
          timestamp: 123456789,
        );

        final diaryProvider = DiaryProvider(diaryService, <DiaryEntry>[]);
        final provider = SyncProvider(
          webDavService: FakeWebDavSyncService(failUploadFor: filename),
          momentService: FakeMomentService(tempDir),
          secretStore: SyncSecretStore.fake(),
          initializeNotifications: false,
        );
        provider.updateDiaryProvider(diaryProvider);

        await provider.saveConfig(
          SyncConfig(
            enabled: true,
            autoSync: true,
            serverUrl: 'https://dav.example.com/',
            username: 'demo',
            password: 'secret',
          ),
        );

        await provider.sync();

        expect(provider.trustSnapshot.state, SyncTrustState.syncFailed);
        expect(provider.trustSnapshot.totalPendingCount, greaterThan(0));
        expect(provider.lastSyncTime, isNull);
      },
    );

    test(
      'moment image upload failure keeps failed trust state with pending media',
      () async {
        const imageName = 'demo.jpg';
        // 使用真实 MomentService（debug 数据目录）：saveMoment 与
        // getAllReferencedImages 必须走真实公开实现，图片引用才能被
        // 同步引擎识别（fake 重声明 _dataDir 遮蔽父类字段，且引用恒为空）
        final momentService = MomentService(debugDataDir: tempDir);
        await momentService.init();

        // 准备一条带图片的随心记，媒体文件真实落盘
        final imageFile = File(
          path.join(momentService.imagesDir!.path, imageName),
        );
        await imageFile.create(recursive: true);
        await imageFile.writeAsString('image-bytes');
        await momentService.saveMoment(
          Moment(
            uuid: 'img-fail',
            content: '带图片的随心记',
            images: const <String>['images/demo.jpg'],
            createdAt: DateTime(2026, 3, 12, 10, 0),
          ),
        );

        // 日记侧为空，确保失败只来自图片上传阶段
        final diaryService = FakeDiaryService(tempDir);
        await diaryService.init();
        final diaryProvider = DiaryProvider(diaryService, <DiaryEntry>[]);

        final provider = SyncProvider(
          webDavService: FakeWebDavSyncService(failUploadFor: imageName),
          momentService: momentService,
          secretStore: SyncSecretStore.fake(),
          initializeNotifications: false,
        );
        provider.updateDiaryProvider(diaryProvider);

        await provider.saveConfig(
          SyncConfig(
            enabled: true,
            autoSync: true,
            serverUrl: 'https://dav.example.com/',
            username: 'demo',
            password: 'secret',
          ),
        );

        await provider.sync();

        // 图片上传失败 → 失败态，且 pending 计数按类别保留
        expect(provider.trustSnapshot.state, SyncTrustState.syncFailed);
        expect(provider.trustSnapshot.pendingMomentCount, greaterThan(0));
        expect(provider.trustSnapshot.pendingImageCount, greaterThan(0));
        expect(provider.trustSnapshot.totalPendingCount, greaterThan(0));
        expect(provider.trustSnapshot.failureReason, isNotNull);
        expect(provider.trustSnapshot.failureReason, isNotEmpty);
        expect(provider.lastSyncTime, isNull);
      },
    );

    test('connect failure from network marks sync as failed', () async {
      final provider = SyncProvider(
        webDavService: FakeWebDavSyncService(
          connectResult: false,
          connectionError: 'SocketException: Failed host lookup',
        ),
        momentService: FakeMomentService(tempDir),
        secretStore: SyncSecretStore.fake(),
        initializeNotifications: false,
      );

      await provider.saveConfig(
        SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );

      final connected = await provider.connect();

      expect(connected, isFalse);
      expect(provider.trustSnapshot.state, SyncTrustState.syncFailed);
      expect(provider.lastError, '网络异常，请稍后重试');
    });

    test('connect failure from auth marks sync as needing attention', () async {
      final provider = SyncProvider(
        webDavService: FakeWebDavSyncService(
          connectResult: false,
          connectionError: '401 Unauthorized',
        ),
        momentService: FakeMomentService(tempDir),
        secretStore: SyncSecretStore.fake(),
        initializeNotifications: false,
      );

      await provider.saveConfig(
        SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );

      final connected = await provider.connect();

      expect(connected, isFalse);
      expect(provider.trustSnapshot.state, SyncTrustState.needsAttention);
      expect(provider.lastError, '配置异常，请检查账号或服务器地址');
    });

    test(
      'switching back to a previously synced platform restores its baseline',
      () async {
        const filename = '2026-03-12_scope.txt';
        final diaryService = FakeDiaryService(tempDir);
        await diaryService.init();
        final diaryFile = File(path.join(diaryService.dataDir!.path, filename));
        await diaryFile.writeAsString(
          DiaryEntry(
            filename: filename,
            dateString: '2026-03-12',
            title: '平台切换测试',
            content: 'same content',
          ).toFileContent(),
        );
        diaryService.manifestService.updateItem(
          filename,
          isDeleted: false,
          timestamp: 22334455,
        );

        final diaryProvider = DiaryProvider(diaryService, <DiaryEntry>[]);
        final provider = SyncProvider(
          webDavService: FakeWebDavSyncService(),
          s3Service: FakeS3SyncService(),
          momentService: FakeMomentService(tempDir),
          secretStore: SyncSecretStore.fake(),
          initializeNotifications: false,
        );
        provider.updateDiaryProvider(diaryProvider);

        final s3Config = SyncConfig(
          enabled: true,
          autoSync: true,
          syncType: SyncType.s3,
          s3EndPoint: 's3.example.com',
          s3AccessKey: 'ak',
          s3SecretKey: 'sk',
          s3BucketName: 'bucket-a',
        );
        final webDavConfig = SyncConfig(
          enabled: true,
          autoSync: true,
          syncType: SyncType.webdav,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        );

        await provider.saveConfig(s3Config);
        await provider.sync();

        expect(provider.trustSnapshot.state, SyncTrustState.syncedSuccessfully);
        expect(provider.trustSnapshot.totalPendingCount, 0);
        expect(provider.trustSnapshot.lastSuccessfulSyncPlatform, 's3');

        await provider.saveConfig(webDavConfig);

        expect(
          provider.trustSnapshot.state,
          SyncTrustState.localChangesPending,
        );
        expect(provider.trustSnapshot.totalPendingCount, greaterThan(0));
        expect(provider.trustSnapshot.lastSuccessfulSyncPlatform, 's3');

        await provider.saveConfig(s3Config);

        expect(provider.trustSnapshot.state, SyncTrustState.syncedSuccessfully);
        expect(provider.trustSnapshot.totalPendingCount, 0);
        expect(provider.trustSnapshot.lastSuccessfulSyncPlatform, 's3');
      },
    );

    test(
      'remote missing during S3 archive delete does not fail sync',
      () async {
        const filename = '2026-03-12_deleted.txt';
        final diaryService = FakeDiaryService(tempDir);
        await diaryService.init();
        diaryService.manifestService.updateItem(
          filename,
          isDeleted: true,
          timestamp: 99887766,
        );

        final diaryProvider = DiaryProvider(diaryService, <DiaryEntry>[]);
        final provider = SyncProvider(
          webDavService: FakeWebDavSyncService(),
          s3Service: FakeS3SyncService(),
          momentService: FakeMomentService(tempDir),
          secretStore: SyncSecretStore.fake(),
          initializeNotifications: false,
        );
        provider.updateDiaryProvider(diaryProvider);

        await provider.saveConfig(
          SyncConfig(
            enabled: true,
            autoSync: true,
            syncType: SyncType.s3,
            s3EndPoint: 's3.example.com',
            s3AccessKey: 'ak',
            s3SecretKey: 'sk',
            s3BucketName: 'bucket-a',
          ),
        );

        await provider.sync();

        expect(provider.trustSnapshot.state, SyncTrustState.syncedSuccessfully);
        expect(provider.trustSnapshot.totalPendingCount, 0);
      },
    );

    test('sync returns connectionFailed result when connection fails', () async {
      final provider = SyncProvider(
        webDavService: FakeWebDavSyncService(
          connectResult: false,
          connectionError: 'SocketException: Failed host lookup',
        ),
        momentService: FakeMomentService(tempDir),
        secretStore: SyncSecretStore.fake(),
        initializeNotifications: false,
      );

      await provider.saveConfig(
        SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );

      final result = await provider.sync();

      expect(result.status, SyncRunStatus.connectionFailed);
      expect(result.failureMessage, '网络异常，请稍后重试');
      expect(provider.trustSnapshot.state, SyncTrustState.syncFailed);
    });

    test('sync returns alreadySyncing result while a sync is in progress', () async {
      final provider = SyncProvider(
        webDavService: FakeWebDavSyncService(),
        momentService: FakeMomentService(tempDir),
        secretStore: SyncSecretStore.fake(),
        initializeNotifications: false,
      );

      await provider.saveConfig(
        SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );

      // 将信任态置为 syncing（模拟正在执行的同步），重入保护应返回 typed result
      await provider.refreshTrustSnapshot(
        overrideState: SyncTrustState.syncing,
      );

      final result = await provider.sync();

      expect(result.status, SyncRunStatus.alreadySyncing);
      expect(result.failureMessage, isEmpty);
    });

    test('sync returns success result with zero changes on a clean state', () async {
      final diaryService = FakeDiaryService(tempDir);
      await diaryService.init();
      final diaryProvider = DiaryProvider(diaryService, <DiaryEntry>[]);
      final provider = SyncProvider(
        webDavService: FakeWebDavSyncService(),
        momentService: FakeMomentService(tempDir),
        secretStore: SyncSecretStore.fake(),
        initializeNotifications: false,
      );
      provider.updateDiaryProvider(diaryProvider);

      await provider.saveConfig(
        SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );

      final result = await provider.sync();

      expect(result.status, SyncRunStatus.success);
      expect(result.hasChanges, isFalse);
      expect(result.processedDiaries, 0);
      expect(result.processedMoments, 0);
      expect(provider.trustSnapshot.state, SyncTrustState.syncedSuccessfully);
      expect(provider.trustSnapshot.totalPendingCount, 0);
      expect(provider.lastSyncTime, isNotNull);
    });

    test('requestAutoSync schedules a debounced sync when auto sync is enabled', () async {
      final provider = SyncProvider(
        webDavService: FakeWebDavSyncService(),
        momentService: FakeMomentService(tempDir),
        secretStore: SyncSecretStore.fake(),
        initializeNotifications: false,
      );

      await provider.saveConfig(
        SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );

      // 首次触发（无上次同步时间）不受冷却限制，返回防抖排定决策
      final decision = await provider.requestAutoSync(fromLifecycle: true);

      expect(decision, AutoSyncDecision.scheduled);
      // 先排空 saveConfig 后台 connect 的异步链，再释放调度器取消 30s 防抖
      await pumpEventQueue();
      provider.dispose();
    });

    test('requestAutoSync force triggers immediately even when auto sync is off', () async {
      final provider = TestableSyncProvider(
        webDavService: FakeWebDavSyncService(),
        momentService: FakeMomentService(tempDir),
        secretStore: SyncSecretStore.fake(),
        initializeNotifications: false,
      );

      await provider.saveConfig(
        SyncConfig(
          enabled: true,
          autoSync: false,
          serverUrl: 'https://dav.example.com/',
          username: 'demo',
          password: 'secret',
        ),
      );

      final decision = await provider.requestAutoSync(force: true);

      expect(decision, AutoSyncDecision.triggeredNow);
      await pumpEventQueue();
      expect(provider.syncCallCount, 1);
    });

    test('requestAutoSync returns null and marks needsAttention when credentials missing', () async {
      final provider = SyncProvider(
        webDavService: FakeWebDavSyncService(),
        momentService: FakeMomentService(tempDir),
        secretStore: SyncSecretStore.fake(),
        initializeNotifications: false,
      );

      await provider.saveConfig(
        SyncConfig(
          enabled: true,
          autoSync: true,
          serverUrl: 'https://dav.example.com/',
          username: '',
          password: '',
        ),
      );

      final decision = await provider.requestAutoSync(fromLifecycle: true);

      expect(decision, isNull);
      expect(provider.trustSnapshot.state, SyncTrustState.needsAttention);
    });
  });
}

class TestableSyncProvider extends SyncProvider {
  int syncCallCount = 0;

  TestableSyncProvider({
    super.webDavService,
    super.s3Service,
    super.momentService,
    super.secretStore,
    super.notificationService,
    super.initializeNotifications,
  });

  @override
  Future<SyncRunResult> sync({bool isAuto = false}) async {
    syncCallCount++;
    return const SyncRunResult(status: SyncRunStatus.success);
  }
}

class FakeWebDavSyncService extends WebDavSyncService {
  FakeWebDavSyncService({
    this.failUploadFor,
    this.connectResult = true,
    this.testConnectionResult = true,
    this.connectionError,
  });

  final String? failUploadFor;
  final bool connectResult;
  final bool testConnectionResult;
  final String? connectionError;
  final Map<String, String> remoteFiles = <String, String>{};
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void initConfig(String serverUrl, String username, String password) {}

  @override
  Future<bool> connect() async {
    _connected = connectResult;
    return connectResult;
  }

  @override
  Future<bool> testConnection() async => testConnectionResult;

  @override
  String? get lastConnectionError => connectionError;

  @override
  Future<List<RemoteFile>> listFiles(String remotePath) async => <RemoteFile>[];

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    Function(int sent, int total)? onProgress,
  }) async {
    if (failUploadFor != null && remotePath.endsWith(failUploadFor!)) {
      throw Exception('Network failure');
    }
    remoteFiles[remotePath] = await File(localPath).readAsString();
    onProgress?.call(1, 1);
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    Function(int received, int total)? onProgress,
  }) async {
    final content = remoteFiles[remotePath];
    if (content == null) {
      throw Exception('404 Not Found');
    }
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    onProgress?.call(1, 1);
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    remoteFiles.remove(remotePath);
  }

  @override
  Future<void> moveFile(String oldPath, String newPath) async {
    final content = remoteFiles.remove(oldPath);
    if (content == null) {
      throw Exception('404 Not Found');
    }
    remoteFiles[newPath] = content;
  }

  @override
  Future<String?> readRemoteFile(String remotePath) async =>
      remoteFiles[remotePath];

  @override
  Future<void> writeRemoteFile(String remotePath, String content) async {
    remoteFiles[remotePath] = content;
  }

  @override
  Future<void> ensureDirectoryExists(String remotePath) async {}
}

class FakeDiaryService extends DiaryService {
  FakeDiaryService(this.rootDir);

  final Directory rootDir;
  final ManifestService _manifestService = ManifestService();
  final TrashService _trashService = TrashService();
  Directory? _dataDir;
  bool _initialized = false;

  @override
  Directory? get dataDir => _dataDir;

  @override
  String get currentDataPath => _dataDir?.path ?? 'Unknown';

  @override
  ManifestService get manifestService => _manifestService;

  @override
  TrashService get trashService => _trashService;

  @override
  void reset() {
    _initialized = false;
    _dataDir = null;
  }

  @override
  Future<void> init() async {
    if (_initialized) return;

    _dataDir = Directory(path.join(rootDir.path, 'diary_data'));
    await _dataDir!.create(recursive: true);
    await _manifestService.init(_dataDir!);
    await _trashService.init(_dataDir!);
    _initialized = true;
  }

  @override
  Future<List<DiaryEntry>> getEntries() async => <DiaryEntry>[];

  @override
  Future<void> saveCache(List<DiaryEntry> entries) async {}

  @override
  Future<List<DiaryEntry>?> loadCache() async => null;
}

class FakeS3SyncService extends S3SyncService {
  FakeS3SyncService({
    this.failUploadFor,
    this.connectResult = true,
    this.testConnectionResult = true,
    this.connectionError,
  });

  final String? failUploadFor;
  final bool connectResult;
  final bool testConnectionResult;
  final String? connectionError;
  final Map<String, String> remoteFiles = <String, String>{};
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  String? get lastConnectionError => connectionError;

  @override
  void initConfig({
    required String endPoint,
    required String accessKey,
    required String secretKey,
    required String bucketName,
    String? region,
  }) {}

  @override
  Future<bool> connect() async {
    _connected = connectResult;
    return connectResult;
  }

  @override
  Future<bool> testConnection() async => testConnectionResult;

  @override
  Future<List<RemoteFile>> listFiles(String remotePath) async => <RemoteFile>[];

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath, {
    Function(int sent, int total)? onProgress,
  }) async {
    if (failUploadFor != null && remotePath.endsWith(failUploadFor!)) {
      throw Exception('Network failure');
    }
    remoteFiles[remotePath] = await File(localPath).readAsString();
    onProgress?.call(1, 1);
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    String localPath, {
    Function(int received, int total)? onProgress,
  }) async {
    final content = remoteFiles[remotePath];
    if (content == null) {
      throw Exception('404 Not Found');
    }
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    onProgress?.call(1, 1);
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    remoteFiles.remove(remotePath);
  }

  @override
  Future<void> moveFile(String oldPath, String newPath) async {
    final content = remoteFiles.remove(oldPath);
    if (content == null) {
      throw Exception('404 Not Found');
    }
    remoteFiles[newPath] = content;
  }

  @override
  Future<String?> readRemoteFile(String remotePath) async =>
      remoteFiles[remotePath];

  @override
  Future<void> writeRemoteFile(String remotePath, String content) async {
    remoteFiles[remotePath] = content;
  }

  @override
  Future<void> ensureDirectoryExists(String remotePath) async {}
}

class FakeMomentService extends MomentService {
  FakeMomentService(this.rootDir);

  final Directory rootDir;
  final ManifestService _manifestService = ManifestService();
  Directory? _dataDir;
  Directory? _imagesDir;
  Directory? _audioDir;
  bool _initialized = false;

  @override
  Directory? get dataDir => _dataDir;

  @override
  Directory? get imagesDir => _imagesDir;

  @override
  Directory? get audioDir => _audioDir;

  @override
  ManifestService get manifestService => _manifestService;

  @override
  void reset() {
    _initialized = false;
    _dataDir = null;
    _imagesDir = null;
    _audioDir = null;
  }

  @override
  Future<void> init() async {
    if (_initialized) return;

    _dataDir = Directory(path.join(rootDir.path, 'moments_data'));
    _imagesDir = Directory(path.join(_dataDir!.path, 'images'));
    _audioDir = Directory(path.join(_dataDir!.path, 'audio'));

    await _dataDir!.create(recursive: true);
    await _imagesDir!.create(recursive: true);
    await _audioDir!.create(recursive: true);
    await _manifestService.init(
      _dataDir!,
      manifestFileName: 'local_moments_manifest.json',
    );
    _initialized = true;
  }

  @override
  Future<Set<String>> getAllReferencedImages() async => <String>{};
}
