import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../models/sync_config.dart';
import '../services/webdav_sync_service.dart';
import '../services/diary_service.dart';
import '../services/moment_service.dart';
import 'diary_provider.dart';

enum SyncStatus { none, syncing, success, failed }

class SyncProvider with ChangeNotifier {
  final WebDavSyncService _webDavService = WebDavSyncService();
  final MomentService _momentService = MomentService();
  
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

      // 1. 同步日记 (Txt)
      await _syncDiaries();
      
      // 2. 同步随心记 (Moments JSON & Images)
      await _syncMoments();

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
  
  // ==========================================
  // 日记同步逻辑 (Txt)
  // ==========================================
  Future<void> _syncDiaries() async {
      await _diaryProvider!.service.init();
      final localDir = _diaryProvider!.service.dataDir;
      if (localDir == null) throw Exception('本地日记目录不可用');

      // 加载 Snapshot
      final prefs = await SharedPreferences.getInstance();
      List<String> lastKnownRemoteFiles = prefs.getStringList('last_known_remote_manifest') ?? [];

      debugPrint('Sync Diaries: Fetching remote files...');
      List<webdav.File> currentRemoteFilesRaw = await _webDavService.listRemoteFiles(
        remotePath: WebDavSyncService.diaryBasePath
      );
      
      // Filter & Map
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

      // Cloud Delete -> Local Delete
      for (var filename in lastKnownRemoteFiles) {
        if (!currentRemoteMap.containsKey(filename) && currentLocalMap.containsKey(filename)) {
           await _diaryProvider!.service.deleteEntry(filename);
           currentLocalMap.remove(filename);
           debugPrint('Sync Diaries: Cloud deletion detected, removing local: $filename');
        }
      }

      // Local Delete -> Cloud Delete
      List<String> filesToDeleteRemote = [];
      for (var filename in lastKnownRemoteFiles) {
        if (currentRemoteMap.containsKey(filename) && !currentLocalMap.containsKey(filename)) {
          filesToDeleteRemote.add(filename);
        }
      }
      for (var filename in filesToDeleteRemote) {
        await _webDavService.deleteFile(WebDavSyncService.diaryBasePath + filename);
        currentRemoteMap.remove(filename);
        debugPrint('Sync Diaries: Local deletion detected, removing remote: $filename');
      }

      // Update / Download
      for (var filename in currentRemoteMap.keys) {
        final remote = currentRemoteMap[filename]!;
        final localFile = currentLocalMap[filename];

        bool needsDownload = false;
        if (localFile == null) {
          needsDownload = true;
          debugPrint('Sync Diaries: New remote file found: $filename');
        } else {
          if (remote.mTime != null) {
            final remoteTime = remote.mTime!;
            final localTime = await localFile.lastModified();
            if (remoteTime.difference(localTime).inSeconds > 2) {
               needsDownload = true;
               debugPrint('Sync Diaries: Remote newer: $filename');
             }
          }
        }

        if (needsDownload) {
          await _webDavService.downloadFile(
            WebDavSyncService.diaryBasePath + filename, 
            path.join(localDir.path, filename)
          );
          currentLocalMap.remove(filename); 
        } else {
          if (localFile != null) {
             final remoteTime = remote.mTime;
             if (remoteTime != null) {
               final localTime = await localFile.lastModified();
               if (localTime.difference(remoteTime).inSeconds > 2) {
                 await _webDavService.uploadFile(
                   localFile.path, 
                   WebDavSyncService.diaryBasePath + filename
                 );
                 debugPrint('Sync Diaries: Local newer, uploading: $filename');
               }
             }
             currentLocalMap.remove(filename);
          }
        }
      }

      // Upload New Local
      for (var entry in currentLocalMap.entries) {
        final filename = entry.key;
        final file = entry.value;
        debugPrint('Sync Diaries: New local file found, uploading: $filename');
        await _webDavService.uploadFile(
          file.path, 
          WebDavSyncService.diaryBasePath + filename
        );
      }

      // Update Snapshot
      List<webdav.File> finalRemoteFiles = await _webDavService.listRemoteFiles(
        remotePath: WebDavSyncService.diaryBasePath
      );
      List<String> newManifest = finalRemoteFiles
          .where((f) => f.name != null && f.name!.endsWith('.txt'))
          .map((f) => f.name!)
          .toList();

      await prefs.setStringList('last_known_remote_manifest', newManifest);
  }

  // ==========================================
  // 随心记同步逻辑 (Moments)
  // ==========================================
  Future<void> _syncMoments() async {
      await _momentService.init();
      final localDir = _momentService.dataDir;
      if (localDir == null) {
        debugPrint('Sync Moments: Local dir not available, skipping.');
        return;
      }
      
      // 1. 同步 JSON 数据 (Moment Files)
      await _syncMomentJsonFiles(localDir);
      
      // 2. 同步图片附件 (Images)
      // Images dir: localDir/images
      final imagesDir = Directory(path.join(localDir.path, 'images'));
      if (await imagesDir.exists()) {
         await _syncMomentImages(imagesDir);
      }
  }

