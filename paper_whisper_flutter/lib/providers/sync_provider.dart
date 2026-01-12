import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../models/sync_config.dart';
import '../services/webdav_sync_service.dart';
import '../services/diary_service.dart';
import 'diary_provider.dart';

enum SyncStatus { none, syncing, success, failed }

class SyncProvider with ChangeNotifier {
  final WebDavSyncService _webDavService = WebDavSyncService();
  DiaryProvider? _diaryProvider;
  
  SyncConfig _config = SyncConfig();
  SyncStatus _status = SyncStatus.none;
  String _lastError = '';
  DateTime? _lastSyncTime;

  SyncConfig get config => _config;
  SyncStatus get status => _status;
  String get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isConfigured => _config.enabled && _config.serverUrl.isNotEmpty;

  SyncProvider() {
    _loadConfig();
  }

  void updateDiaryProvider(DiaryProvider dp) {
    _diaryProvider = dp;
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('sync_config');
    if (jsonStr != null) {
      try {
        _config = SyncConfig.fromJson(jsonDecode(jsonStr));
      } catch (e) {
        debugPrint('Error loading sync config: $e');
      }
    }
    
    final timeStr = prefs.getString('last_sync_time');
    if (timeStr != null) {
      _lastSyncTime = DateTime.tryParse(timeStr);
    }

    if (_config.enabled) {
      // 尝试自动连接
      connect(test: false);
    }
    notifyListeners();
  }

  Future<void> saveConfig(SyncConfig newConfig) async {
    _config = newConfig;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_config', jsonEncode(_config.toJson()));
    notifyListeners();
    
    // 如果启用，尝试连接
    if (_config.enabled) {
      connect();
    }
  }

  Future<bool> connect({bool test = true}) async {
    final success = await _webDavService.connect(
      _config.serverUrl,
      _config.username,
      _config.password,
    );
    
    if (success && test) {
      return await _webDavService.testConnection();
    }
    return success;
  }

