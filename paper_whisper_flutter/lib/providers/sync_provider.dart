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

  /// 执行完整同步
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

      // 2. 获取两端文件列表
      debugPrint('Sync: Fetching remote files...');
      List<webdav.File> remoteFiles = await _webDavService.listRemoteFiles();
      
      debugPrint('Sync: Remote files count: ${remoteFiles.length}');
      // 过滤非 txt 文件
      remoteFiles = remoteFiles.where((f) => f.name != null && f.name!.endsWith('.txt')).toList();

      List<FileSystemEntity> localFiles = localDir.listSync();
      Map<String, File> localMap = {};
      for (var f in localFiles) {
        if (f is File && path.extension(f.path) == '.txt') {
          localMap[path.basename(f.path)] = f;
        }
      }

      int uploadCount = 0;
      int downloadCount = 0;

      // 3. 遍历远程文件（检测下载/更新）
      for (var remote in remoteFiles) {
        final filename = remote.name!;
        final localFile = localMap[filename];

        bool needsDownload = false;
        if (localFile == null) {
          // 本地没有 -> 下载
          needsDownload = true;
          debugPrint('Sync: New remote file found: $filename');
        } else {
          // 本地有 -> 比较修改时间
          // WebDAV modification time 通常是 GMT
          if (remote.mTime != null) {
            final remoteTime = remote.mTime!; // webdav_client 已解析为 DateTime
            final localTime = await localFile.lastModified();
             
            // 简单的比较策略：如果远程比本地新 2秒以上（容差），下载覆盖
             if (remoteTime.difference(localTime).inSeconds > 2) {
               needsDownload = true;
               debugPrint('Sync: Remote newer: $filename (Remote: $remoteTime, Local: $localTime)');
             }
          }
        }

        if (needsDownload) {
          await _webDavService.downloadFile(filename, path.join(localDir.path, filename));
          downloadCount++;
          // 从 map 中移除，表示已处理
          localMap.remove(filename);
        } else {
          // 已经存在且本地比较新（或一样），从 map 移除，后续不再处理（除非需要上传覆盖）
          if (localFile != null) {
             // 检查是否需要上传覆盖
             final remoteTime = remote.mTime;
             if (remoteTime != null) {
               final localTime = await localFile.lastModified();
               if (localTime.difference(remoteTime).inSeconds > 2) {
                 // 本地比远程新 -> 上传
                 await _webDavService.uploadFile(localFile.path, filename);
                 uploadCount++;
                 debugPrint('Sync: Local newer, uploading: $filename');
               }
             }
             localMap.remove(filename);
          }
        }
      }

      // 4. 遍历剩余的本地文件（检测上传 - 这些是远程没有的）
      for (var entry in localMap.entries) {
        final filename = entry.key;
        final file = entry.value;
        debugPrint('Sync: New local file found, uploading: $filename');
        await _webDavService.uploadFile(file.path, filename);
        uploadCount++;
      }

      debugPrint('Sync completed. Uploaded: $uploadCount, Downloaded: $downloadCount');
      
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
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
