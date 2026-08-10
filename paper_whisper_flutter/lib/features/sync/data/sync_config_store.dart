import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:paper_whisper_flutter/features/sync/data/sync_config.dart';
import 'package:paper_whisper_flutter/features/sync/data/sync_secret_store.dart';

/// 同步配置与密钥持久化（无 UI 依赖，可独立单测）。
///
/// 键名、JSON 结构与密钥存储契约与 `SyncProvider` 原实现逐字兼容：
/// - `sync_config` 键与 `SyncConfig.toJson/fromJson` 原样保留；
/// - 密钥（WebDAV 密码 / S3 SecretKey）只经 [SyncSecretStore] 读写，
///   绝不写入 SharedPreferences；
/// - legacy 密钥迁移复用 `sync_secret_store.dart` 的 `migrateLegacySyncSecrets`。
///
/// 迁移来源：
/// - `load()`  原 `_loadConfig` 配置段（744-758）+ `_hydrateConfigSecrets`（508-517）
/// - `save()`  原 `_persistSecrets`（503-506）+ `saveConfig` 写回段（805-807）
class SyncConfigStore {
  SyncConfigStore({
    required SyncSecretStore secretStore,
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _secretStore = secretStore,
       _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  static const String syncConfigKey = 'sync_config';

  final SyncSecretStore _secretStore;
  final Future<SharedPreferences> Function() _prefsFactory;

  /// 加载配置：legacy 密钥迁移 → 读取 `sync_config` JSON → 回填密钥。
  Future<SyncConfig> load() async {
    final prefs = await _prefsFactory();
    await migrateLegacySyncSecrets(prefs, _secretStore);
    var config = SyncConfig();
    final jsonStr = prefs.getString(syncConfigKey);
    if (jsonStr != null) {
      try {
        config = SyncConfig.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        debugPrint('Error loading sync config: $e');
      }
    }
    return hydrateSecrets(config);
  }

  /// 保存配置：先写密钥（空值即删除），再写 `sync_config` JSON。
  Future<void> save(SyncConfig config) async {
    final prefs = await _prefsFactory();
    await _persistSecrets(config);
    await prefs.setString(syncConfigKey, jsonEncode(config.toJson()));
  }

  /// 从 secure storage 回填配置中的密钥字段。
  Future<SyncConfig> hydrateSecrets(SyncConfig config) async {
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

  Future<void> _persistSecrets(SyncConfig config) async {
    await _secretStore.writeWebDavPassword(config.password);
    await _secretStore.writeS3SecretKey(config.s3SecretKey);
  }
}
