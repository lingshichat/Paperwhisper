import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/sync_config.dart';
import '../../../models/sync_manifest.dart';

/// 作用域化同步缓存持久化（无 UI 依赖，可独立单测）。
///
/// 负责 scope ID 派生、4 组远端基线缓存键、作用域/全局 lastSyncTime
/// 与 legacy 全局键迁移。键名、base64Url 编码与迁移语义与原实现逐字兼容。
///
/// 迁移来源（原 `sync_provider.dart`）：
/// - `buildSyncScopeId`              原 `_buildSyncScopeId`（400-407）
/// - `scopeStorageKey`               原 `_scopeStorageKey`（409-411）
/// - `decodeManifest`                原 `_decodeManifest`（413-424）
/// - manifest/nameSet 读写           原 `_loadCachedManifest` 等（426-444）
/// - 作用域 lastSyncTime 读写        原 `_loadCurrentScopeLastSyncTime`（446-463）
/// - legacy 迁移                     原 `_migrateLegacyScopeCacheIfNeeded`（465-501）
/// - 全局 `last_sync_time` 读写      原 `_loadConfig`（772-775）/ `sync` 成功分支（1128）
class SyncScopeCacheStore {
  SyncScopeCacheStore({Future<SharedPreferences> Function()? prefsFactory})
    : _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  // 原 sync_provider.dart 键常量（72-83）
  static const String lastKnownRemoteManifestKey = 'last_known_remote_manifest';
  static const String lastKnownMomentsManifestKey =
      'last_known_moments_manifest';
  static const String lastKnownMomentImagesKey =
      'last_known_remote_moment_images';
  static const String lastKnownMomentAudioKey =
      'last_known_remote_moment_audio';
  static const String currentScopeLastSyncTimeKey = 'last_sync_time_scope';
  static const String globalLastSyncTimeKey = 'last_sync_time';

  final Future<SharedPreferences> Function() _prefsFactory;

  /// 派生远程目标 scope ID（WebDAV/S3 各自独立，base64Url 编码、去 padding）。
  String buildSyncScopeId(SyncConfig config) {
    final rawScope = config.syncType == SyncType.webdav
        ? 'webdav|${config.serverUrl.trim().toLowerCase()}|${config.username.trim().toLowerCase()}'
        : 's3|${config.s3EndPoint.trim().toLowerCase()}|${config.s3BucketName.trim().toLowerCase()}|${config.s3AccessKey.trim().toLowerCase()}|${(config.s3Region ?? '').trim().toLowerCase()}';

    return base64UrlEncode(utf8.encode(rawScope)).replaceAll('=', '');
  }

  /// 由基础键 + scope ID 派生实际存储键。
  String scopeStorageKey(String baseKey, SyncConfig config) {
    return '${baseKey}_${buildSyncScopeId(config)}';
  }

  /// 解码缓存的 manifest JSON，损坏时回退为空 manifest。
  SyncManifest decodeManifest(String? jsonStr) {
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

  Future<SyncManifest> loadCachedManifest(String key, SyncConfig config) async {
    final prefs = await _prefsFactory();
    return decodeManifest(prefs.getString(scopeStorageKey(key, config)));
  }

  Future<void> saveCachedManifest(
    String key,
    SyncConfig config,
    SyncManifest manifest,
  ) async {
    final prefs = await _prefsFactory();
    await prefs.setString(
      scopeStorageKey(key, config),
      jsonEncode(manifest.toJson()),
    );
  }

  Future<Set<String>> loadCachedNameSet(String key, SyncConfig config) async {
    final prefs = await _prefsFactory();
    return (prefs.getStringList(scopeStorageKey(key, config)) ?? <String>[])
        .toSet();
  }

  Future<void> saveCachedNameSet(
    String key,
    SyncConfig config,
    Set<String> values,
  ) async {
    final prefs = await _prefsFactory();
    await prefs.setStringList(
      scopeStorageKey(key, config),
      values.toList()..sort(),
    );
  }

  Future<DateTime?> loadCurrentScopeLastSyncTime(SyncConfig config) async {
    final prefs = await _prefsFactory();
    final timeStr = prefs.getString(
      scopeStorageKey(currentScopeLastSyncTimeKey, config),
    );
    return timeStr == null ? null : DateTime.tryParse(timeStr);
  }

  Future<void> persistCurrentScopeLastSyncTime(
    SyncConfig config,
    DateTime value,
  ) async {
    final prefs = await _prefsFactory();
    await prefs.setString(
      scopeStorageKey(currentScopeLastSyncTimeKey, config),
      value.toIso8601String(),
    );
  }

  /// 将旧版全局缓存键一次性迁移到当前作用域键（仅当作用域键不存在时复制，
  /// 随后移除 4 组全局 manifest/nameSet 键；全局 `last_sync_time` 不删除）。
  Future<void> migrateLegacyScopeCacheIfNeeded(SyncConfig config) async {
    final prefs = await _prefsFactory();
    final scopedDiaryKey = scopeStorageKey(lastKnownRemoteManifestKey, config);
    final scopedMomentKey = scopeStorageKey(
      lastKnownMomentsManifestKey,
      config,
    );
    final scopedImageKey = scopeStorageKey(lastKnownMomentImagesKey, config);
    final scopedAudioKey = scopeStorageKey(lastKnownMomentAudioKey, config);
    final scopedTimeKey = scopeStorageKey(currentScopeLastSyncTimeKey, config);

    final legacyDiary = prefs.getString(lastKnownRemoteManifestKey);
    if (!prefs.containsKey(scopedDiaryKey) && legacyDiary != null) {
      await prefs.setString(scopedDiaryKey, legacyDiary);
    }

    final legacyMoments = prefs.getString(lastKnownMomentsManifestKey);
    if (!prefs.containsKey(scopedMomentKey) && legacyMoments != null) {
      await prefs.setString(scopedMomentKey, legacyMoments);
    }

    final legacyImages = prefs.getStringList(lastKnownMomentImagesKey);
    if (!prefs.containsKey(scopedImageKey) && legacyImages != null) {
      await prefs.setStringList(scopedImageKey, legacyImages);
    }

    final legacyAudio = prefs.getStringList(lastKnownMomentAudioKey);
    if (!prefs.containsKey(scopedAudioKey) && legacyAudio != null) {
      await prefs.setStringList(scopedAudioKey, legacyAudio);
    }

    final legacyTime = prefs.getString(globalLastSyncTimeKey);
    if (!prefs.containsKey(scopedTimeKey) && legacyTime != null) {
      await prefs.setString(scopedTimeKey, legacyTime);
    }

    await prefs.remove(lastKnownRemoteManifestKey);
    await prefs.remove(lastKnownMomentsManifestKey);
    await prefs.remove(lastKnownMomentImagesKey);
    await prefs.remove(lastKnownMomentAudioKey);
  }

  Future<DateTime?> readGlobalLastSyncTime() async {
    final prefs = await _prefsFactory();
    final timeStr = prefs.getString(globalLastSyncTimeKey);
    return timeStr == null ? null : DateTime.tryParse(timeStr);
  }

  Future<void> writeGlobalLastSyncTime(DateTime value) async {
    final prefs = await _prefsFactory();
    await prefs.setString(globalLastSyncTimeKey, value.toIso8601String());
  }
}