  /// 执行完整同步（支持双向删除）
  Future<void> sync() async {
    if (_status == SyncStatus.syncing) return;
    if (!_config.enabled) return;

    // 确保连接
    if (!_webDavService.isConnected) {
      bool connected = await connect(test: false);
      if (!connected) {
        _setStatus(SyncStatus.failed, error: '无法连接到服务器');
        return;
      }
    }

    _setStatus(SyncStatus.syncing);

    try {
      if (_diaryProvider == null) {
        throw Exception('DiaryProvider not initialized');
      }

      // 1. 确保本地环境准备好
      await _diaryProvider!.service.init();
      final localDir = _diaryProvider!.service.dataDir;
      if (localDir == null) {
         throw Exception('本地数据目录不可用');
      }

      // 2. 加载“上次已知云端文件列表”快照
      final prefs = await SharedPreferences.getInstance();
      List<String> lastKnownRemoteFiles = prefs.getStringList('last_known_remote_manifest') ?? [];

      // 3. 获取最新的云端和本地文件列表
      debugPrint('Sync: Fetching remote files...');
      List<webdav.File> currentRemoteFilesRaw = await _webDavService.listRemoteFiles();
      
      // 过滤 txt 并提取文件名
      List<webdav.File> currentRemoteFilesList = currentRemoteFilesRaw
          .where((f) => f.name != null && f.name!.endsWith('.txt'))
          .toList();
      Map<String, webdav.File> currentRemoteMap = {
        for (var f in currentRemoteFilesList) f.name!: f
      };
      
      List<FileSystemEntity> localFiles = localDir.listSync();
      Map<String, File> currentLocalMap = {};
      for (var f in localFiles) {
        if (f is File && path.extension(f.path) == '.txt') {
          currentLocalMap[path.basename(f.path)] = f;
        }
      }

      int uploadCount = 0;
      int downloadCount = 0;
      int deleteLocalCount = 0;
      int deleteRemoteCount = 0;

      // 4. 检测【云端删除】并同步到本地 (Cloud Deleted -> Delete Local)
      // 条件：文件在“上次快照”中，但不在“当前云端”中，且本地还存在
      for (var filename in lastKnownRemoteFiles) {
        if (!currentRemoteMap.containsKey(filename) && currentLocalMap.containsKey(filename)) {
           // 确认删除本地
           await _diaryProvider!.service.deleteEntry(filename); // 使用 service 直接删除
           currentLocalMap.remove(filename); // 从待处理列表移除
           deleteLocalCount++;
           debugPrint('Sync: Cloud deletion detected, removing local: $filename');
        }
      }

      // 5. 检测【本地删除】并同步到云端 (Local Deleted -> Delete Remote)
      // 条件：文件在“上次快照”中，也在“当前云端”中，但本地不存在
      List<String> filesToDeleteRemote = [];
      for (var filename in lastKnownRemoteFiles) {
        if (currentRemoteMap.containsKey(filename) && !currentLocalMap.containsKey(filename)) {
          filesToDeleteRemote.add(filename);
        }
      }
      for (var filename in filesToDeleteRemote) {
        await _webDavService.deleteFile(filename);
        currentRemoteMap.remove(filename); // 从待处理列表移除
        deleteRemoteCount++;
        debugPrint('Sync: Local deletion detected, removing remote: $filename');
      }

      // 6. 双向新增/修改同步
      // 遍历剩余的云端文件（检测下载/更新）
      for (var filename in currentRemoteMap.keys) {
        final remote = currentRemoteMap[filename]!;
        final localFile = currentLocalMap[filename];

        bool needsDownload = false;
        if (localFile == null) {
          // 本地没有（且不在快照中，说明是新产生的） -> 下载
          needsDownload = true;
          debugPrint('Sync: New remote file found: $filename');
        } else {
          // 本地有 -> 比较时间
          if (remote.mTime != null) {
            final remoteTime = remote.mTime!;
            final localTime = await localFile.lastModified();
            if (remoteTime.difference(localTime).inSeconds > 2) {
               needsDownload = true;
               debugPrint('Sync: Remote newer: $filename');
             }
          }
        }

        if (needsDownload) {
          await _webDavService.downloadFile(filename, path.join(localDir.path, filename));
          downloadCount++;
          // 更新 localMap 以避免后续重复
          currentLocalMap.remove(filename); 
        } else {
          // 本地存在且可能更新 -> 检查是否上传
          if (localFile != null) {
             final remoteTime = remote.mTime;
             if (remoteTime != null) {
               final localTime = await localFile.lastModified();
               if (localTime.difference(remoteTime).inSeconds > 2) {
                 await _webDavService.uploadFile(localFile.path, filename);
                 uploadCount++;
                 debugPrint('Sync: Local newer, uploading: $filename');
               }
             }
             currentLocalMap.remove(filename);
          }
        }
      }

      // 7. 遍历剩余的本地文件（检测上传 - 纯新增）
      for (var entry in currentLocalMap.entries) {
        final filename = entry.key;
        final file = entry.value;
        debugPrint('Sync: New local file found, uploading: $filename');
        await _webDavService.uploadFile(file.path, filename);
        uploadCount++;
        
        // 临时添加到 currentRemoteMap 以便更新 manifest
        // 实际上只要上传成功，下次 fetch 就会有
      }

      // 8. 更新快照 (Snapshot)
      // 新的快照应该是：同步操作完成后，云端应该有的文件列表
      // 简单起见，我们重新 fetch 一次？或者根据操作推算。
      // 为保证准确性，建议根据逻辑推算：
      // Final Remote = (Original Remote - Deleted) + Uploaded + (Existing kept)
      // 最稳妥方式：再 list 一次（虽然耗时），或者假定成功。
      // 鉴于 webdav 延迟，假定成功比较好。
      
      // 构建新的 manifest
      List<String> newManifest = [];
      // 保留未被删除的云端文件
      newManifest.addAll(currentRemoteMap.keys); 
      // 加上新上传的文件
      // 上面步骤 7 中的文件
      // 加上步骤 6 中下载的文件? 它们已经在 currentRemoteMap.keys 里了 (如果没有被 remove)
      // Wait, I removed handled files from currentLocalMap, not currentRemoteMap keys (except deleted ones).
      // So currentRemoteMap.keys contains all original remote files minus deleted ones.
      // We need to add newly uploaded files.
      // But actually, just fetching is safer to avoid inconsistencies.
      // Given user request is infrequent sync, let's fetch list again to be absolutely sure.
      List<webdav.File> finalRemoteFiles = await _webDavService.listRemoteFiles();
      newManifest = finalRemoteFiles
          .where((f) => f.name != null && f.name!.endsWith('.txt'))
          .map((f) => f.name!)
          .toList();

      await prefs.setStringList('last_known_remote_manifest', newManifest);

      debugPrint('Sync completed. DL:$downloadCount, UL:$uploadCount, DelLoc:$deleteLocalCount, DelRem:$deleteRemoteCount');
      
      _lastSyncTime = DateTime.now();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());

      _setStatus(SyncStatus.success);
      
      // 刷新 UI
      await _diaryProvider!.loadEntries();
      
    } catch (e) {
      debugPrint('Sync failed: $e');
      _setStatus(SyncStatus.failed, error: e.toString());
    }
  }

  void _setStatus(SyncStatus s, {String error = ''}) {
    _status = s;
    _lastError = error;
    notifyListeners();
  }
}