  Future<void> _syncMomentJsonFiles(Directory localDir) async {
      final prefs = await SharedPreferences.getInstance();
      List<String> lastKnownRemoteFiles = prefs.getStringList('last_known_moments_manifest') ?? [];

      debugPrint('Sync Moments: Fetching remote JSON files...');
      List<webdav.File> currentRemoteFilesRaw = await _webDavService.listRemoteFiles(
        remotePath: WebDavSyncService.momentsBasePath
      );
      
      // Filter JSON
      List<webdav.File> currentRemoteFilesList = currentRemoteFilesRaw
          .where((f) => f.name != null && f.name!.endsWith('.json'))
          .toList();
      Map<String, webdav.File> currentRemoteMap = {
        for (var f in currentRemoteFilesList) f.name!: f
      };
      
      List<FileSystemEntity> localFiles = localDir.listSync();
      Map<String, File> currentLocalMap = {};
      for (var f in localFiles) {
        if (f is File && path.extension(f.path) == '.json') {
          currentLocalMap[path.basename(f.path)] = f;
        }
      }

      // Cloud Delete -> Local Delete
      for (var filename in lastKnownRemoteFiles) {
        if (!currentRemoteMap.containsKey(filename) && currentLocalMap.containsKey(filename)) {
           // Delete local moment json
           try {
             await currentLocalMap[filename]!.delete();
             currentLocalMap.remove(filename);
             debugPrint('Sync Moments: Cloud deletion detected, removing local: $filename');
           } catch(e) {
             debugPrint('Sync Moments: Error deleting local file $filename: $e');
           }
        }
      }

      // Local Delete -> Cloud Delete
      List<String> filesToDeleteRemote = [];
      for (var filename in lastKnownRemoteFiles) {
        if (currentRemoteMap.containsKey(filename) && !currentLocalMap.containsKey(filename)) {
          filesToDeleteRemote.add(filename);
        }
      }
      for (var filename in filesToDeleteRemote) {
        await _webDavService.deleteFile(WebDavSyncService.momentsBasePath + filename);
        currentRemoteMap.remove(filename);
        debugPrint('Sync Moments: Local deletion detected, removing remote: $filename');
      }

      // Update / Download
      for (var filename in currentRemoteMap.keys) {
        final remote = currentRemoteMap[filename]!;
        final localFile = currentLocalMap[filename];

        bool needsDownload = false;
        if (localFile == null) {
          needsDownload = true;
        } else {
          if (remote.mTime != null) {
            final remoteTime = remote.mTime!;
            final localTime = await localFile.lastModified();
            if (remoteTime.difference(localTime).inSeconds > 2) {
               needsDownload = true;
             }
          }
        }

        if (needsDownload) {
          await _webDavService.downloadFile(
            WebDavSyncService.momentsBasePath + filename, 
            path.join(localDir.path, filename)
          );
          currentLocalMap.remove(filename); 
        } else {
          if (localFile != null) {
             final remoteTime = remote.mTime;
             if (remoteTime != null) {
               final localTime = await localFile.lastModified();
               if (localTime.difference(remoteTime).inSeconds > 2) {
                 await _webDavService.uploadFile(
                   localFile.path, 
                   WebDavSyncService.momentsBasePath + filename
                 );
               }
             }
             currentLocalMap.remove(filename);
          }
        }
      }

      // Upload New Local
      for (var entry in currentLocalMap.entries) {
        final filename = entry.key;
        final file = entry.value;
        await _webDavService.uploadFile(
          file.path, 
          WebDavSyncService.momentsBasePath + filename
        );
      }

      // Update Snapshot
      List<webdav.File> finalRemoteFiles = await _webDavService.listRemoteFiles(
        remotePath: WebDavSyncService.momentsBasePath
      );
      List<String> newManifest = finalRemoteFiles
          .where((f) => f.name != null && f.name!.endsWith('.json'))
          .map((f) => f.name!)
          .toList();

      await prefs.setStringList('last_known_moments_manifest', newManifest);
  }

  Future<void> _syncMomentImages(Directory localImagesDir) async {
      debugPrint('Sync Moments: Syncing images...');
      
      // 1. Get Remote Images List
      List<webdav.File> remoteImagesRaw = await _webDavService.listRemoteFiles(
        remotePath: WebDavSyncService.momentsImagesPath
      );
      Set<String> remoteImageNames = remoteImagesRaw
         .where((f) => f.name != null)
         .map((f) => f.name!)
         .toSet();

      // 2. Get Local Images List
      List<FileSystemEntity> localImages = localImagesDir.listSync();
      
      // 3. Upload Local -> Remote (If not exists)
      for (var f in localImages) {
         if (f is File) {
            String name = path.basename(f.path);
            if (!remoteImageNames.contains(name)) {
               debugPrint('Sync Moments: Uploading new image $name');
               await _webDavService.uploadFile(
                 f.path, 
                 WebDavSyncService.momentsImagesPath + name
               );
            }
         }
      }
      
      // 4. Download Remote -> Local (If not exists)
      // This ensures if I add images on phone, PC gets them.
      for (var remoteFile in remoteImagesRaw) {
         String? name = remoteFile.name;
         if (name == null) continue;
         
         File localFile = File(path.join(localImagesDir.path, name));
         if (!localFile.existsSync()) {
            debugPrint('Sync Moments: Downloading missing image $name');
            await _webDavService.downloadFile(
               WebDavSyncService.momentsImagesPath + name, 
               localFile.path
            );
         }
      }
  }

  void _setStatus(SyncStatus s, {String error = ''}) {
    _status = s;
    _lastError = error;
    notifyListeners();
  }
}
