import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/sync_trust_snapshot.dart';

/// `sync_trust_snapshot` 持久化（SharedPreferences），无 UI 依赖，可独立单测。
///
/// 键名 `sync_trust_snapshot` 与 JSON 结构与 `SyncProvider` 原实现逐字兼容。
/// Provider 只负责编排：读取/写入委托本 store，不再直接触碰
/// SharedPreferences。
///
/// 迁移来源（原 `sync_provider.dart`）：
/// - `_persistTrustSnapshot`           原（310-316）
/// - `_loadConfig` 的 snapshot 读取段   原（755-762）
class SyncTrustSnapshotStore {
  SyncTrustSnapshotStore({Future<SharedPreferences> Function()? prefsFactory})
    : _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  static const String syncTrustSnapshotKey = 'sync_trust_snapshot';

  final Future<SharedPreferences> Function() _prefsFactory;

  /// 读取持久化的信任快照；无记录或解析失败时返回 null。
  Future<SyncTrustSnapshot?> load() async {
    final prefs = await _prefsFactory();
    final jsonStr = prefs.getString(syncTrustSnapshotKey);
    if (jsonStr == null) return null;
    try {
      return SyncTrustSnapshot.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Error loading sync trust snapshot: $e');
      return null;
    }
  }

  /// 持久化信任快照（JSON 逐字保留）。
  Future<void> save(SyncTrustSnapshot snapshot) async {
    final prefs = await _prefsFactory();
    await prefs.setString(syncTrustSnapshotKey, jsonEncode(snapshot.toJson()));
  }
}
