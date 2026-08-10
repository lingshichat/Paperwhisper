import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../../models/sync_manifest.dart';
import '../../../services/cloud_storage_service.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_service.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import '../../../services/webdav_sync_service.dart';
import '../data/sync_scope_cache_store.dart';
import 'sync_error_classifier.dart';
import 'sync_progress_tracker.dart';
import 'sync_run_outcome.dart';

/// 同步进度/文案回调（原 `SyncProvider._showNotification` 的输入签名）。
///
/// 由门面注入：body 更新进度文案并转交 OS 通知服务，Runner 本身
/// 不持有任何通知插件、BuildContext 或 Widget。
typedef SyncNotificationCallback =
    void Function(int? progress, int? max, {String? body, bool indeterminate});

/// 同步引擎（原 `SyncProvider` 的 `_processBatch`/`_syncDiaries`/`_mergeManifests`/
/// `_syncTrash`/`_syncMoments`/`_syncMomentJsonFiles`/`_syncMomentImages`/
/// `_syncMomentAudio`，约 800 行，逐字迁移）。
///
/// 职责边界：
/// - 纯 Manifest 合并（时间戳判胜、单边存在、删除标记原样）以静态
///   [mergeManifests] 暴露，可独立单测；
/// - [run] 按「日记 → 随心记 JSON → 图片 → 语音」顺序执行，填充并返回
///   [SyncRunOutcome]（上传/下载/删除失败计数、错误列表、各分类已完成计数、
///   自动同步流量保护跳过的操作数）；
/// - 不持有 BuildContext / Widget / Toast / Dialog / Provider / 通知插件；
///   进度展示经 [onNotify] 回调转交门面。
///
/// 兼容红线（逐字保留）：
/// - `batch=1 + 每项 1s 间隔`（`_processBatch`，规避坚果云限流）；
/// - 远端目录路径（`WebDavSyncService.rootPath/diaryBasePath/trashBasePath/
///   momentsBasePath/momentsImagesPath/momentsAudioPath`）与
///   `manifest.json` / `moments_manifest.json` 文件名；
/// - 幽灵项（远端 404/Not Found/NoSuchKey）容错与双向孤儿清理；
/// - 自动同步上传 >20 的流量保护（计入 `skippedOperations`）；
/// - 图片下载 15s 超时、时间戳判胜合并、统计计数与进度文案。
///
/// 本批次不改动 `MomentService` 的 reset/init 冗余（由实例所有权批次处理）。
class SyncRunner {
  SyncRunner({
    required CloudStorageService storage,
    required MomentService momentService,
    required SyncScopeCacheStore scopeCacheStore,
    required SyncProgressTracker progressTracker,
    required SyncErrorClassifier errorClassifier,
    required SyncNotificationCallback onNotify,
    this.batchDelay = const Duration(seconds: 1),
    this.imageDownloadTimeout = const Duration(seconds: 15),
  }) : _storage = storage,
       _momentService = momentService,
       _scopeCacheStore = scopeCacheStore,
       _progressTracker = progressTracker,
       _errorClassifier = errorClassifier,
       _onNotify = onNotify;

  /// 每批操作之间的等待间隔，规避坚果云等 WebDAV 服务的限流（默认 1s，
  /// 对应原 `_processBatch` 的硬编码 1000ms）。测试可注入更短时长加速用例。
  final Duration batchDelay;

  /// 图片下载超时（默认 15s，对应原 `_syncMomentImages` 的硬编码值）。
  final Duration imageDownloadTimeout;

  final CloudStorageService _storage;
  final MomentService _momentService;
  final SyncScopeCacheStore _scopeCacheStore;
  final SyncProgressTracker _progressTracker;
  final SyncErrorClassifier _errorClassifier;
  final SyncNotificationCallback _onNotify;

