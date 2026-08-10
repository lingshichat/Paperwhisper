import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../models/sync_config.dart';
import '../../../models/sync_manifest.dart';
import 'package:paper_whisper_flutter/features/diary/data/diary_service.dart';
import 'package:paper_whisper_flutter/features/moments/data/moment_service.dart';
import '../data/sync_scope_cache_store.dart';

/// 按类别划分的待同步计数（原 `SyncProvider._PendingCounts`）。
class SyncPendingCounts {
  final int diaries;
  final int moments;
  final int images;
  final int audio;

  const SyncPendingCounts({
    this.diaries = 0,
    this.moments = 0,
    this.images = 0,
    this.audio = 0,
  });

  int get total => diaries + moments + images + audio;
}

/// 待同步计数计算器（原 `SyncProvider._calculatePendingCounts` 及其差值辅助）。
///
/// 职责边界：
/// - 纯差值计算（`countPendingManifestItems` / `countPendingAssetNames`）
///   为静态纯函数，可独立单测；
/// - [calculate] 负责本地 manifest/名称集合与作用域缓存基线的 IO 编排，
///   输入 DiaryService?（未注入时日记侧计数为 0）与当前 `SyncConfig`，
///   输出 [SyncPendingCounts]。
///
/// 迁移来源（原 `sync_provider.dart`）：
/// - `_PendingCounts`               原（158-172）
/// - `_countPendingManifestItems`   原（367-381）
/// - `_getLocalAudioNames`          原（383-393）
/// - `_countPendingAssetNames`      原（395-401）
/// - `_calculatePendingCounts`      原（403-448）
class SyncPendingCalculator {
  SyncPendingCalculator({
    required SyncScopeCacheStore scopeCacheStore,
    required MomentService momentService,
  }) : _scopeCacheStore = scopeCacheStore,
       _momentService = momentService;

  final SyncScopeCacheStore _scopeCacheStore;
  final MomentService _momentService;

  /// 纯函数：本地 manifest 中与远端不一致（缺失或不同）的条目数。
  static int countPendingManifestItems(
    SyncManifest local,
    SyncManifest remote,
  ) {
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

  /// 纯函数：本地/远端名称集合的差集总量（双向孤儿合计）。
  static int countPendingAssetNames(
    Set<String> localNames,
    Set<String> remoteNames,
  ) {
    final localOnly = localNames.difference(remoteNames).length;
    final remoteOnly = remoteNames.difference(localNames).length;
    return localOnly + remoteOnly;
  }

  /// 枚举本地语音目录中的文件名集合。
  /// 供 pending 计算与成功后基线缓存（`_persistSuccessfulSyncCaches`）共用，
  /// 保持单一实现。
  Future<Set<String>> getLocalAudioNames() async {
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

  /// 计算当前作用域下的待同步计数。
  ///
  /// [diaryService] 为 null 时（如 DiaryProvider 未注入）日记侧计数为 0，
  /// 与原实现 `_diaryProvider == null` 的语义一致。
  Future<SyncPendingCounts> calculate(
    SyncConfig config, {
    DiaryService? diaryService,
  }) async {
    int pendingDiaryCount = 0;

    if (diaryService != null) {
      await diaryService.init();
      if (diaryService.dataDir != null) {
        await diaryService.manifestService.ensureConsistency(
          diaryService.dataDir!,
        );
      }
      final cachedDiaryManifest = await _scopeCacheStore.loadCachedManifest(
        SyncScopeCacheStore.lastKnownRemoteManifestKey,
        config,
      );
      pendingDiaryCount = countPendingManifestItems(
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
      config,
    );
    final pendingMomentCount = countPendingManifestItems(
      _momentService.manifestService.manifest,
      cachedMomentManifest,
    );

    final localImages = await _momentService.getAllReferencedImages();
    final cachedImages = await _scopeCacheStore.loadCachedNameSet(
      SyncScopeCacheStore.lastKnownMomentImagesKey,
      config,
    );
    final pendingImageCount = countPendingAssetNames(localImages, cachedImages);

    final localAudio = await getLocalAudioNames();
    final cachedAudio = await _scopeCacheStore.loadCachedNameSet(
      SyncScopeCacheStore.lastKnownMomentAudioKey,
      config,
    );
    final pendingAudioCount = countPendingAssetNames(localAudio, cachedAudio);

    return SyncPendingCounts(
      diaries: pendingDiaryCount,
      moments: pendingMomentCount,
      images: pendingImageCount,
      audio: pendingAudioCount,
    );
  }
}