  /// 纯函数：本地/远端 manifest 合并（时间戳判胜，仅单边存在则取该侧，
  /// 删除标记 `isDeleted` 原样保留）。
  ///
  /// 迁移来源：原 `SyncProvider._mergeManifests`（1041-1073）。
  static Map<String, SyncItem> mergeManifests(
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

  /// 执行完整同步。日记阶段失败仅记入 outcome 不中断，
  /// 随心记阶段整体由内部 try 包裹，与原实现顺序一致。
  ///
  /// [diaryService] 为 null 时记入「DiaryProvider not initialized」
  /// 删除失败并继续随心记同步（原 `SyncProvider.sync` 的日记侧空判断）。
  Future<SyncRunOutcome> run({
    required bool isAuto,
    DiaryService? diaryService,
  }) async {
    final outcome = SyncRunOutcome();

    try {
      if (diaryService == null) {
        outcome.addDeleteFailure('DiaryProvider not initialized');
      } else {
        // 1. 同步日记 (Txt)
        await _syncDiaries(diaryService, isAuto, outcome);
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
      outcome.addUploadFailure(e.toString());
    }

    // 2. 同步随心记 (Moments JSON & Images)
    await _syncMoments(isAuto, outcome);

    return outcome;
  }

  // 通知回调包装：`indeterminate` 提供默认值，转发给门面注入的回调。
  void _notify(
    int? progress,
    int? max, {
    String? body,
    bool indeterminate = false,
  }) {
    _onNotify(progress, max, body: body, indeterminate: indeterminate);
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

      // 增加 batchDelay 间隔，避免触发 API 速率限制 (坚果云极其敏感)
      if (i + batchSize < items.length) {
        await Future.delayed(batchDelay);
      }
    }
  }

  // ==========================================
  // 日记同步逻辑 (Manifest Based)
  // ==========================================
  Future<void> _syncDiaries(
    DiaryService service,
    bool isAuto,
    SyncRunOutcome outcome,
  ) async {
    await service.init();

    final localManifest = service.manifestService.manifest;

    if (!isAuto) {
      _notify(null, null, body: "正在获取云端索引...");
    }

    final remoteManifestJsonStr = await _storage.readRemoteFile(
      '${WebDavSyncService.rootPath}manifest.json',
    );
    final remoteManifest = _scopeCacheStore.decodeManifest(
      remoteManifestJsonStr,
    );
    final nextRemoteManifest = remoteManifest.clone();
    final mergedItems = mergeManifests(localManifest, remoteManifest);

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
      _notify(processed, totalOps, body: "开始同步 $totalOps 个变更...");
    }

    await _processBatch(toDownload, (filename) async {
      try {
        await _storage.downloadFile(
          WebDavSyncService.diaryBasePath + filename,
          path.join(service.dataDir!.path, filename),
        );
        await service.manifestService.updateItem(
          filename,
          timestamp: mergedItems[filename]!.versionTimestamp,
          isDeleted: false,
        );
        processed++;
        _progressTracker.markItemProcessed();
        if (!isAuto) {
          _notify(processed, totalOps, body: "下载: $filename");
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
        await _storage.uploadFile(
          file.path,
          WebDavSyncService.diaryBasePath + filename,
        );
        nextRemoteManifest.updateItem(mergedItems[filename]!);
        processed++;
        _progressTracker.markItemProcessed();
        if (!isAuto) {
          _notify(processed, totalOps, body: "上传: $filename");
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
        await service.manifestService.updateItem(
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
        await _storage.ensureDirectoryExists(WebDavSyncService.trashBasePath);
        await _storage.moveFile(srcPath, trashPath);
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
      await service.manifestService.removeItem(
        name,
        expectedVersionTimestamp: mergedItems[name]!.versionTimestamp,
      );
      nextRemoteManifest.items.remove(name);
    }

    final manifestToWrite = SyncManifest(
      lastSyncTimestamp: DateTime.now().millisecondsSinceEpoch,
      items: nextRemoteManifest.items.map(
        (key, value) => MapEntry(key, value.copyWith()),
      ),
    );

    try {
      await _storage.writeRemoteFile(
        '${WebDavSyncService.rootPath}manifest.json',
        jsonEncode(manifestToWrite.toJson()),
      );
    } catch (e) {
      outcome.addUploadFailure('diary manifest write: $e');
    }

    outcome.processedDiaries = processed;
    await _syncTrash(service, isAuto, outcome);
  }

  Future<void> _syncTrash(
    DiaryService service,
    bool isAuto,
    SyncRunOutcome outcome,
  ) async {
    final trashFiles = await service.trashService.listValidTrashFiles();
    if (trashFiles.isEmpty) return;

    if (!isAuto) _notify(null, null, body: "正在归档回收站...");

    try {
      // 检查云端 Trash 目录是否存在
      await _storage.ensureDirectoryExists(WebDavSyncService.trashBasePath);

      final remoteTrashList = await _storage.listFiles(
        WebDavSyncService.trashBasePath,
      );
      final remoteNames = remoteTrashList.map((f) => f.name).toSet();

      await _processBatch(trashFiles, (file) async {
        final name = path.basename(file.path);
        if (!remoteNames.contains(name)) {
          try {
            await _storage.uploadFile(
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
      // 共享的 MomentService 已在 composition root 初始化；这里仅做
      // 幂等的首次 init 保护（init 内部 `_dataDir != null` 直接返回），
      // 移除原 init→reset→init 冗余，避免不必要的 IO 与状态重置。
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
      _notify(null, null, body: "正在获取随心记索引...");
    }

    final remoteManifestJsonStr = await _storage.readRemoteFile(
      '${WebDavSyncService.rootPath}moments_manifest.json',
    );
    final remoteManifest = _scopeCacheStore.decodeManifest(
      remoteManifestJsonStr,
    );
    final nextRemoteManifest = remoteManifest.clone();
    final mergedItems = mergeManifests(localManifest, remoteManifest);

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
      _notify(processed, totalOps, body: "同步随心记 ($totalOps)...");
    }

    await _processBatch(toDownload, (filename) async {
      _progressTracker.resetCurrentFile();
      try {
        await _storage.downloadFile(
          WebDavSyncService.momentsBasePath + filename,
          path.join(service.dataDir!.path, filename),
          onProgress: _progressTracker.onFileProgress,
        );
        await service.manifestService.updateItem(
          filename,
          timestamp: mergedItems[filename]!.versionTimestamp,
          isDeleted: false,
        );
        processed++;
        _progressTracker.markItemProcessed();
        if (!isAuto) {
          _notify(processed, totalOps, body: "随心记下载: $filename");
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
        await _storage.uploadFile(
          file.path,
          WebDavSyncService.momentsBasePath + filename,
          onProgress: _progressTracker.onFileProgress,
        );
        nextRemoteManifest.updateItem(mergedItems[filename]!);
        processed++;
        _progressTracker.markItemProcessed();
        if (!isAuto) {
          _notify(processed, totalOps, body: "随心记上传: $filename");
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
          _notify(processed, totalOps, body: "随心记归档: $filename");
        }
      } catch (e) {
        outcome.addDeleteFailure('moment local archive $filename: $e');
      }
    });

    await _processBatch(toTrashRemote, (filename) async {
      final srcPath = '${WebDavSyncService.momentsBasePath}$filename';
      final trashPath = '${WebDavSyncService.trashBasePath}moments_$filename';

      try {
        await _storage.ensureDirectoryExists(WebDavSyncService.trashBasePath);
        await _storage.moveFile(srcPath, trashPath);
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
      await service.manifestService.removeItem(
        name,
        expectedVersionTimestamp: mergedItems[name]!.versionTimestamp,
      );
      nextRemoteManifest.items.remove(name);
    }

    final manifestToWrite = SyncManifest(
      lastSyncTimestamp: DateTime.now().millisecondsSinceEpoch,
      items: nextRemoteManifest.items.map(
        (key, value) => MapEntry(key, value.copyWith()),
      ),
    );

    try {
      await _storage.writeRemoteFile(
        '${WebDavSyncService.rootPath}moments_manifest.json',
        jsonEncode(manifestToWrite.toJson()),
      );
    } catch (e) {
      outcome.addUploadFailure('moment manifest write: $e');
    }

    outcome.processedMoments = processed;
  }

  Future<void> _syncMomentImages(
    Directory localImagesDir,
    bool isAuto,
    Set<String> validImageNames,
    SyncRunOutcome outcome,
  ) async {
    if (!isAuto) _notify(null, null, body: "正在同步图片...");

    // 1. Get Remote List
    List<RemoteFile> remoteImagesRaw = await _storage.listFiles(
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
          await _storage.deleteFile(WebDavSyncService.momentsImagesPath + name);
          processed++;
          if (!isAuto) {
            _notify(processed, total, body: "清理云端无效图片: $name");
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
              _notify(
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
        await _storage.uploadFile(
          f.path,
          WebDavSyncService.momentsImagesPath + name,
        );
        processed++;
        if (!isAuto) _notify(processed, total, body: "图片上传: $name");
      } catch (e) {
        outcome.addUploadFailure('image upload $name: $e');
      }
    });

    // Parallel Download
    await _processBatch(toDownload, (name) async {
      File localFile = File(path.join(localImagesDir.path, name));
      try {
        await _storage
            .downloadFile(
              WebDavSyncService.momentsImagesPath + name,
              localFile.path,
            )
            .timeout(imageDownloadTimeout);
        processed++;
        if (!isAuto) _notify(processed, total, body: "图片下载: $name");
      } catch (e) {
        outcome.addDownloadFailure('image download $name: $e');
      }
    });
    outcome.processedImages = processed;
  }

  Future<void> _syncMomentAudio(
    Directory localAudioDir,
    bool isAuto,
    SyncRunOutcome outcome,
  ) async {
    if (!isAuto) _notify(null, null, body: "正在同步语音...");

    // 1. Get Remote List
    List<RemoteFile> remoteAudioRaw = await _storage.listFiles(
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
        await _storage.uploadFile(
          f.path,
          WebDavSyncService.momentsAudioPath + name,
        );
        processed++;
        if (!isAuto) _notify(processed, total, body: "语音上传: $name");
      } catch (e) {
        outcome.addUploadFailure('audio upload $name: $e');
      }
    });

    // Parallel Download
    await _processBatch(toDownload, (name) async {
      File localFile = File(path.join(localAudioDir.path, name));
      try {
        await _storage.downloadFile(
          WebDavSyncService.momentsAudioPath + name,
          localFile.path,
        );
        processed++;
        if (!isAuto) _notify(processed, total, body: "语音下载: $name");
      } catch (e) {
        outcome.addDownloadFailure('audio download $name: $e');
      }
    });
    outcome.processedAudio = processed;
  }
}
